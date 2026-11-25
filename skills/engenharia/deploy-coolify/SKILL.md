---
name: deploy-coolify
description: Coloca um serviço no ar no Coolify da Auditore (OCI, ARM) com deploy automatizado e rollback endereçável por SHA — imagem construída no GitHub Actions, publicada no GHCR, implantada por webhook, e validada por health check que testa o banco, não só o HTTP. Use quando alguém disser "subir no Coolify", "deploy na OCI", "hospedar essa API", "migrar do Cloud Run/Heroku/Render pro nosso servidor", "configurar deploy automatizado", "preciso de rollback", ou for criar um serviço novo que vai rodar em container na infraestrutura da Auditore. NÃO use para configurar o Coolify em si (instalação, servidores, proxy) nem para deploy em Firebase/Vercel/Cloud Run.
---

# deploy-coolify

Procedimento para colocar um serviço no ar no Coolify da Auditore, com deploy automatizado e
rollback que não depende de UI.

**Alvo:** `$ARGUMENTS` — caminho do projeto, ou vazio para o diretório atual.

## Token discipline

- Leia `armadilhas.md` e `health-check.md` **sob demanda**, não de entrada.
- Verifique o estado real (`gh run list`, API do Coolify, `dig`) antes de supor — cada suposição
  errada aqui custa um ciclo de CI inteiro.
- Não rode subagentes: isto é procedimento, não investigação aberta.

## Safe-mode

- **Nunca** faça `git push`, merge, ou dispare deploy de produção sem confirmação explícita.
- Segredo (PAT, token do Coolify, `DATABASE_URL`) nunca entra no chat, no repositório ou na
  imagem: confirme que `.env*` e `.token-*` estão no `.gitignore` **e** no `.dockerignore`.
- Antes de desligar a infraestrutura antiga, valide a nova e espere a propagação do DNS — enquanto
  a antiga estiver de pé, o rollback é trocar o DNS de volta.
- Migração de banco não faz parte do deploy: rode explicitamente, com o usuário ciente.

## O desenho, em uma frase

O GitHub Actions constrói e testa a imagem, publica no GHCR com tag imutável por commit e avisa o
Coolify por webhook; o Coolify puxa e sobe. Deploy e rollback são **a mesma operação**: reapontar
uma tag móvel para um SHA que já existe.

Duas tags com papéis distintos:

`sha-<commit>` é imutável, uma por commit — o histórico endereçável. `staging`/`production` são
móveis e apontam para um `sha-*` — é o que o Coolify puxa.

## Ordem de execução

A imagem precisa existir antes de o Coolify conseguir puxá-la. Não inverta.

### 1. Levar os artefatos para o projeto

Copie do `movicar-api` (referência de implementação) e ajuste nomes:

- `Dockerfile` — multi-stage: compila na imagem, runtime só sobe o compilado
- `.github/workflows/deploy.yml` — build ARM, smoke test como portão, publicação, webhook
- `scripts/smoke-test.sh` — sobe o container e exige HTTP 200 antes de publicar
- `scripts/release.sh` — promove/reverte por SHA
- `scripts/health-check.sh` — valida o deploy de fora

**O Dockerfile precisa compilar em build-time.** Se o `CMD` roda build, migração ou codegen, tire:
cada restart recompila e, pior, migração no boot altera o banco de produção sem revisão.

### 2. Publicar a primeira imagem

Nasce no primeiro push para a branch configurada. Confira em
`https://github.com/orgs/<org>/packages`.

> Consultar o pacote pela API pode devolver **404 por falta de escopo**, não por ausência:
> `403 need read:packages` = existe e você não pode ver. Não conclua pelo 404.

### 3. Os três passos de console (quem executa é uma pessoa)

Autenticar o servidor no GHCR, liberar a porta na OCI **nas duas camadas** (rede e firewall do SO),
e liberar o IP do servidor no banco. Comandos, fontes e o motivo de cada um em
**`console-oci.md`** — não improvise, cada um tem um modo de falha que parece outra coisa.

### 4. Criar a aplicação no Coolify

**+ New Resource → Docker Image**:

| Campo | Valor |
|---|---|
| Docker Image | `ghcr.io/<org>/<app>` |
| Tag | `staging` ou `production` |
| Ports Exposes | a porta que a app escuta |
| Health check | `/health` |

Não mapeie porta para o host — isso desliga rolling update. Deixe o proxy resolver e aponte o
FQDN; o HTTPS é automático.

### 5. Fechar o laço

Copie a **Deploy Webhook URL** da aplicação e crie um token em **Keys & Tokens** com permissão
*Deploy* (não `root`). No repositório:

```sh
gh secret set COOLIFY_WEBHOOK_STAGING --body '<url>'
gh secret set COOLIFY_WEBHOOK_PRODUCTION --body '<url>'
gh secret set COOLIFY_TOKEN --body '<token>'
```

> **O webhook é POST.** Desde o Coolify v4.2, endpoints que mudam estado são POST-only e GET
> responde **405** ([release](https://github.com/coollabsio/coolify/releases/tag/v4.2.0)) — a doc
> de CI/CD deles ainda mostra GET.

## Gatilhos

- **staging** — push em `dev`. Barato e imediato; staging serve para validar muitas vezes.
- **produção** — `release: published`. Deliberado, versão nomeada, changelog; a tag da release e o
  `sha-*` apontam para o mesmo digest.

Reviewers no `environment: production` do GitHub adicionam aprovação humana à release.

## Health check: HTTP não prova nada

Um container sobe e responde HTTP **sem conseguir falar com o banco** — clientes como o Prisma
conectam sob demanda. Um health check que só olha a porta dá verde quando o serviço está inútil.

Exponha uma rota pública que **testa a dependência crítica** e devolve 503 quando ela falha, com
teto de tempo (senão o próprio check trava no timeout do driver):

Implementação e o porquê em **`health-check.md`**. Valide de fora com `./scripts/health-check.sh https://<dominio> [versão]` — checa DNS, TLS,
aplicação, banco e se a versão servida é a esperada. Sai 0 ou 1.

## Rollback

```sh
./scripts/release.sh production --list          # SHAs disponíveis
./scripts/release.sh production sha-a1b2c3d     # promove ou reverte
```

Nada é reconstruído: volta bit a bit o que estava rodando. O rollback nativo do Coolify **só
alcança imagens ainda no disco** e o cleanup as remove
([doc](https://next.coolify.io/docs/applications/deployments/rollbacks)); a tag no registry não tem
esse problema. Rollback **não** reverte migração de banco, storage nem serviço externo.

## Armadilhas conhecidas

Symlinks do `bun install`, prune que não poda, lockfile dessincronizado por merge, imports
absolutos que dependem da plataforma do build, build duplicado em branch com PR aberto —
tudo em **`armadilhas.md`**. Leia quando o build falhar de um jeito que não bate com o código.

## O que é por servidor e o que é por projeto

**Por servidor, uma vez:** `docker login ghcr.io`, firewall (VCN + SO).

**Por projeto:** aplicação no Coolify, DNS, secrets `COOLIFY_*`, variáveis de ambiente, e os
artefatos do passo 1.

## Referências

- [Coolify: registry privado](https://coolify.io/docs/knowledge-base/docker/registry)
- [Coolify: rollbacks](https://next.coolify.io/docs/applications/deployments/rollbacks)
- [Atlas: IP access list](https://www.mongodb.com/docs/atlas/security/ip-access-list/)

Demais fontes em `console-oci.md`.
