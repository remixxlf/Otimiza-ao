import { Redis } from '@upstash/redis';

// Inicializar cliente do Redis (ele pega as variáveis do Upstash injetadas pela Vercel automaticamente)
const redis = Redis.fromEnv();

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  // 1. Validar Token de Segurança (Secret) via Query Parameter
  // O link na Kiwify deve ser cadastrado como: https://seu-site.vercel.app/api/webhook?secret=MINHA_CHAVE
  const webhookSecret = process.env.WEBHOOK_SECRET || 'chave_padrao_otimizador';
  const { secret } = req.query;

  if (secret !== webhookSecret) {
    res.status(401).send('Unauthorized: Secret incorreto');
    return;
  }

  const payload = req.body;
  
  // Logar para debug na dashboard da Vercel
  console.log('Kiwify Webhook Payload:', JSON.stringify(payload));

  const orderStatus = payload.order_status;
  const orderId = payload.order_id; // ID Único da transação

  // Se o pagamento foi aprovado
  if (orderStatus === 'paid') {
    try {
      // Salvar o token (orderId) no Redis com validade de 2 horas (7200 segundos)
      // Definimos o limite inicial de usos (uses = 0)
      await redis.set(`token:${orderId}`, { uses: 0 }, { ex: 7200 });
      console.log(`Token registrado: token:${orderId}`);
      res.status(200).send('Token registrado no Redis com sucesso!');
    } catch (err) {
      console.error('Erro ao salvar no Redis:', err);
      res.status(500).send('Erro interno ao salvar o token.');
    }
  } else {
    res.status(200).send(`Webhook recebido, mas status ignorado: ${orderStatus}`);
  }
}
