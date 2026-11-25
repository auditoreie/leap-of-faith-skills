# Os três passos de console

Lazy-load da skill `deploy-coolify`. Executados por uma pessoa, com acesso ao servidor e aos consoles.

**a) Autenticar o servidor no GHCR.** O Coolify **não guarda credencial de registry** — ele usa o
login do Docker da máquina onde roda ([doc](https://coolify.io/docs/knowledge-base/docker/registry)).
Por SSH, no servidor:

```sh
echo "$PAT" | docker login ghcr.io -u <usuario> --password-stdin
```

PAT com escopo `read:packages` apenas. É **por registry, não por projeto**: as credenciais ficam em
`$HOME/.docker/config.json` e são identificadas pela `ServerURL`
([doc](https://docs.docker.com/reference/cli/docker/login/)). Feito uma vez no servidor, vale para
todo serviço novo da mesma org — **não repita este passo a cada projeto**.

> Use um **machine user**, não a conta pessoal de alguém. Token atrelado a uma pessoa quebra o
> deploy quando ela sai da org ou o token expira.

**b) Liberar a porta na OCI — nos dois lugares.** Liberar só no console não basta. A Oracle é
explícita: ao investigar acesso, verifique as regras do NSG, as da security list **e** *"the
instance's OS firewall rules"*
([doc](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm)). As imagens
de plataforma vêm com firewall local restritivo.

**c) Liberar o IP do servidor no banco.** Se for MongoDB Atlas: *"Atlas only allows client
connections to the cluster from entries in the project's IP access list"*
([doc](https://www.mongodb.com/docs/atlas/security/ip-access-list/)). Sem isso a aplicação **sobe e
responde HTTP**, mas falha em toda query — parece bug de código.


## Fontes adicionais

- [OCI: Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [GitHub: runners arm64 em repositórios privados](https://github.blog/changelog/2026-01-29-arm64-standard-runners-are-now-available-in-private-repositories/)
- [GitHub Packages: billing](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-packages/about-billing-for-github-packages)
- [Coolify: CI/CD com GitHub Actions](https://coolify.io/docs/applications/ci-cd/github/actions) — mostra GET no webhook, desatualizado
