# Passadas de revisão A–F

Prompt do agente de achados (passo 3) e checklist de fallback quando `code-review` não está na
sessão. Gere candidatos com recall alto; a precisão é do passo 4. Cada candidato sai como:
afirmação, severidade provisória, ponteiro `caminho:linha`, e o input ou estado que dispara a falha.

Regras fixas: só código core do diff e, quando um achado exigir, quem chama ou é chamado. Não rode
teste, build nem instale nada. Não comente o que lint, tipos e teste já apontaram (o resultado do
passo 1 vem no prompt). Regra que o `CLAUDE.md` do repo marca como absoluta, de ouro ou
inegociável vale como blocker quando violada, sem exigir exploração provada.

## A. Correção e lógica

Só com caminho de falha concreto no diff: invariante quebrada; falha não tratada que deixa estado
parcial; limite (vazio, zero, último, off-by-one); ordem em código assíncrono; concorrência
concreta (mesmo registro, duas escritas); erro engolido; recurso vazado no caminho de erro;
dinheiro somado em float ou arredondado sem regra; data de calendário convertida sem fuso. Não
aponte input que o código a montante torna impossível nem "e se alguém depois...".

## B. Segurança

Introduzido por este PR e com caminho de exploração rastreado: injeção; auth e autorização (rota
nova sem guard, checagem de dono ausente, elevação por troca de conta); segredo em código ou log;
PII em log ou resposta; desserialização insegura; SSRF; redirect aberto; webhook sem validação de
assinatura. Problema pré-existente vai para 🟣. Fora: DoS teórico, dependência desatualizada sem
advisory para a versão exata, vulnerabilidade de memória em linguagem segura, arquivo de teste.
Em caminho de dinheiro, credencial ou rota de titular, falta de trilha de auditoria e falta de
guard contam, sim.

## C. Estrutura e manutenibilidade

Priorize: regressão estrutural; simplificação perdida que elimina ramo, helper ou camada;
condicional ad hoc espalhada onde há ponto único; abstração ou wrapper de uma implementação só;
cast e opcionalidade que escondem invariante; lógica de feature em módulo compartilhado; helper
duplicado quando já existe o canônico; `async` serializado sem motivo. Nit de legibilidade só se
não houver item acima.

## D. Comentário inútil e código defensivo sem motivo

Comentário que repete o código, narra a mudança, docstring inflada em helper trivial, código
comentado, TODO sem dono ou issue, banner de seção em arquivo curto. Código: try/catch em caminho
interno confiável, `any` para calar o compilador, null check em valor que o tipo já garante,
código "para depois", configuração de valor que nunca muda. A sugestão não muda comportamento,
salvo bug claro.

## E. Afirmações do PR

Cada "corrige X", "melhora Y", "não muda comportamento" e cada checkbox marcado do template vira
algo falsificável: teste que falha antes e passa depois, comando rodado com saída, benchmark,
issue. Sem evidência, 🟠 em forma de pergunta pedindo a prova. Nunca "verificado" sem rastro,
nunca afirmar que a claim é falsa.

## F. Bypass, duplicação e gambiarra

Candidatos do scanner e o que a regex não pega: supressão de lint ou tipo sem justificativa e
issue; teste pulado ou `.only`; asserção enfraquecida; TLS desligado; cast duplo ou `!` que esconde
null real; `--no-verify`; desvio por variável de ambiente. Duplicação exige dois `caminho:linha` e
a correção aponta o canônico. Gambiarra: número mágico sem nome, sleep como sincronização, retry
em volta de bug determinístico, lógica sobre texto de erro, edição manual de arquivo gerado, URL
ou caminho hardcoded, workaround "temporário" sem dono nem prazo. Simplificação rotulada, com dono
e issue, não é gambiarra.
