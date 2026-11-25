#!/usr/bin/env bash
# gcp.sh — leituras compactas do GCP (Cloud Run, Cloud Build, Error Reporting, Firebase Hosting). SÓ LEITURA.
#
# Uso: bash gcp.sh <sub> --project P [--service S] [--region R] [--since 2h|1d] [--from ISO --to ISO]
#                        [--severity ERROR] [--status 5xx|4xx|NNN] [--grep texto] [--limit 30] [--site SITE]
# Subcomandos: logs | requests | revisoes | builds | erros | hosting
# Exit: 0 ok · 2 uso · 4 auth do gcloud expirada (peça `! gcloud auth login`) · 5 falha na chamada
set -uo pipefail

sub="${1:-}"; shift || true
[[ -n "$sub" ]] || { sed -n '2,8p' "$0"; exit 2; }
project=""; service=""; region=""; since="2h"; from=""; to=""; severity=""; status=""; grep_txt=""; limit=30; site=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) project="$2"; shift 2;; --service) service="$2"; shift 2;; --region) region="$2"; shift 2;;
    --since) since="$2"; shift 2;; --from) from="$2"; shift 2;; --to) to="$2"; shift 2;;
    --severity) severity="$2"; shift 2;; --status) status="$2"; shift 2;; --grep) grep_txt="$2"; shift 2;;
    --limit) limit="$2"; shift 2;; --site) site="$2"; shift 2;;
    *) echo "argumento desconhecido: $1" >&2; exit 2;;
  esac
done
[[ -n "$project" ]] || { echo "--project é obrigatório" >&2; exit 2; }
command -v gcloud >/dev/null 2>&1 || { echo "gcloud não encontrado no PATH" >&2; exit 5; }

# --- auth (nunca renova; só detecta) ---------------------------------------
if ! gcloud auth print-access-token >/dev/null 2>&1; then
  echo "AUTH: credencial do gcloud expirada ou ausente. Peça ao usuário: ! gcloud auth login   (conta: $(gcloud config get-value account 2>/dev/null))" >&2
  exit 4
fi

cut_line() { cut -c1-220; }
region_flag() { [[ -n "$region" ]] && printf -- '--region=%s' "$region"; }

# --- filtro comum de logs ------------------------------------------------------
base_filter() {
  local f='resource.type="cloud_run_revision"'
  [[ -n "$service" ]] && f="$f AND resource.labels.service_name=\"$service\""
  [[ -n "$region" ]]  && f="$f AND resource.labels.location=\"$region\""
  [[ -n "$severity" ]] && f="$f AND severity>=$severity"
  if [[ -n "$from" ]]; then f="$f AND timestamp>=\"$from\""; fi
  if [[ -n "$to" ]];   then f="$f AND timestamp<=\"$to\""; fi
  if [[ -n "$grep_txt" ]]; then f="$f AND (textPayload:\"$grep_txt\" OR jsonPayload.message:\"$grep_txt\" OR jsonPayload.msg:\"$grep_txt\" OR httpRequest.requestUrl:\"$grep_txt\")"; fi
  printf '%s' "$f"
}
fresh_flag() { if [[ -n "$from" ]]; then printf -- '--freshness=30d'; else printf -- '--freshness=%s' "$since"; fi; }

