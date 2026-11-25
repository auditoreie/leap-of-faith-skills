# Health check que testa a dependência, não a porta

Lazy-load da skill `deploy-coolify`. Leia ao implementar a rota `/health`.

Um container sobe e responde HTTP **sem conseguir falar com o banco** — clientes como o Prisma
conectam sob demanda. Um health check que só olha a porta dá verde quando o serviço está inútil.
Numa migração, o modo de falha mais provável é exatamente esse: IP fora da allowlist, credencial
trocada, rede bloqueada.

A rota precisa de três coisas: ser pública, testar a dependência crítica, e ter teto de tempo —
sem o teto, o próprio check trava no timeout do driver.

```ts
@IsPublic()
@Get('health')
async getHealth(@Res() res: Response) {
  const startedAt = Date.now();
  let database: 'up' | 'down' = 'down';
  try {
    await Promise.race([
      this.prisma.$runCommandRaw({ ping: 1 }),
      new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 3000)),
    ]);
    database = 'up';
  } catch {
    database = 'down'; // a mensagem crua pode vazar host/usuário da conexão
  }
  const healthy = database === 'up';
  return res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    version: process.env.npm_package_version,
    database,
    latencyMs: Date.now() - startedAt,
  });
}
```

Devolva **503** quando a dependência falhar, para o orquestrador não
considerar saudável um container que não serve. Não exponha a mensagem crua do erro: ela costuma
carregar host e usuário da string de conexão. O detalhe fica no log do container.
