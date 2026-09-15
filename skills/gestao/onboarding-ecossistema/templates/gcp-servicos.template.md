# GCP — mapa de serviços do ecossistema <nome> (uso local; não versionar em repo público)

Projeto: `<project id>` · levantado em <AAAA-MM-DD>. Linhas **confirmar** não foram vistas ao vivo.

## Cloud Run

| Produto | Ambiente | Serviço | Região | Imagem | Fonte |
|---|---|---|---|---|---|
| `<produto>` | `<dev|staging|produção>` | `<nome do serviço>` | `<região>` | `<registry/imagem>` | `<arquivo que prova>` |

## Firebase Hosting

| Produto | dev | staging | produção | outros |
|---|---|---|---|---|
| `<app>` | `<site>` | `<site>` | `<site>` | `<site>` |

## Como validar (só leitura)

```bash
gcloud run services list --project <project> --format='table(metadata.name,metadata.labels.cloud.googleapis.com/location,status.url)'
firebase hosting:sites:list --project <project>
```
