# meupet-push (Cloudflare Worker)

Envia as notificações push do Meu Pet+ (chat, agendamentos, receitas, SOS, corridas e pedidos).
Publicado automaticamente pelo Cloudflare Workers Builds a cada push na `main` (pasta `worker/`).

- `POST /notify` com `Authorization: Bearer <ID token do Firebase>` e corpo
  `{"to": ["uid"...], "title": "...", "body": "...", "data": {...}}`.
- Segredo `SERVICE_ACCOUNT` (JSON da conta de serviço do Firebase) fica só no painel do Cloudflare.
