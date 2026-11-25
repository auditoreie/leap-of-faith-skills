"""Crawl somente leitura de um site (sitemaps primeiro, depois links internos).

Fase 1: URLs dos sitemaps. Fase 2: crawl complementar pelos links internos.
Respeita robots.txt, no máximo 1 requisição por segundo, user-agent identificado.
Cache bruto em data/raw/ (permite retomar e reprocessar sem novo crawl).

Uso: python3 -I crawl.py --site https://www.exemplo.com.br [--max-paginas N]
Roda a partir da raiz do projeto: grava em ./data/raw/.
Saída: data/raw/pages.jsonl (sinais extraídos por URL). O CSV por tipo de página é do projeto:
inferir tipo depende do site (slug, classe do <body>), então escreva um build_crawl_csv.py local.
"""

import argparse
import gzip
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path.cwd()
RAW = ROOT / "data" / "raw"
HTML_DIR = RAW / "html"
PAGES = RAW / "pages.jsonl"
SITE = ""  # definido por --site
SITEMAP_INDEX = ""
ROBOTS = ""
UA = "AuditoreSiteAudit/1.0 (read-only crawl)"
HOSTS = set()
INTERVALO = 1.05  # segundos entre requisições
ASSET_EXT = re.compile(
    r"\.(jpe?g|png|gif|webp|svg|avif|ico|pdf|docx?|xlsx?|pptx?|zip|rar|mp4|webm|mp3|css|js|json|xml|txt|woff2?|ttf|eot)$",
    re.I,
)
SKIP_PREFIX = ("/wp-content/", "/wp-json/", "/wp-includes/", "/feed", "/xmlrpc.php")


def configurar_site(url):
    """Define site, sitemap, robots e hosts aceitos (com e sem www) a partir da URL base."""
    global SITE, SITEMAP_INDEX, ROBOTS, HOSTS
    u = urllib.parse.urlsplit(url if "://" in url else "https://" + url)
    host = u.netloc.lower()
    SITE = f"{u.scheme}://{host}"
    SITEMAP_INDEX = SITE + "/sitemap_index.xml"
    ROBOTS = SITE + "/robots.txt"
    sem_www = host[4:] if host.startswith("www.") else host
    HOSTS = {host, sem_www, "www." + sem_www}


def canonizar_host(n):
    """Normaliza para o host configurado e https."""
    u = urllib.parse.urlsplit(n)
    return urllib.parse.urlunsplit(("https", urllib.parse.urlsplit(SITE).netloc, u.path, u.query, ""))


_ultimo = 0.0


def esperar():
    global _ultimo
    delta = time.monotonic() - _ultimo
    if delta < INTERVALO:
        time.sleep(INTERVALO - delta)
    _ultimo = time.monotonic()


class SemRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


OPENER = urllib.request.build_opener(SemRedirect)


def http_get(url, tentativas=2):
    """Retorna (status, headers dict, bytes). Não segue redirecionamento."""
    for i in range(tentativas):
        esperar()
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding": "gzip"})
        try:
            with OPENER.open(req, timeout=40) as r:
                status, headers, body = r.status, dict(r.headers), r.read()
        except urllib.error.HTTPError as e:
            status, headers, body = e.code, dict(e.headers or {}), e.read() if e.fp else b""
        except Exception as e:  # rede
            if i + 1 == tentativas:
                return 0, {"erro": repr(e)}, b""
            time.sleep(5)
            continue
        if headers.get("Content-Encoding", headers.get("content-encoding", "")) == "gzip" and body:
            try:
                body = gzip.decompress(body)
            except OSError:
                pass
        return status, headers, body
    return 0, {}, b""


# ---------- robots.txt ----------

def carregar_robots():
    """Regras do robots.txt para o UA (RFC 9309): grupos do produto, senão os de '*'.
    robots inacessível (rede ou 5xx) = proibição total: aborta a coleta. 4xx = sem regras."""
    status, _, body = http_get(ROBOTS)
    if status == 0 or status >= 500:
        sys.exit(f"robots.txt inacessível ({status or 'erro de rede'}): coleta abortada (RFC 9309, 2.3.1.4). Tente depois.")
    if status >= 400:
        return []
    produto = UA.split("/", 1)[0].lower()
    grupos = []  # (agentes, regras)
    em_agentes = False
    for linha in body.decode("utf-8", "replace").splitlines():
        linha = linha.split("#", 1)[0].strip()
        if ":" not in linha:
            continue
        k, v = (p.strip() for p in linha.split(":", 1))
        k = k.lower()
        if k == "user-agent":
            if not em_agentes:
                grupos.append((set(), []))
            grupos[-1][0].add(v.lower())
            em_agentes = True
        elif k in ("allow", "disallow"):
            em_agentes = False
            if grupos and v:
                rx = "^" + re.escape(v).replace(r"\*", ".*").replace(r"\$", "$")
                grupos[-1][1].append((k, re.compile(rx), len(v)))
    proprios = [r for ags, rs in grupos if produto in ags for r in rs]
    if any(produto in ags for ags, _ in grupos):
        return proprios
    return [r for ags, rs in grupos if "*" in ags for r in rs]


