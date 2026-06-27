export default async function handler(req, res) {
  // URL do script RAW no GitHub (privado ou publico)
  const GITHUB_RAW_URL = 'https://raw.githubusercontent.com/remixxlf/Otimiza-ao/main/Otimizador_Windows.ps1';

  try {
    const response = await fetch(GITHUB_RAW_URL);

    if (!response.ok) {
      res.status(502).send('# Erro ao buscar script do servidor');
      return;
    }

    const scriptContent = await response.text();

    // Retorna como texto puro (PowerShell precisa disso)
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    res.status(200).send(scriptContent);
  } catch (error) {
    res.status(500).send('# Erro interno do servidor proxy');
  }
}
