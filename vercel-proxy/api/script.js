import { Redis } from '@upstash/redis';

// Inicializar cliente do Redis (ele pega as variáveis do Upstash injetadas pela Vercel automaticamente)
const redis = Redis.fromEnv();

export default async function handler(req, res) {
  const { token } = req.query;

  // Se não enviar token, bloqueia a execução
  if (!token) {
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.status(200).send(
      `Write-Host "=============================================" -ForegroundColor Red\n` +
      `Write-Host "  ERRO: TOKEN DE ACESSO AUSENTE!" -ForegroundColor Red\n` +
      `Write-Host "  Por favor, compre o script no site oficial." -ForegroundColor Yellow\n` +
      `Write-Host "=============================================" -ForegroundColor Red\n` +
      `Start-Sleep -Seconds 5\n` +
      `exit`
    );
    return;
  }

  try {
    // Buscar o status do token no Upstash Redis
    const tokenData = await redis.get(`token:${token}`);

    // Se o token não existir (ou já tiver expirado após 2 horas)
    if (!tokenData) {
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.status(200).send(
        `Write-Host "=============================================" -ForegroundColor Red\n` +
        `Write-Host "  ERRO: TOKEN EXPIRADO OU INVALIDO!" -ForegroundColor Red\n` +
        `Write-Host "  Sua licenca expirou ou nao foi encontrada." -ForegroundColor Yellow\n` +
        `Write-Host "=============================================" -ForegroundColor Red\n` +
        `Start-Sleep -Seconds 5\n` +
        `exit`
      );
      return;
    }

    // Limite de usos (segurança anti-compartilhamento)
    const MAX_USES = 3; 
    if (tokenData.uses >= MAX_USES) {
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.status(200).send(
        `Write-Host "=============================================" -ForegroundColor Red\n` +
        `Write-Host "  ERRO: LIMITE DE EXECUCOES EXCEDIDO!" -ForegroundColor Red\n` +
        `Write-Host "  Este token ja foi usado o limite maximo de ${MAX_USES} vezes." -ForegroundColor Yellow\n` +
        `Write-Host "=============================================" -ForegroundColor Red\n` +
        `Start-Sleep -Seconds 5\n` +
        `exit`
      );
      return;
    }

    // Incrementar o uso e salvar de volta no Redis mantendo a expiração original
    tokenData.uses = (tokenData.uses || 0) + 1;
    
    // Pegar o TTL restante para não resetar o tempo de expiração do token (em segundos)
    const ttl = await redis.ttl(`token:${token}`);
    
    if (ttl > 0) {
      await redis.set(`token:${token}`, tokenData, { ex: ttl });
    } else {
      await redis.set(`token:${token}`, tokenData);
    }

    // Se passou na validação, busca o script original no GitHub
    const GITHUB_RAW_URL = 'https://raw.githubusercontent.com/remixxlf/Otimiza-ao/main/Otimizador_Windows.ps1';
    const response = await fetch(GITHUB_RAW_URL);

    if (!response.ok) {
      res.status(502).send('# Erro ao buscar script do servidor GitHub');
      return;
    }

    const scriptContent = await response.text();

    // Retorna o script como texto puro para execução
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    res.status(200).send(scriptContent);

  } catch (error) {
    res.status(500).send(`# Erro interno do servidor proxy: ${error.message}`);
  }
}
