# Contribuindo

Este repositório fica melhor quanto mais gente o usa de verdade e devolve o que aprendeu. Se você
resolveu um problema com o Claude Code e teve que explicar o mesmo padrão duas vezes — isso é uma
skill, e ela cabe aqui.

**Contribuição externa é bem-vinda e desejada.** Abra um fork, escreva, valide, mande o PR.

## Por que contribuir

Uma skill boa é conhecimento que para de ser re-explicado. Cada uma que entra aqui:

- economiza tokens de todo mundo que usa o repositório, toda vez que roda;
- transforma conhecimento que estava na cabeça de uma pessoa em algo que o time inteiro executa igual;
- é revisada por quem usa na prática, então melhora com o uso em vez de apodrecer.

O objetivo não é acumular skills — é acumular **skills mantidas**. Uma skill excelente vale mais que
dez abandonadas.

## Fluxo

```bash
# 1. Fork pelo GitHub, depois clone o seu fork
git clone git@github.com:<voce>/leap-of-faith-skills.git
cd leap-of-faith-skills
git remote add upstream git@github.com:auditoreie/leap-of-faith-skills.git

# 2. Branch a partir da main atualizada
git fetch upstream && git checkout -b feat/minha-skill upstream/main

# 3. Escreva seguindo docs/creating-skills.md
#    skills/<tema>/<nome>/SKILL.md

# 4. Instale e use de verdade antes de mandar
#    (o install.sh também ativa o hook de validação: core.hooksPath = .githooks)
./install.sh

# 5. Rode o gate de validação quando quiser conferir antes do commit
./skills/engenharia/validar-skill/scripts/scan.sh

# 6. Commit (conventional commits, uma linha) e PR pro upstream
git commit -m "feat(skill/minha-skill): resumo em uma linha"
git push origin feat/minha-skill
```

## O gate é obrigatório e automático

Todo commit passa pela `validar-skill` antes de entrar — o `install.sh` configura um hook de
`pre-commit` que roda o scanner sobre os arquivos em stage. **Bloqueio aborta o commit.** Ressalva
passa e aparece no review.

```bash
./install.sh                              # ativa o hook (uma vez por clone)
git config core.hooksPath                 # deve responder: .githooks
```

Se você clonou e o hook não está ativo, rode o `install.sh` — hooks não viajam no `git clone`, por
isso eles ficam versionados em `.githooks/` e o instalador aponta o git pra lá.

O PR precisa passar com veredicto **APROVADO** ou **APROVADO COM RESSALVAS**. Bloqueio não entra —
e se o bloqueio for credencial, **revogue a chave** antes de qualquer outra coisa: o histórico do git
preserva o valor, então apagar do arquivo não resolve.

`--no-verify` existe, mas usar significa que você contornou o gate conscientemente — explique no PR
por quê. Contribuição com bypass não documentado é rejeitada.

## O que faz uma contribuição ser aceita

- [ ] Resolve um problema que aparece em **mais de um projeto**
- [ ] Segue a estrutura de [docs/creating-skills.md](docs/creating-skills.md)
- [ ] `description` com gatilhos literais e fronteira negativa ("NÃO use para…")
- [ ] Declara **Token discipline** e **Safe-mode**
- [ ] `SKILL.md` ≤ 150 linhas, detalhe em lazy-load
- [ ] Zero segredo, zero dado de cliente, zero path absoluto de máquina
- [ ] Foi **usada de verdade** pelo menos algumas vezes antes do PR
- [ ] Passa na `validar-skill`

Contribuição de correção também conta: um passo que quebrou porque a API mudou, uma `description`
que dispara na hora errada, um exemplo que não funciona mais. Isso é manutenção, e é o que mantém o
repositório vivo.

## Ideias de skills que fariam diferença

Backlog aberto — pegue uma, ou proponha outra. Ideias que servem a mais gente que só a quem escreve:

**engenharia/**
- `revisar-pr` — revisão estruturada de diff com critérios explícitos e severidade calibrada
- `escrever-testes` — cobertura a partir do diff, priorizando caminho de erro em vez de happy path
- `investigar-bug` — do sintoma à causa raiz, sem partir pra correção antes de reproduzir
- `refatorar-seguro` — refatoração em passos verificáveis, com teste antes de cada mudança
- `auditar-dependencias` — CVEs, licenças incompatíveis, pacote abandonado
- `otimizar-tokens` — analisa uma sessão e aponta onde o contexto foi desperdiçado

**gestao/**
- `changelog` — CHANGELOG a partir dos commits, agrupado por impacto pro usuário
- `postmortem` — incidente → linha do tempo, causa raiz, ação corretiva, sem caça às bruxas
- `estimar` — decompõe uma task em unidades estimáveis e sinaliza o que está mal definido
- `onboarding-repo` — guia de primeiros passos gerado a partir da estrutura real do repositório

**integracoes/**
- Referência curada de qualquer API com documentação espalhada — o padrão da `meta-waba`: consolida o
  que exigiria dezenas de páginas, com os erros reais e as pegadinhas que a doc oficial não conta
- `supabase`, `stripe`, `aws-s3`, `google-workspace` — mesma ideia, outros ecossistemas

**acessibilidade e qualidade** (nenhuma existe ainda, e todas seriam úteis pra muita gente)
- `a11y-audit` — WCAG sobre o que mudou, com o critério citado
- `i18n` — extração de strings e checagem de chave faltando
- `perf-web` — Core Web Vitals a partir do build

Se a sua ideia serve a mais gente do que só o seu time, ela é boa candidata. Na dúvida, **abra uma
issue antes de escrever** — economiza o seu tempo e evita duplicação.

## Licença e autoria

Ao contribuir, você concorda que a sua contribuição seja distribuída sob a
[PolyForm Noncommercial License 1.0.0](LICENSE), que rege este repositório: uso, modificação e
redistribuição livres para **fins não-comerciais**; uso comercial por terceiros exige licença
específica da Auditore.

Você mantém a autoria do que escreveu — o histórico do git é o registro. Não envie código de terceiro
sem licença compatível, nem material sob NDA.

## Código de convivência

Revisão é sobre o código, nunca sobre a pessoa. Aponte o problema, explique o porquê e, quando der,
sugira o caminho. Quem contribui está doando tempo — a régua é alta, o tom é respeitoso.
