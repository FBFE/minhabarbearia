# Aplica os segredos do Stripe no Secret Manager e prepara o deploy.
# 1) Na raiz do repositório (d:\minhabarbearia), crie estes 2 ficheiros com UMA linha em cada, sem aspas e sem linha vazia extra:
#    - stripe_sk.txt   → chave completa  sk_live_... ou sk_test_...
#    - stripe_whsec.txt → segredo do webhook whsec_... (painel do Stripe, mesmo destino da URL Firebase)
# 2) Na PowerShell, a partir de d:\minhabarbearia:
#    .\scripts\apply-stripe-secrets.ps1
# 3) Depois: firebase deploy --only functions
#
$ErrorActionPreference = "Stop"
# scripts\ → raiz do repo
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path (Join-Path $root "firebase.json"))) {
  Write-Error "Execute a partir de minhabarbearia: firebase.json não encontrado em $root"
  exit 1
}

Set-Location $root

$sk = Join-Path $root "stripe_sk.txt"
$wh = Join-Path $root "stripe_whsec.txt"

if (-not (Test-Path $sk)) { Write-Error "Falta $sk — crie o ficheiro com a chave sk_ (uma linha)."; exit 1 }
if (-not (Test-Path $wh)) { Write-Error "Falta $wh — crie o ficheiro com o whsec_ (uma linha)."; exit 1 }

Write-Host "A definir STRIPE_SECRET_KEY..."
& firebase functions:secrets:set STRIPE_SECRET_KEY --data-file $sk --force
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "A definir STRIPE_WEBHOOK_SECRET..."
& firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --data-file $wh --force
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Segredos aplicados. Agora: firebase deploy --only functions"
exit 0