case "$sub" in
  logs)
    f="$(base_filter)"
    echo "== logs · $project/${service:-*} · filtro: $f · $(fresh_flag) · limit $limit"
    gcloud logging read "$f" --project "$project" "$(fresh_flag)" --limit "$limit" --order desc \
      --format='value(timestamp,severity,resource.labels.revision_name,httpRequest.status,textPayload,jsonPayload.message,jsonPayload.msg)' 2>&1 \
      | sed -E 's/\t+/ | /g' | cut_line
    ;;
  requests)
    f="$(base_filter) AND logName:\"requests\""
    case "$status" in
      5xx) f="$f AND httpRequest.status>=500";;
      4xx) f="$f AND httpRequest.status>=400 AND httpRequest.status<500";;
      "")  ;;
      *)   f="$f AND httpRequest.status=$status";;
    esac
    echo "== requests · $project/${service:-*} · filtro: $f · $(fresh_flag) · limit $limit"
    gcloud logging read "$f" --project "$project" "$(fresh_flag)" --limit "$limit" --order desc \
      --format='value(timestamp,httpRequest.status,httpRequest.requestMethod,httpRequest.requestUrl,httpRequest.latency,resource.labels.revision_name)' 2>&1 \
      | sed -E 's/\t+/ | /g' | cut_line
    ;;
  revisoes)
    [[ -n "$service" && -n "$region" ]] || { echo "revisoes exige --service e --region" >&2; exit 2; }
    echo "== serviço $service ($project/$region)"
    gcloud run services describe "$service" --project "$project" --region "$region" \
      --format='value(status.url,status.latestReadyRevisionName,spec.template.spec.containers[0].image)' 2>&1 | sed -E 's/\t+/ | /g'
    echo "-- tráfego"; gcloud run services describe "$service" --project "$project" --region "$region" --format='flattened(status.traffic)' 2>&1 | head -12
    echo "-- env (só nomes)"; gcloud run services describe "$service" --project "$project" --region "$region" --format='value(spec.template.spec.containers[0].env[].name)' 2>&1 | tr ';' '\n' | sort | tr '\n' ' '; echo
    echo "-- últimas revisões"; gcloud run revisions list --service "$service" --project "$project" --region "$region" --limit 5 \
      --format='table(metadata.name,metadata.creationTimestamp.date(tz=LOCAL),status.conditions[0].status,spec.containers[0].image.basename())' 2>&1
    ;;
  builds)
    echo "== builds recentes ($project${region:+, região $region})"
    out="$(gcloud builds list --project "$project" $(region_flag) --limit "${limit:-8}" \
      --format='table(id.slice(0:8).join(""),createTime.date(tz=LOCAL),status,substitutions._SERVICE_NAME,substitutions._ENV_TAG,source.repoSource.branchName)' 2>&1)"
    printf '%s\n' "$out" | head -"$((limit+2))"
    ;;
  erros)
    period="PERIOD_1_DAY"
    case "$since" in *h) [[ "${since%h}" -le 1 ]] && period="PERIOD_1_HOUR" || period="PERIOD_6_HOURS";; 1d) period="PERIOD_1_DAY";; *d) period="PERIOD_1_WEEK";; 30d) period="PERIOD_30_DAYS";; esac
    url="https://clouderrorreporting.googleapis.com/v1beta1/projects/$project/groupStats?timeRange.period=$period&pageSize=${limit}&order=COUNT_DESC"
    [[ -n "$service" ]] && url="$url&serviceFilter.service=$service"
    echo "== error reporting · $project/${service:-*} · $period"
    resp="$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" "$url")"
    printf '%s' "$resp" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if "error" in d:
    e = d["error"]; print(f"  NÃO VERIFICADO — {e.get(\"code\")}: {str(e.get(\"message\"))[:160]}"); sys.exit(0)
gs = d.get("errorGroupStats", [])
if not gs: print("  nenhum grupo de erro no período"); sys.exit(0)
for g in gs:
    rep = g.get("representative", {})
    msg = (rep.get("message") or "").split("\n")[0][:150]
    svcs = ",".join(sorted({s.get("service","?") for s in g.get("affectedServices", [])}))
    print(f"  {g.get(\"count\",\"?\"):>6}x  {g.get(\"firstSeenTime\",\"\")[:16]} → {g.get(\"lastSeenTime\",\"\")[:16]}  [{svcs}]  {msg}")
'
    ;;
  hosting)
    [[ -n "$site" ]] || { echo "hosting exige --site" >&2; exit 2; }
    command -v firebase >/dev/null 2>&1 || { echo "firebase CLI não encontrada" >&2; exit 5; }
    echo "== hosting · site $site ($project)"
    firebase hosting:channel:list --site "$site" --project "$project" 2>&1 | grep -v DeprecationWarning | grep -v trace-deprecation | head -20
    ;;
  *) echo "subcomando desconhecido: $sub (logs|requests|revisoes|builds|erros|hosting)" >&2; exit 2;;
esac
