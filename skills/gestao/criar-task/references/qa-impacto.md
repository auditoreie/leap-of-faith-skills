# Impacto no usuário, estado final verdadeiro e ações fora do roteiro

Três mecânicas de QA absorvidas para o ecossistema. Uso: tasks de tipo **Erro** (rubrica), critério de aceite de qualquer task (estado final), e roteiros de teste manual/e2e (ações fora do roteiro).

## Rubrica de impacto (vai no "Problema" da task de Erro, ao lado da severidade técnica)

Classifica pelo efeito em quem usa, não pela dificuldade técnica. Um nível por bug; em dúvida, o mais alto que a evidência sustenta.

| Nível | Significa | Exemplo no ecossistema |
|---|---|---|
| **Blocks-Completion** | a pessoa não consegue terminar o que veio fazer | comprador não consegue pagar; operador não consegue confirmar o pedido; integrador recebe 500 ao criar link |
| **Data-Loss** | dado ou dinheiro somem, duplicam ou ficam inconsistentes sem aviso | PIX pago fica `PENDING` para sempre; estorno duplo; split com wallet errada |
| **Trust-Damage** | funciona, mas a pessoa deixa de confiar | status "pago" antes da confirmação; e-mail com valor diferente da tela; situação cadastral falsa |
| **Friction** | termina, mas com esforço ou confusão evitável | precisa recarregar para ver o link; erro genérico sem dizer o campo; passo redundante |
| **Cosmetic** | não afeta tarefa nem confiança | desalinhamento, texto cortado, cor fora do padrão |

Mapeamento de prioridade sugerido: Blocks-Completion e Data-Loss → prioridade alta no ClickUp (dinheiro sempre Data-Loss no mínimo); Trust-Damage → normal, com prazo; Friction e Cosmetic → backlog, agrupáveis.

## Estado final verdadeiro (critério de aceite)

Um fluxo só "funcionou" quando o resultado é lido por um **caminho independente** do que o produziu: a tela ou a API pública mostram o estado, depois de refresh, sem consultar o banco. Ver o documento no Mongo prova que a escrita aconteceu, não que o usuário vê o certo. Toda task ganha um critério assim: "estado final verificado via <dashboard | endpoint /v1 | webhook recebido>, não só pelo banco".

## Ações fora do roteiro (para e2e e teste manual)

Depois do caminho feliz, faça pelo menos três destas antes de dar o teste como concluído:

**Dinheiro**
- Pagar duas vezes o mesmo link (idempotência); pagar valor diferente do esperado; pagar depois de expirado.
- Estornar parcialmente e depois total; estornar o que já foi estornado.
- Split: mudar a config no meio do fluxo; wallet inexistente; percentual que soma mais de 100.
- Moeda e arredondamento: centavos ímpares, valor com três casas vindo do integrador.

**Rede e tempo**
- Webhook chega duas vezes; chega fora de ordem (confirmação antes da criação); chega com assinatura inválida; não chega (poll assume).
- Timeout do gateway na criação e na confirmação; resposta 5xx seguida de sucesso no retry.
- Relógio: expiração na virada do dia em UTC-3; pedido com data de hoje criado às 23:59.

**Acesso e estado**
- Dois usuários do mesmo tenant agindo no mesmo recurso; usuário de outro tenant tentando o ID alheio; sessão expirada no meio do fluxo.
- Toggle OFF depois de dados criados com ele ON; voltar a versão anterior do dash com a API nova.

Registre o que foi feito e o que aconteceu, inclusive quando nada quebrou: "tentado X, comportamento Y" é evidência.