def permitido(regras, url):
    p = urllib.parse.urlsplit(url)
    alvo = p.path + ("?" + p.query if p.query else "")
    melhor = None
    for tipo, rx, n in regras:
        if rx.match(alvo) and (melhor is None or n > melhor[1] or (n == melhor[1] and tipo == "allow")):
            melhor = (tipo, n)
    return melhor is None or melhor[0] == "allow"


# ---------- sitemaps ----------

NS = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}


def ler_sitemaps():
    """Tenta sitemap_index.xml e depois sitemap.xml; aceita índice ou sitemap simples.
    Sem sitemap válido, devolve vazio e o crawl segue só pelos links (avisa no terminal)."""
    urls = {}
    for cand in (SITEMAP_INDEX, SITE + "/sitemap.xml"):
        status, _, body = http_get(cand)
        if status != 200 or not body.strip().startswith(b"<"):
            continue
        try:
            idx = ET.fromstring(body)
        except ET.ParseError:
            continue
        filhos = [(sm.findtext("sm:loc", namespaces=NS).strip()) for sm in idx.findall("sm:sitemap", NS)]
        if not filhos:
            filhos = [cand]
        for loc in filhos:
            nome = loc.rsplit("/", 1)[-1].replace(".xml", "")
            if loc == cand:
                b = body
            else:
                _, _, b = http_get(loc)
            try:
                root = ET.fromstring(b)
            except ET.ParseError:
                continue
            _coletar(root, nome, urls)
        break
    if not urls:
        print("aviso: nenhum sitemap legível; o crawl seguirá só por links", flush=True)
    return urls


def _coletar(root, nome, urls):
    for u in root.findall("sm:url", NS):
        uloc = u.findtext("sm:loc", namespaces=NS).strip()
        urls[uloc] = {
            "sitemap": re.sub(r"\d+$", "", nome),
            "lastmod_sitemap": (u.findtext("sm:lastmod", namespaces=NS) or "").strip(),
            "imagens_sitemap": len(u.findall("{http://www.google.com/schemas/sitemap-image/1.1}image")),
        }


# ---------- parser HTML ----------

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
NAO_TEXTO = {"script", "style", "noscript", "svg", "template", "iframe"}
MOLDURA = {"header", "footer", "nav"}


