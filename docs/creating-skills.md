# Criando uma nova skill aqui

## Quando criar

Criar quando o padrão se repete em mais de um projeto interno. Não criar pra coisas específicas de um único repo (essas vão no `CLAUDE.md` daquele repo).

## Estrutura mínima

```
skills/<nome>/
└── SKILL.md          ← obrigatório, com frontmatter
```

Estrutura recomendada:

```
skills/<nome>/
├── SKILL.md          ← entry point: routing + token budget
├── conventions.md    ← detalhes lazy-load (opcional)
└── templates/        ← templates carregados sob demanda (opcional)
```

## Frontmatter da SKILL.md

```markdown
---
name: nome-da-skill
description: Frase explicando QUANDO usar. Inclua gatilhos de intent (palavras-chave em português e inglês que ativam a skill). Mencione tarefas que NÃO devem invocá-la.
---
```

`description` é o que o Claude usa pra decidir invocar a skill. Seja específico — inclua exemplos do que dispara e do que não dispara.

## Princípios obrigatórios

1. **Token discipline na SKILL.md** — toda skill deve declarar regras explícitas de orçamento de tokens (o que ler, o que não ler, quando lazy-load).
2. **Lazy-load do detalhe** — SKILL.md fica curto (~150 linhas máx). Detalhes ficam em `conventions.md` ou similares, lidos só quando necessário.
3. **Safe-mode defaults** — skill nunca deve fazer git, deletar arquivos, ou chamar APIs externas sem comando explícito do usuário.
4. **Subcomandos por intent** — se a skill tem várias operações, route por args/intent na própria SKILL.md.
5. **Output focado em valor percebido** — toda operação principal termina com um resumo curto que mostra o que mudou e o que vale fazer em seguida.

## Processo

1. Crie `skills/<nome>/SKILL.md` aqui no `auditore-skills`.
2. Teste localmente: rode `~/auditore-skills/install.sh` e use em um projeto.
3. Itere baseado no uso real.
4. Quando estabilizar, commit e PR aqui.

## Antipadrões

- Skill que delega tudo a sub-agentes — custa demais.
- Skill que carrega o repo inteiro pra "entender contexto".
- Skill que toma ação destrutiva sem confirmação.
- Skill com SKILL.md > 200 linhas — refatore pra lazy-load.
- Skill que duplica funcionalidade de outra já existente — estenda ao invés.

## Versionamento

Bump de comportamento de skill = entrada no CHANGELOG da skill (se houver) ou ao menos commit message explícito (`feat(skill/nome): ...`, `fix(skill/nome): ...`).
