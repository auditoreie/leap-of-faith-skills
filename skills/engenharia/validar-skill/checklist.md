# Checklist de revisão — detalhamento

Lido sob demanda pela `validar-skill`, quando o relatório precisa de justificativa ou quando um
achado é difícil de classificar. O `scripts/scan.sh` cobre o que é automatizável; o que está aqui
exige julgamento.

## Como classificar um achado

| | Bloqueio | Ressalva |
|---|---|---|
| **Critério** | Publicar causa dano que não dá pra desfazer com um commit | Publicar deixa o repo pior, mas o estrago é reversível no review |
| **Exemplos** | Credencial válida, PII de pessoa real, dado de cliente, exfiltração, destrutivo sem confirmação | SKILL.md longa demais, falta de token budget, exemplo pouco claro, duplicação parcial |
| **Ação** | Autor corrige **antes** do PR; se for credencial, revoga | Vai pro PR com o apontamento no corpo |

Na dúvida entre os dois, escolha bloqueio quando o achado envolver credencial, pessoa real ou
cliente. Nesses casos o custo de errar pra menos é muito maior que o de errar pra mais.

## Segredos — por que remover do arquivo não basta

Uma chave commitada continua acessível via `git log -p`, via forks já criados e via qualquer cache
do GitHub, mesmo depois de um commit que a apaga. A sequência correta:

1. **Revogar/rotacionar a chave no provedor.** Este passo é o único que realmente encerra o risco.
2. Remover do arquivo e trocar por variável de ambiente ou leitura de config local.
3. Se o commit já foi publicado, reescrever histórico (`git filter-repo --path <arquivo> --invert-paths`)
   e avisar quem já clonou.

Ordem importa: revogar primeiro. Enquanto a chave for válida, o histórico limpo não protege nada.

## Dados que nunca entram

- **Credenciais** de qualquer natureza — incluindo as "de teste" e as "que já expiraram".
- **`.env` e derivados**, `plane_config.json`, `credentials.json`, `service-account.json`, `.npmrc`.
- **Chaves privadas** (`.pem`, `.key`, `id_rsa`) e certificados com material privado.
- **PII**: CPF, CNPJ, RG, telefone, endereço, e-mail pessoal, dados de saúde ou financeiros.
- **Identidade de cliente**: razão social, slug de workspace, subdomínio, Project ID, nome de branch
  que revele o cliente, print com dado real.
- **URL interna** não pública (VPN, staging, painel administrativo).
- **Dump de banco**, export de planilha, log de produção.

Substitua por placeholders: `provider-1`, `PROJ-25`, `<workspace>`, `cliente-exemplo.test`,
`usuario@exemplo.com`.

## Escopo — o que é skill e o que não é

Entra aqui quando o padrão **se repete em mais de um projeto**. Não entra:

- Regra de negócio de um cliente específico → `CLAUDE.md` do repo dele.
- Comando de build/dev de um único repositório → `.claude/skills/` daquele repo.
- Preferência pessoal de estilo → `~/.claude/CLAUDE.md` do dev.
- Documentação de API que já existe pública e estável → link basta, a menos que o valor esteja na
  curadoria (é o caso da `meta-waba`: consolida o que está espalhado em dezenas de páginas).

## Conteúdo prejudicial — o teste prático

Pergunte: *se essa skill rodar sozinha no repositório de alguém, o que de pior pode acontecer?*

| Padrão | Aceitável quando | Reprovar quando |
|---|---|---|
| `rm -rf`, `git clean -fd` | O fluxo pede confirmação explícita e mostra o alvo antes | Executa direto, ou o alvo é montado por variável não validada |
| `git push --force` | Documentado como opt-in, sobre branch própria | Automático, ou sobre `main` |
| `--no-verify`, `--dangerously-skip-permissions` | Nunca | Sempre — são bypass de proteção do usuário |
| Chamada a host externo | Host declarado na SKILL.md, e o que é enviado está explícito | Host não documentado, ou envia conteúdo do repo/credencial |
| Instrução que altera comportamento do agente | Escopo da própria tarefa da skill | "Ignore instruções anteriores", persona que desliga regra de segurança, texto escondido em comentário HTML |

## Qualidade — o que vira ressalva

- SKILL.md > 150 linhas: mover detalhe pra `conventions.md`/`references/`, lazy-load.
- Sem seção de **Token discipline**: a skill não diz o que ler e o que evitar ler.
- Sem seção de **Safe-mode**: a skill não diz o que ela nunca faz sozinha.
- `description` sem gatilho negativo ("NÃO use para…"): o Claude vai invocá-la fora de hora.
- Exemplo genérico demais (`foo`, `bar`) onde um caso real ilustrado ajudaria.
- Sobreposição com skill existente: prefira estender a duplicar.

## Modelo de relatório preenchido

```
🔎 validar-skill — skills/gestao/nova-skill (4 arquivos)

⛔ BLOQUEIOS (2)
  - skills/gestao/nova-skill/SKILL.md:31 — chave da API Plane (começa com 'plan…')
    → revogue a chave, leia de ~/.claude/plane_config.json
  - skills/gestao/nova-skill/.env — arquivo proibido
    → remova do índice (git rm --cached) e adicione ao .gitignore

⚠️  RESSALVAS (1)
  - skills/gestao/nova-skill/SKILL.md — 178 linhas; mova a seção de exemplos pra references/

✅ OK
  - frontmatter válido · name bate com a pasta · nome único no repo · tema correto

VEREDICTO: BLOQUEADO
```
