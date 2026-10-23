# Origem e licenças

Os scripts em `scripts/` são cópias sem alteração da skill **the-judge** v1.4.0, do catálogo
Tech Leads Club:

- Repositório: https://github.com/tech-leads-club/agent-skills
- Skill: `packages/skills-catalog/skills/(quality)/the-judge`
- Autor da skill: Felipe Rodrigues (https://github.com/felipfr)
- Código (`scripts/*.py`): MIT, Copyright (c) 2026 Tech Leads Club (texto abaixo)
- Conteúdo da skill upstream (`SKILL.md` e `references/`): CC-BY-4.0
  (https://creativecommons.org/licenses/by/4.0/), conforme a nota de dupla licença do upstream

Conferência das cópias (sha256, branch `main` em 2026-10-22):

| Arquivo | sha256 |
|---|---|
| `scripts/scan_bypasses.py` | `5593c047757a29ea1b9f2d9b4e61e8c88f5709cfafdcb47112c7ab79b1e7aa62` |
| `scripts/review_gate.py` | `279f0a119907c6a0a178d2be7cb8b3f1a5642f99a83fc4008c92bfbf3faf486d` |
| `scripts/post_review.py` | `dbf2ea0d0de802a6ca4f46fde252852ce1d3b5eacd0d90898b5b08b77f3130ae` |

O que mudou em relação ao upstream: `SKILL.md` e `references/` foram reescritos em português para
o fluxo deste repositório (gate do próprio repo primeiro, achados via `code-review` ou agente
leve, publicação só com autorização, regras do `CLAUDE.md` do projeto como blocker). O contrato do
`findings.json`, a tabela de severidades, as regras de texto do gate, a voz dos comentários e o
contrato de convergência seguem o desenho do upstream. `templates/findings.exemplo.json` e este
aviso são novos.

Este aviso acompanha qualquer redistribuição desta pasta.

## MIT License (scripts)

Copyright (c) 2026 Tech Leads Club

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
