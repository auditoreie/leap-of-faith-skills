# Prompt de subagente de desenvolvimento

O subagente não vê a conversa. Preencha cada bloco e apague o que não se aplica.

```text
Objetivo: <ação + objeto + resultado esperado>.
Por quê: <efeito de negócio ou o que depende disto>.

Contexto já decidido (não reabrir):
- <decisão de desenho, padrão a seguir, arquivo de referência:linha>

Escopo:
- Mexer em: <arquivos ou módulos>
- Não mexer em: <o que fica fora>

Pronto quando: <critério observável: teste X passa, comando Y devolve Z>.

Limites da máquina (obrigatórios):
- Testes só em foreground, com workers limitados (ex.: --maxWorkers=2), uma suíte por
  vez. Nunca rode teste ou build em background nem fique esperando job em background.
- Não rode a suíte completa se houver outro test runner ativo na máquina.
- Sem push, merge, deploy, db push ou ação destrutiva (reset --hard, rm -rf, clean).
  Se precisar, pare e devolva o pedido.
- Commit só se pedido aqui: <sim, uma linha conventional commit, sem co-autoria | não>.

Retorno (só isto, sem prosa):
1. Status: pronto | bloqueado (<motivo>) | parcial (<o que falta>)
2. Arquivos alterados
3. Comandos de verificação rodados e o resultado (verbatim nas falhas)
4. O que não foi verificado, marcado como tal
5. Dúvida de desenho encontrada, se houver (não decida sozinho)
```
