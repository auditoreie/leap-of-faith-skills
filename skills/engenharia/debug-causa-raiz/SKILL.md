---
name: debug-causa-raiz
description: Investiga um bug, falha de teste, build quebrado ou incidente em produção até a causa raiz ANTES de propor qualquer correção — reproduz, lê o erro inteiro, confere o que mudou, instrumenta as fronteiras entre componentes, forma uma hipótese por vez, prova com teste que falha e aplica um único fix; três tentativas falhas viram questão de arquitetura, não quarta tentativa. Use quando o usuário disser "por que isso quebra", "investiga esse erro", "bug em produção", "o teste falhou", "/debug-causa-raiz <sintoma>", "debug this". NÃO use para revisar código sem bug (isso é /review), para só ler logs do GCP (isso é /logs-gcp, que esta skill chama) nem para abrir a task (isso é /criar-task, que recebe o diagnóstico daqui).
---

# debug-causa-raiz

Regra única: **nenhuma correção antes de entender a causa.** Fix de sintoma é falha, mesmo quando "funciona". A skill produz um diagnóstico com evidência, um fix mínimo provado por teste, e o que ficou em aberto.

**Argumento:** `$ARGUMENTS` — sintoma, mensagem de erro, link de log, ID de task ou PR. Vazio → pergunte: o que se observa, onde (local, staging, produção), desde quando, e o que se esperava.

## Token discipline

- Leia a mensagem de erro e o stack trace **inteiros** uma vez; depois trabalhe com `grep -n` no entorno das linhas citadas. Não releia arquivos já lidos.
- Produção: use `/logs-gcp` para logs, revisões e builds — não chame `gcloud` à mão. Peça janela curta (a hora do sintoma ± 30 min) e filtre por serviço.
- Código: `git grep -n` pelo símbolo do stack, `sed -n` no entorno. Histórico: `git log -S'<trecho>' --oneline -- <arquivo>` acha quando um trecho entrou; `git log origin/<integração> --since=<data> -- <pasta>` acha o que mudou. `git bisect` só com reprodução automatizada e confirmação.
- Sistemas com várias camadas (engine → api → gateway → webhook): instrumente **uma vez** com log na entrada e na saída de cada fronteira, rode uma vez, leia; não adivinhe a camada.
- Mais de 3 módulos envolvidos e sem hipótese: delegue a localização a um `Explore` com `model: haiku` (só leitura), mantenha a análise inline.

## Safe-mode

- Sem fix antes da fase 1 completa. Sem duas mudanças ao mesmo tempo. Sem "conserta agora, investiga depois". Sem "provavelmente é X, deixa eu mudar".
- Dados de produção são somente leitura. Nenhum `update`, `delete` ou script contra banco de produção sai desta skill; se a correção exigir dado, vira plano em `/migracao-segura-prisma-mongo`.
- Instrumentação temporária sai antes do commit, ou vira log estruturado deliberado com nível certo.
- Teste que falha vem **antes** do fix. Sem framework aplicável, um script de reprodução mínimo vale, e fica registrado no diagnóstico.
- Terceira tentativa falha → pare e questione o desenho com o usuário. Não existe quarta tentativa sem essa conversa.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Fase 1 — causa.**
   - Erro completo: mensagem, código, arquivo:linha, request id, revisão do Cloud Run, horário com fuso.
   - Reproduza de forma confiável (local via compose/e2e do repo; ou passos exatos em staging). Sem reprodução → colete mais dado, não chute.
   - O que mudou: deploy recente (`/logs-gcp builds`), commits na janela, env ou toggle alterado, dependência atualizada, diferença de ambiente.
   - Fronteiras: para cada componente no caminho, o que entra e o que sai. Um `console.log`/log estruturado por fronteira, uma execução, leitura. Anote a camada onde o dado deixa de ser o esperado.
   - Rastreie o valor ruim até a origem. O fix mora na origem, não onde explodiu.

2. **Fase 2 — padrão.** Ache código parecido que funciona no mesmo repo e liste **todas** as diferenças, inclusive as que "não podem importar". Se está implementando um padrão de referência (ADR, doc de integração), leia-o inteiro, não o trecho.

3. **Fase 3 — hipótese.** Escreva uma frase: "a causa é X porque Y (evidência Z)". Teste com a **menor** mudança possível, uma variável por vez. Não confirmou → nova hipótese, não fix em cima de fix. Não sabe → diga que não sabe e o que falta observar.

4. **Fase 4 — fix.** Teste que falha reproduzindo o caso (`/rodar-testes` decide a camada) → um único fix na causa → teste passa, vizinhos passam, sintoma sumiu no ambiente onde apareceu. Nada de "já que estou aqui". Refactor é outro PR.

5. **Fase 4½ — arquitetura.** Três fixes falharam, ou cada fix revela acoplamento novo em outro lugar, ou o fix "exige refatorar tudo": o problema é de desenho. Pare, resuma a evidência e leve ao usuário. Saída típica: ADR via `project-ledger` ou task via `/criar-task`, não código.

## Sinais de que está errando

Pensou "quick fix por enquanto", "vou tentar mudar X e ver", "mudo várias coisas e rodo os testes", "não entendi direito mas isso deve resolver", "mais uma tentativa" depois de duas falhas → volte à fase 1. O usuário dizendo "isso não está acontecendo?", "para de chutar", "estamos travados?" significa o mesmo.

## Output

```
Sintoma: <o que se observa, onde, desde quando>
Evidência: <log/trace com horário e revisão · arquivo:linha · commit/deploy na janela>
Causa raiz: <uma frase, com a fronteira onde o dado quebra>
Fix: <arquivo:linha — mudança mínima> · teste: <spec que falhava e agora passa>
Verificado: <comando rodado e resultado · sintoma reproduzido e ausente após o fix>
Risco/aberto: <o que não foi provado · dado a corrigir · ADR necessário> | nenhum
```

Sem teste que falhava antes, o bloco diz isso explicitamente em "Verificado". Cole o bloco como comentário na task do ClickUp ou passe-o para `/criar-task` quando a correção virar trabalho de outra pessoa.