class Extrator(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = ""
        self._in_title = False
        self.canonical = ""
        self.meta = {}
        self.body_class = ""
        self.h1 = 0
        self.links = []
        self.jsonld = []
        self._in_jsonld = False
        self._buf_jsonld = []
        self.itemtypes = set()
        self.cont = {t: 0 for t in NAO_TEXTO | MOLDURA}
        self.palavras = 0
        self.palavras_total = 0

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if tag in self.cont and tag not in VOID:
            self.cont[tag] += 1
        if tag == "title":
            self._in_title = True
        elif tag == "link" and "canonical" in a.get("rel", "").lower().split():
            self.canonical = a.get("href", "").strip()
        elif tag == "meta":
            chave = (a.get("property") or a.get("name") or "").lower()
            if chave:
                self.meta.setdefault(chave, a.get("content", ""))
        elif tag == "body":
            self.body_class = a.get("class", "")
        elif tag == "h1":
            self.h1 += 1
        elif tag == "a" and a.get("href"):
            self.links.append(a["href"].strip())
        elif tag == "script" and "ld+json" in a.get("type", "").lower():
            self._in_jsonld = True
            self._buf_jsonld = []
        if a.get("itemtype"):
            self.itemtypes.update(t.rsplit("/", 1)[-1] for t in a["itemtype"].split())

    def handle_endtag(self, tag):
        if tag in self.cont and self.cont[tag] > 0:
            self.cont[tag] -= 1
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_jsonld:
            self._in_jsonld = False
            self.jsonld.append("".join(self._buf_jsonld))

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_jsonld:
            self._buf_jsonld.append(data)
            return
        if any(self.cont[t] for t in NAO_TEXTO):
            return
        n = len(re.findall(r"\w+", data))
        self.palavras_total += n
        if not any(self.cont[t] for t in MOLDURA):
            self.palavras += n


def tipos_jsonld(blocos):
    tipos, datas = set(), {}

    def andar(o):
        if isinstance(o, dict):
            t = o.get("@type")
            if isinstance(t, str):
                tipos.add(t)
            elif isinstance(t, list):
                tipos.update(x for x in t if isinstance(x, str))
            for k in ("datePublished", "dateModified"):
                if isinstance(o.get(k), str):
                    datas.setdefault(k, o[k])
            for v in o.values():
                andar(v)
        elif isinstance(o, list):
            for v in o:
                andar(v)

    for b in blocos:
        try:
            andar(json.loads(b))
        except json.JSONDecodeError:
            tipos.add("JSON-LD-invalido")
    return sorted(tipos), datas


def normalizar(href, base):
    if href.startswith(("mailto:", "tel:", "javascript:", "#", "whatsapp:", "data:")):
        return None
    u = urllib.parse.urljoin(base, href)
    p = urllib.parse.urlsplit(u)
    if p.scheme not in ("http", "https"):
        return None
    return urllib.parse.urlunsplit((p.scheme, p.netloc.lower(), p.path or "/", p.query, ""))


def extrair(url, html):
    ex = Extrator()
    try:
        ex.feed(html)
    except Exception as e:  # HTML quebrado: guarda o que deu
        ex.meta["_erro_parse"] = repr(e)
    tipos, datas = tipos_jsonld(ex.jsonld)
    internos, uploads, externos = set(), set(), set()
    for h in ex.links:
        n = normalizar(h, url)
        if not n:
            continue
        host = urllib.parse.urlsplit(n).netloc
        path = urllib.parse.urlsplit(n).path
        if host in HOSTS:
            if path.startswith("/wp-content/uploads/"):
                uploads.add(n)
            else:
                internos.add(canonizar_host(n))
        else:
            externos.add(n)
    return {
        "title": re.sub(r"\s+", " ", ex.title).strip(),
        "canonical": ex.canonical,
        "meta_robots": ex.meta.get("robots", ""),
        "body_class": ex.body_class,
        "article_section": ex.meta.get("article:section", ""),
        "og_type": ex.meta.get("og:type", ""),
        "qtd_h1": ex.h1,
        "palavras": ex.palavras,
        "palavras_total": ex.palavras_total,
        "dados_estruturados": tipos + sorted(f"microdata:{t}" for t in ex.itemtypes),
        "data_publicacao": ex.meta.get("article:published_time") or datas.get("datePublished", ""),
        "data_modificacao": ex.meta.get("article:modified_time")
        or ex.meta.get("og:updated_time")
        or datas.get("dateModified", ""),
        "links_internos": sorted(internos),
        "links_uploads": sorted(uploads),
        "links_externos": sorted(externos),
    }


# ---------- laço principal ----------

def cache_path(url):
    return HTML_DIR / (hashlib.sha1(url.encode()).hexdigest() + ".html.gz")


def rastreavel(regras, url):
    p = urllib.parse.urlsplit(url)
    if p.netloc not in HOSTS or p.query or ASSET_EXT.search(p.path):
        return False
    if p.path.startswith(SKIP_PREFIX):
        return False
    return permitido(regras, url)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", required=True, help="URL base, ex.: https://www.exemplo.com.br")
    ap.add_argument("--max-paginas", type=int, default=3000)
    args = ap.parse_args()
    configurar_site(args.site)
    HTML_DIR.mkdir(parents=True, exist_ok=True)

    feitos = {}
    if PAGES.exists():
        for linha in PAGES.read_text().splitlines():
            r = json.loads(linha)
            feitos[r["url"]] = r

    regras = carregar_robots()
    sitemap = ler_sitemaps()
    print(f"sitemaps: {len(sitemap)} URLs", flush=True)

    fila = [u for u in list(sitemap) + [SITE + "/"] if rastreavel(regras, u)]
    vistos = set(fila)
    for r in feitos.values():  # reenfileira links de páginas já cacheadas
        for l in r.get("links_internos", []) + ([r["redirect_para"]] if r.get("redirect_para") else []):
            if l not in vistos and rastreavel(regras, l):
                vistos.add(l)
                fila.append(l)

    out = PAGES.open("a")
    i = 0
    while fila and len(feitos) < args.max_paginas:
        url = fila.pop(0)
        if url in feitos:
            continue
        status, headers, body = http_get(url)
        h = {k.lower(): v for k, v in headers.items()}
        reg = {
            "url": url,
            "origem": "sitemap" if url in sitemap else "crawl",
            **sitemap.get(url, {}),
            "status": status,
            "content_type": h.get("content-type", ""),
            "redirect_para": "",
            "x_robots_tag": h.get("x-robots-tag", ""),
        }
        if 300 <= status < 400:
            reg["redirect_para"] = normalizar(h.get("location", ""), url) or ""
        if status == 200 and "html" in reg["content_type"]:
            cache_path(url).write_bytes(gzip.compress(body))
            reg.update(extrair(url, body.decode("utf-8", "replace")))
        novos = reg.get("links_internos", []) + ([reg["redirect_para"]] if reg["redirect_para"] else [])
        for l in novos:
            if l not in vistos and rastreavel(regras, l):
                vistos.add(l)
                fila.append(l)
        feitos[url] = reg
        out.write(json.dumps(reg, ensure_ascii=False) + "\n")
        out.flush()
        i += 1
        if i % 25 == 0:
            print(f"{len(feitos)} feitas, {len(fila)} na fila", flush=True)
    out.close()
    print(f"fim: {len(feitos)} URLs, fila restante {len(fila)}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
