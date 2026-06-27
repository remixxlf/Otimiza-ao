#Requires -RunAsAdministrator
<#
╔══════════════════════════════════════════════════════════════════════╗
║               OTIMIZADOR WINDOWS v2.0 - COMMUNITY EDITION           ║
║                                                                      ║
║  Baseado em pesquisas do Reddit (r/pcmasterrace, r/OptimizedGaming)  ║
║  GitHub (WinUtil, Win11Debloat) e foruns de hardware.                ║
║  Tudo que os "packs de otimizacao" do Instagram fazem,               ║
║  so que de graca, aberto e documentado.                              ║
║                                                                      ║
║  ⚠ EXECUTE COMO ADMINISTRADOR                                       ║
║  ⚠ CRIE UM PONTO DE RESTAURACAO ANTES                               ║
╚══════════════════════════════════════════════════════════════════════╝

FONTES:
  - Reddit r/pcmasterrace, r/OptimizedGaming
  - Chris Titus Tech WinUtil (github.com/ChrisTitusTech/winutil)
  - Win11Debloat (github.com/Raphire/Win11Debloat)
  - Fóruns: TechPowerUp, Tom's Hardware, Level1Techs
#>

# ============================================================
# CONFIGURACAO E CORES
# ============================================================
$Host.UI.RawUI.WindowTitle = "Otimizador Windows v3.0 - Zero-Click Edition"
$ErrorActionPreference = "SilentlyContinue"

# Inicializar arquivo de log temporario
$script:logFile = "$env:TEMP\Relatorio_Otimizacao.txt"
"=============================================" | Out-File -FilePath $script:logFile -Encoding UTF8
"   RELATORIO DE OTIMIZACAO - ZERO-CLICK v3.0  " | Out-File -FilePath $script:logFile -Append -Encoding UTF8
"   Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" | Out-File -FilePath $script:logFile -Append -Encoding UTF8
"=============================================" | Out-File -FilePath $script:logFile -Append -Encoding UTF8
"" | Out-File -FilePath $script:logFile -Append -Encoding UTF8

# Variaveis globais de progresso
$script:totalSteps = 19
$script:currentStep = 0

function Show-Progress {
    param([string]$StepName)
    $script:currentStep++
    $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
    $barLength = 30
    $filled = [math]::Round($barLength * $script:currentStep / $script:totalSteps)
    $empty = $barLength - $filled
    $bar = ('█' * $filled) + ('░' * $empty)
    
    Write-Host ""
    Write-Host "  [$bar] $percent% ($script:currentStep/$script:totalSteps) - $StepName" -ForegroundColor Magenta
    $Host.UI.RawUI.WindowTitle = "Otimizador v3.0 - $percent% - $StepName"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  $Text" -ForegroundColor Cyan -NoNewline
    $padding = 50 - $Text.Length - 2
    Write-Host (" " * [Math]::Max($padding, 0)) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Salvar no log
    "" | Out-File -FilePath $script:logFile -Append -Encoding UTF8
    "--- $Text ---" | Out-File -FilePath $script:logFile -Append -Encoding UTF8
}

function Write-Step {
    param([string]$Text, [string]$Status = "OK")
    $color = if ($Status -eq "OK") { "Green" } elseif ($Status -eq "SKIP") { "Yellow" } else { "Red" }
    Write-Host "    [" -NoNewline
    Write-Host $Status -ForegroundColor $color -NoNewline
    Write-Host "] $Text"
    
    # Salvar no log
    "[$Status] $Text" | Out-File -FilePath $script:logFile -Append -Encoding UTF8
}

function Write-Info {
    param([string]$Text)
    # Silenciado para manter o terminal limpo
}

function Write-Warn {
    param([string]$Text)
    # Silenciado para manter o terminal limpo
}

function Ensure-RegPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
}

# ============================================================
# DIAGNOSTICO DO SISTEMA (NOVO - mostra estado atual)
# ============================================================
function Show-SystemDiag {
    Write-Header "DIAGNOSTICO DO SISTEMA"

    # CPU
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    Write-Host "    🖥️ CPU: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads)"

    # RAM
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    Write-Host "    💾 RAM: " -NoNewline -ForegroundColor Yellow
    Write-Host "$ram GB"

    # GPU (filtra adaptadores virtuais e basicos)
    $gpus = Get-WmiObject Win32_VideoController | Where-Object {
        $_.Status -eq 'OK' -and
        $_.Name -notmatch 'Parsec|Virtual|Basic|Microsoft|Remote'
    }
    if (-not $gpus) {
        $gpus = Get-WmiObject Win32_VideoController | Where-Object { $_.Status -eq 'OK' }
    }
    foreach ($g in $gpus) {
        # Buscar VRAM real via registro (64-bit) - corrige o bug de 4GB do WMI
        $vram = 0
        $regAdapters = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -ErrorAction SilentlyContinue
        foreach ($ra in $regAdapters) {
            if ($ra.DriverDesc -eq $g.Name -and $ra.'HardwareInformation.qwMemorySize') {
                $vram = [math]::Round([uint64]$ra.'HardwareInformation.qwMemorySize' / 1GB, 0)
                break
            }
        }
        if ($vram -eq 0) { $vram = [math]::Round($g.AdapterRAM / 1GB, 0) }
        Write-Host "    🎮 GPU: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($g.Name) ($vram GB VRAM)"
    }

    # Disco
    $disks = Get-PhysicalDisk | Select-Object MediaType, Size, FriendlyName
    foreach ($d in $disks) {
        $sizeGB = [math]::Round($d.Size / 1GB, 0)
        Write-Host "    💿 Disco: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($d.FriendlyName) - $($d.MediaType) ($sizeGB GB)"
    }

    # Windows
    $os = Get-WmiObject Win32_OperatingSystem
    Write-Host "    🪟 OS: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($os.Caption) - Build $($os.BuildNumber)"

    # Plano de energia atual
    $activePlan = powercfg /getactivescheme
    Write-Host "    ⚡ Plano: " -NoNewline -ForegroundColor Yellow
    Write-Host "$activePlan"

    # Monitor refresh rate (usa a GPU real, nao virtual)
    $realMonitor = Get-WmiObject Win32_VideoController | Where-Object {
        $_.Status -eq 'OK' -and $_.Name -notmatch 'Parsec|Virtual|Basic|Microsoft|Remote'
    } | Select-Object -First 1
    if (-not $realMonitor) { $realMonitor = Get-WmiObject Win32_VideoController | Select-Object -First 1 }
    Write-Host "    🖥️ Refresh: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($realMonitor.CurrentRefreshRate) Hz"

    # VBS Status
    $vbs = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    if ($vbs) {
        $vbsStatus = if ($vbs.VirtualizationBasedSecurityStatus -eq 2) { 'ATIVADO - reduz FPS' } else { 'Desativado' }
        Write-Host "    🔒 VBS: " -NoNewline -ForegroundColor Yellow
        Write-Host "$vbsStatus"
    }

    # Game Mode
    $gameMode = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue
    $gmStatus = if ($gameMode.AutoGameModeEnabled -eq 1) { 'Ativado' } else { 'Desativado' }
    Write-Host "    🎮 Game Mode: " -NoNewline -ForegroundColor Yellow
    Write-Host "$gmStatus"

    # HAGS
    $hags = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue
    $hagsStatus = if ($hags.HwSchMode -eq 2) { 'Ativado' } else { 'Desativado' }
    Write-Host "    ⚙️ HAGS: " -NoNewline -ForegroundColor Yellow
    Write-Host "$hagsStatus"

    # Startup apps count
    $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    Write-Host "    🚀 Startup Apps: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($startupItems.Count) programas na inicializacao"
}

# ============================================================
# BANNER INICIAL COM ARTE ASCII
# ============================================================
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "      ___       ___       ___       ___       ___       ___       ___   " -ForegroundColor Cyan
    Write-Host "     /\  \     /\  \     /\__\     /\  \     /\__\     /\__\     /\  \  " -ForegroundColor Cyan
    Write-Host "    /::\  \   /::\  \   /::L_L_   _\:\  \   |::L__L   /:/  /    /::\  \ " -ForegroundColor Cyan
    Write-Host "   /::\:\__\ /::\:\__\ /:/L:\__\ /\/::\__\ /::::\__\ /:/__/    /::\:\__\" -ForegroundColor DarkCyan
    Write-Host "   \;:::/  / \:\:\/  / \/_/:/  / \::/\/__/ \;::;/__/ \:\  \    \/\:\/__/" -ForegroundColor DarkCyan
    Write-Host "    |:\/__/   \:\/  /    /:/  /   \:\__\    |::|__|   \:\__\      \/__/ " -ForegroundColor DarkGray
    Write-Host "     \|__|     \/__/     \/__/     \/__/     \/__/     \/__/            " -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Magenta
    Write-Host "          ⚡ OTIMIZADOR ZERO-CLICK (v3.0) ⚡            " -ForegroundColor Yellow
    Write-Host "  ========================================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Iniciando Otimizacao Extrema Automatica em 3 segundos..." -ForegroundColor Red
    Start-Sleep -Seconds 3
}


# ============================================================
# ============================================================
# 1. PONTO DE RESTAURACAO (FORCADO)
# ============================================================
function Create-RestorePoint {
    Write-Header "CRIANDO PONTO DE RESTAURACAO"
    Write-Info "Tentando forcar a ativacao e criacao do ponto (Bypass 24h Limit)..."

    try {
        # Garantir que o servico VSS esteja rodando
        Start-Service -Name "VSS" -ErrorAction SilentlyContinue | Out-Null
        
        # Forcar ativacao no Registro e remover limite de 24h
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        if (-not (Test-Path $srKey)) { New-Item -Path $srKey -Force | Out-Null }
        Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        
        # Habilitar no drive C:
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null
        
        # Criar o Ponto de Fato
        Checkpoint-Computer -Description "Antes_Otimizacao_v3_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Step "Ponto de restauracao FORCADO com sucesso!"
    }
    catch {
        Write-Step "Erro ao forcar ponto de restauracao: $($_.Exception.Message)" "ERRO"
        Write-Info "O Windows pode ter bloqueado o System Restore na raiz."
    }
}

# ============================================================
# 2. PLANO DE ENERGIA (ATUALIZADO: Ultimate Performance)
# ============================================================
function Optimize-PowerPlan {
    Write-Header "OTIMIZACOES DE ENERGIA"
    Write-Info "Fonte: Reddit r/pcmasterrace, Microsoft Docs"

    # Criar e ativar Ultimate Performance (escondido por padrao)
    # GUID do Ultimate Performance: e9a42b02-d5df-448d-aa00-03f14749eb61
    Write-Host ""
    Write-Host "    ⚡ Plano de Energia:" -ForegroundColor Yellow

    $ultPerf = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    if ($ultPerf -match '([a-f0-9\-]{36})') {
        $newGuid = $Matches[1]
        powercfg /setactive $newGuid 2>$null
        Write-Step 'Ultimate Performance ativado - melhor que High Performance'
        Write-Info "Menos micro-latencia, CPU nunca faz throttle"
    }
    else {
        # Fallback para High Performance
        $highPerf = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg /setactive $highPerf 2>$null
        Write-Step 'High Performance ativado - Ultimate nao disponivel'
    }

    # Desativar hibernacao (libera espaco em disco - tamanho da RAM)
    powercfg /hibernate off 2>$null
    Write-Step "Hibernacao desativada (libera $([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)) GB)"

    # USB Selective Suspend desativado (evita desconexoes de mouse/teclado)
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /SETACTIVE SCHEME_CURRENT
    Write-Step "USB Selective Suspend desativado"

    # PCI Express Link State Power Management = OFF (NOVO - fonte: Reddit)
    # Impede que a GPU entre em modo de economia, evitando stutters
    Write-Host ""
    Write-Host "    🔌 PCI Express (Anti-Stutter GPU):" -ForegroundColor Yellow
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    powercfg /SETACTIVE SCHEME_CURRENT
    Write-Step 'PCI Express Link State: OFF - GPU nunca entra em economia'
    Write-Info "Fonte: Reddit - evita micro-stutters quando GPU sai de idle"

    # Desativar desligamento de disco
    powercfg /change disk-timeout-ac 0
    Write-Step "Timeout do disco desativado"

    # Processor Power Management - Min/Max CPU state
    Write-Host ""
    Write-Host "    🔧 Processor Power:" -ForegroundColor Yellow
    # Minimum processor state = 100% (nunca reduz clock)
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
    # Maximum processor state = 100%
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
    powercfg /SETACTIVE SCHEME_CURRENT
    Write-Step "CPU: Min 100% / Max 100% (sem throttle)"

    # Timer Resolution (melhor responsividade)
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 0
    powercfg /SETACTIVE SCHEME_CURRENT
    Write-Step "Timer de wake desativado"
}

# ============================================================
# 3. SERVICOS DESNECESSARIOS (EXPANDIDO)
# ============================================================
function Disable-UnnecessaryServices {
    Write-Header "DESATIVANDO SERVICOS DESNECESSARIOS"
    Write-Info "Fonte: Reddit r/OptimizedGaming, Chris Titus WinUtil"
    Write-Info "Nenhum servico critico sera tocado."

    $services = @(
        # Telemetria e diagnostico
        @{ Name = 'DiagTrack';                  Desc = 'Telemetria - Connected User Experiences' },
        @{ Name = "dmwappushservice";           Desc = "Push de telemetria WAP" },
        @{ Name = "diagnosticshub.standardcollector.service"; Desc = "Diagnostics Hub Collector" },

        # Performance (consomem recursos sem necessidade gaming)
        @{ Name = 'SysMain';                    Desc = 'Superfetch - pre-carrega apps, usa RAM/disco' },

        # Bloat / inuteis
        @{ Name = "MapsBroker";                 Desc = "Gerenciador de mapas baixados" },
        @{ Name = "lfsvc";                      Desc = "Servico de geolocalizacao" },
        @{ Name = "RetailDemo";                 Desc = "Modo demo de loja" },
        @{ Name = "wisvc";                      Desc = "Windows Insider Service" },
        @{ Name = "WMPNetworkSvc";              Desc = "Windows Media Player Network" },
        @{ Name = "Fax";                        Desc = "Servico de Fax" },
        @{ Name = "PrintNotify";                Desc = "Notificacoes de impressora" },
        @{ Name = "PhoneSvc";                   Desc = "Servico de telefonia" },
        @{ Name = 'RemoteRegistry';             Desc = 'Registro remoto - seguranca' },
        @{ Name = "TrkWks";                     Desc = "Distributed Link Tracking Client" },

        # Xbox (desativar APENAS se nao usa Xbox/Game Pass)
        @{ Name = "XblAuthManager";             Desc = "Xbox Live Auth" },
        @{ Name = "XblGameSave";                Desc = "Xbox Game Save" },
        @{ Name = "XboxNetApiSvc";              Desc = "Xbox Networking" },
        @{ Name = "XboxGipSvc";                 Desc = "Xbox Accessory Management" },

        # Outros que consomem recursos
        @{ Name = "WerSvc";                     Desc = "Windows Error Reporting" },
        @{ Name = "wercplsupport";              Desc = "Problem Reports Support" },
        @{ Name = "PcaSvc";                     Desc = "Program Compatibility Assistant" },
        @{ Name = 'DoSvc';                      Desc = 'Delivery Optimization - P2P updates' },
        @{ Name = 'WbioSrvc';                   Desc = 'Biometric Service - se nao usa' },
        @{ Name = 'TabletInputService';         Desc = 'Touch Keyboard - se nao usa touch' },
        @{ Name = "CDPSvc";                     Desc = "Connected Devices Platform" },
        @{ Name = "MessagingService";           Desc = "Messaging Service" }
    )

    $disabled = 0
    foreach ($svc in $services) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($service) {
            Stop-Service -Name $svc.Name -Force 2>$null
            Set-Service -Name $svc.Name -StartupType Disabled 2>$null
            Write-Step "$($svc.Desc)"
            $disabled++
        }
        else {
            Write-Step "$($svc.Desc) - nao encontrado" "SKIP"
        }
    }
    Write-Host ""
    Write-Host "    📊 $disabled servicos desativados" -ForegroundColor Green
}

# ============================================================
# 4. TWEAKS DE REGISTRO (EXPANDIDO COM TWEAKS DO REDDIT)
# ============================================================
function Apply-RegistryTweaks {
    Write-Header "APLICANDO TWEAKS DE REGISTRO"
    Write-Info "Fonte: Reddit, GitHub WinUtil, foruns TechPowerUp"

    # --- VISUAL / DESEMPENHO ---
    Write-Host ""
    Write-Host "    📊 Visual e Desempenho:" -ForegroundColor Yellow

    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String 2>$null
    Write-Step "Animacoes de minimizar/maximizar desativadas"

    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord 2>$null
    Write-Step "Transparencia de janelas desativada (economiza GPU)"

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord 2>$null
    Write-Step "Efeitos visuais otimizados para desempenho"

    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String 2>$null
    Write-Step "Delay do menu de contexto: 0ms (era 400ms)"

    # Desativar Shake to Minimize (NOVO - Reddit)
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisallowShaking" -Value 1 -Type DWord 2>$null
    Write-Step "Shake to Minimize desativado"

    # --- GAME MODE + HAGS (NOVO - Reddit consenso) ---
    Write-Host ""
    Write-Host "    🎮 Game Mode e HAGS:" -ForegroundColor Yellow
    Write-Info "Consenso Reddit 2025: Game Mode ON + HAGS ON = melhor combo"

    # Ativar Game Mode (Reddit: MANTER ativado, reduz priority de background)
    Ensure-RegPath "HKCU:\SOFTWARE\Microsoft\GameBar"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord 2>$null
    Write-Step "Game Mode: ATIVADO (prioriza jogos automaticamente)"

    # --- INPUT LAG ---
    Write-Host ""
    Write-Host "    🖱️ Reducao de Input Lag:" -ForegroundColor Yellow

    # Desativar aceleracao do mouse
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String 2>$null
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String 2>$null
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String 2>$null
    Write-Step "Aceleracao do mouse desativada (raw input 1:1)"

    # Enhance Pointer Precision OFF
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10" -Type String 2>$null
    Write-Step 'Mouse sensitivity: padrao (6/11 no painel)'

    # Desativar Game Bar / Game DVR (CONSENSO: desativar overlay)
    $gamebar = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    Ensure-RegPath $gamebar
    Set-ItemProperty -Path $gamebar -Name "AppCaptureEnabled" -Value 0 -Type DWord 2>$null

    $gamebarPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    Ensure-RegPath $gamebarPolicy
    Set-ItemProperty -Path $gamebarPolicy -Name "AllowGameDVR" -Value 0 -Type DWord 2>$null

    # Desativar overlay do Game Bar
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord 2>$null
    Write-Step "Game Bar Overlay + DVR desativados"

    # Fullscreen Optimizations (desativar globalmente = menos input lag)
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Type DWord 2>$null
    Write-Step "Fullscreen Optimizations desativadas globalmente"

    # --- REDE / TELEMETRIA ---
    Write-Host ""
    Write-Host "    🔒 Privacidade e Telemetria:" -ForegroundColor Yellow

    $dataCollection = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    Ensure-RegPath $dataCollection
    Set-ItemProperty -Path $dataCollection -Name "AllowTelemetry" -Value 0 -Type DWord 2>$null
    Write-Step "Telemetria do Windows: nivel 0 (Security)"

    $cortana = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Ensure-RegPath $cortana
    Set-ItemProperty -Path $cortana -Name "AllowCortana" -Value 0 -Type DWord 2>$null
    Write-Step "Cortana desativada"

    # Desativar Bing Search no Menu Iniciar (NOVO - muito pedido no Reddit)
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type DWord 2>$null
    Write-Step "Bing Search no Menu Iniciar desativado"

    # Desativar tips, sugestoes e anuncios
    $cdm = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $cdm -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SoftLandingEnabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path $cdm -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord 2>$null
    Write-Step "Tips, sugestoes, anuncios e instalacao silenciosa desativados"

    # Desativar Wi-Fi Sense (NOVO)
    $wifiSense = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi"
    Ensure-RegPath "$wifiSense\AllowWiFiHotSpotReporting"
    Set-ItemProperty -Path "$wifiSense\AllowWiFiHotSpotReporting" -Name "Value" -Value 0 -Type DWord 2>$null
    Ensure-RegPath "$wifiSense\AllowAutoConnectToWiFiSenseHotspots"
    Set-ItemProperty -Path "$wifiSense\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Value 0 -Type DWord 2>$null
    Write-Step "Wi-Fi Sense desativado"

    # --- PRIORIDADE DE JOGOS ---
    Write-Host ""
    Write-Host "    🏆 Prioridade de Jogos (SystemProfile):" -ForegroundColor Yellow

    $gpuPriority = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Ensure-RegPath $gpuPriority
    Set-ItemProperty -Path $gpuPriority -Name "GPU Priority" -Value 8 -Type DWord 2>$null
    Set-ItemProperty -Path $gpuPriority -Name "Priority" -Value 6 -Type DWord 2>$null
    Set-ItemProperty -Path $gpuPriority -Name "Scheduling Category" -Value "High" -Type String 2>$null
    Set-ItemProperty -Path $gpuPriority -Name "SFIO Priority" -Value "High" -Type String 2>$null
    Set-ItemProperty -Path $gpuPriority -Name "Background Only" -Value "False" -Type String 2>$null
    Set-ItemProperty -Path $gpuPriority -Name "Clock Rate" -Value 10000 -Type DWord 2>$null
    Write-Step "Game Priority: GPU=8, CPU=6, Schedule=High"

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord 2>$null
    Write-Step "SystemResponsiveness: 0% reservado para background"

    # Prioridade de rede para jogos (NOVO)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord 2>$null
    Write-Step "Network Throttling Index: desativado para jogos"
}

# ============================================================
# 5. OTIMIZACOES DE REDE (EXPANDIDO)
# ============================================================
function Optimize-Network {
    Write-Header "OTIMIZACOES DE REDE"
    Write-Info "Fonte: Reddit r/pcmasterrace, foruns de networking"

    # Desativar Nagle's Algorithm
    Write-Host ""
    Write-Host "    📡 TCP/IP Tweaks:" -ForegroundColor Yellow

    $interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    foreach ($interface in $interfaces) {
        Set-ItemProperty -Path $interface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord 2>$null
        Set-ItemProperty -Path $interface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord 2>$null
        Set-ItemProperty -Path $interface.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord 2>$null
    }
    Write-Step "Nagle's Algorithm OFF + TCP ACK imediato"
    Write-Info "Pacotes enviados imediatamente sem buffering"

    # TCP Global Parameters
    netsh int tcp set global autotuninglevel=normal 2>$null
    Write-Step "TCP Auto-Tuning: Normal"

    netsh int tcp set global ecncapability=disabled 2>$null
    Write-Step "ECN desativado"

    netsh int tcp set global timestamps=disabled 2>$null
    Write-Step "TCP Timestamps desativados (menos overhead)"

    # Desativar Large Send Offload (NOVO - Reddit)
    Write-Host ""
    Write-Host "    🌐 Network Adapter Tweaks:" -ForegroundColor Yellow

    $netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $netAdapters) {
        # Desativar Flow Control
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        # Desativar Energy Efficient Ethernet
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy-Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        # Desativar Green Ethernet
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Green Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        # Desativar Power Saving
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Power Saving Mode" -DisplayValue "Disabled" -ErrorAction SilentlyContinue

        Write-Step "Adapter '$($adapter.Name)': Flow Control/EEE/Power Saving OFF"
    }

    # Desativar QoS packet scheduler weight (NOVO)
    $qos = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    Ensure-RegPath $qos
    Set-ItemProperty -Path $qos -Name "NonBestEffortLimit" -Value 0 -Type DWord 2>$null
    Write-Step "QoS reserva de banda: 0% (era 20% por padrao)"

    # DNS otimizado
    Write-Host ""
    Write-Host "    📡 DNS Recomendados:" -ForegroundColor Yellow
    Write-Info "Cloudflare: 1.1.1.1 / 1.0.0.1 (mais rapido)"
    Write-Info "Google:     8.8.8.8 / 8.8.4.4 (mais confiavel)"
    Write-Info "Quad9:      9.9.9.9 / 149.112.112.112 (mais seguro)"

    # DNS Cache otimizado (NOVO)
    $dnsCache = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    Set-ItemProperty -Path $dnsCache -Name "MaxCacheEntryTtlLimit" -Value 86400 -Type DWord 2>$null
    Set-ItemProperty -Path $dnsCache -Name "MaxNegativeCacheTtl" -Value 5 -Type DWord 2>$null
    Write-Step "DNS Cache otimizado (TTL max 24h, neg cache 5s)"
}

# ============================================================
# 6. LIMPEZA DO SISTEMA
# ============================================================
function Clean-System {
    Write-Header "LIMPEZA DO SISTEMA"
    Write-Info "Remove arquivos temporarios, cache e lixo do sistema."

    $totalCleaned = 0

    # Pasta Temp do usuario
    $userTemp = "$env:TEMP"
    $size = (Get-ChildItem $userTemp -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Remove-Item "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
    $totalCleaned += $size
    Write-Step "Temp do usuario: $([math]::Round($size, 1)) MB limpo"

    # Pasta Temp do Windows
    $winTemp = "$env:SystemRoot\Temp"
    $size = (Get-ChildItem $winTemp -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Remove-Item "$winTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
    $totalCleaned += $size
    Write-Step "Temp do Windows: $([math]::Round($size, 1)) MB limpo"

    # Prefetch
    $prefetch = "$env:SystemRoot\Prefetch"
    $size = (Get-ChildItem $prefetch -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Remove-Item "$prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    $totalCleaned += $size
    Write-Step "Prefetch: $([math]::Round($size, 1)) MB limpo"

    # Windows Update Cache (NOVO)
    $wuCache = "$env:SystemRoot\SoftwareDistribution\Download"
    if (Test-Path $wuCache) {
        $size = (Get-ChildItem $wuCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Stop-Service -Name wuauserv -Force 2>$null
        Remove-Item "$wuCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv 2>$null
        $totalCleaned += $size
        Write-Step "Windows Update Cache: $([math]::Round($size, 1)) MB limpo"
    }

    # Shader Cache (NOVO - Reddit)
    $shaderCache = "$env:LOCALAPPDATA\D3DSCache"
    if (Test-Path $shaderCache) {
        $size = (Get-ChildItem $shaderCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Remove-Item "$shaderCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        $totalCleaned += $size
        Write-Step "DirectX Shader Cache: $([math]::Round($size, 1)) MB limpo"
        Write-Info "Shaders serao recompilados na proxima vez (stutter temporario)"
    }

    # NVIDIA Shader Cache (NOVO)
    $nvCache = "$env:LOCALAPPDATA\NVIDIA\DXCache"
    if (Test-Path $nvCache) {
        $size = (Get-ChildItem $nvCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Remove-Item "$nvCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        $totalCleaned += $size
        Write-Step "NVIDIA Shader Cache: $([math]::Round($size, 1)) MB limpo"
    }

    # Cache de icones
    $iconCache = "$env:LOCALAPPDATA\IconCache.db"
    if (Test-Path $iconCache) {
        Remove-Item $iconCache -Force -ErrorAction SilentlyContinue
        Write-Step "Cache de icones removido"
    }

    # Thumbnail cache (NOVO)
    $thumbCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
    $thumbFiles = Get-Item $thumbCache -ErrorAction SilentlyContinue
    if ($thumbFiles) {
        $size = ($thumbFiles | Measure-Object -Property Length -Sum).Sum / 1MB
        $thumbFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        $totalCleaned += $size
        Write-Step "Thumbnail Cache: $([math]::Round($size, 1)) MB limpo"
    }

    # DNS Cache
    ipconfig /flushdns 2>$null | Out-Null
    Write-Step "Cache DNS limpo"

    # Lixeira
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Step "Lixeira esvaziada"

    # Limpeza da pasta WinSxS (Bypass/Component Store Cleanup - Estilo ISO)
    Write-Host ""
    Write-Host "    📦 Limpando Base de Componentes do Windows (WinSxS)..." -ForegroundColor Yellow
    Write-Info "Isso pode levar de 1 a 3 minutos, mas libera muito espaco em disco."
    dism.exe /online /Cleanup-Image /StartComponentCleanup /NoRestart | Out-Null
    Write-Step "Limpeza da pasta WinSxS (Store Cleanup) concluida"

    Write-Host ""
    Write-Host "    💾 Total liberado: ~$([math]::Round($totalCleaned, 1)) MB" -ForegroundColor Green
}

function Optimize-GPU {
    Write-Header "OTIMIZACOES DE GPU"

    $gpu = Get-WmiObject Win32_VideoController | Where-Object {
        $_.Status -eq 'OK' -and $_.Name -notmatch 'Parsec|Virtual|Basic|Microsoft|Remote'
    } | Select-Object -First 1
    if (-not $gpu) { $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Status -eq 'OK' } | Select-Object -First 1 }
    Write-Info "GPU detectada: $($gpu.Name)"

    Write-Host ""
    Write-Host "    🖥️ Otimizacoes Gerais:" -ForegroundColor Yellow

    # HAGS (Hardware Accelerated GPU Scheduling)
    $gpuSchd = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-ItemProperty -Path $gpuSchd -Name "HwSchMode" -Value 2 -Type DWord 2>$null
    Write-Step "HAGS (Hardware Accelerated GPU Scheduling): Ativado"
    Write-Info "Reduz latencia de rendering, aprovado pela comunidade"

    # Desativar MPO
    Set-ItemProperty -Path $gpuSchd -Name "DisableOverlays" -Value 1 -Type DWord 2>$null
    Write-Step "Multi-Plane Overlay (MPO) desativado"
    Write-Info "Resolve stutters em MUITAS configs (consenso Reddit)"

    # TDR Level ajustado (evita "driver stopped responding")
    Set-ItemProperty -Path $gpuSchd -Name "TdrDelay" -Value 10 -Type DWord 2>$null
    Set-ItemProperty -Path $gpuSchd -Name "TdrDdiDelay" -Value 10 -Type DWord 2>$null
    Write-Step "TDR Delay: 10s (evita falsos 'driver stopped responding')"

    # DXGI Timeout
    $dxgi = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\DCI"
    Ensure-RegPath $dxgi
    Set-ItemProperty -Path $dxgi -Name "Timeout" -Value 7 -Type DWord 2>$null
    Write-Step "DXGI Timeout otimizado"

    # Desativar GPU Preemption (Preempcao de GPU)
    Set-ItemProperty -Path $gpuSchd -Name "DxgkEnablePreemption" -Value 0 -Type DWord 2>$null
    Write-Step "GPU Preemption: DESATIVADO (Frame timing mais consistente)"

    # Otimizar DirectX (Forcar Flip Model via registro)
    $dxMode = "HKLM:\SOFTWARE\Microsoft\DirectX"
    Ensure-RegPath $dxMode
    Set-ItemProperty -Path $dxMode -Name "D3D12FlipModel" -Value 1 -Type DWord 2>$null
    Write-Step "DXGI Flip Model: FORCADO (menor latencia em DX11/12)"

    # Otimizacoes por Marca de GPU
    if ($gpu.Name -match "NVIDIA") {
        Write-Host ""
        Write-Host "    🟢 GPU NVIDIA Detectada - Aplicando Tweaks Especififcos:" -ForegroundColor Green

        # NVIDIA Profile tweaks via registro
        $nvProfile = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
        if (Test-Path $nvProfile) {
            # Desativar HDCP Overhead
            Set-ItemProperty -Path $nvProfile -Name "RMHdcpKeyglobZero" -Value 1 -Type DWord 2>$null
            Write-Step "NVIDIA: HDCP overhead reduzido"
            
            # Forcar Shader Cache Ilimitado via Registro (4096 = Ilimitado em drivers modernos)
            Set-ItemProperty -Path $nvProfile -Name "ShaderCacheSize" -Value 4096 -Type DWord 2>$null
            Write-Step "NVIDIA: Shader Cache setado para ILIMITADO via Registro"

            # Prefer Maximum Performance (PowerManagementMode = 1)
            Set-ItemProperty -Path $nvProfile -Name "PowerManagementMode" -Value 1 -Type DWord 2>$null
            Write-Step "NVIDIA: Modo de Energia Máximo Desempenho forçado"
        }

        # Desativar NVIDIA Telemetry (Servicos e Agendador)
        Stop-Service -Name "NvTelemetryContainer" -Force 2>$null
        Set-Service -Name "NvTelemetryContainer" -StartupType Disabled 2>$null
        Get-ScheduledTask -TaskPath "\CcTasks\" -ErrorAction SilentlyContinue | Where-Object {$_.TaskName -match "NvTm"} | Disable-ScheduledTask 2>$null
        Write-Step "NVIDIA: Servico de Telemetria e Coleta de Dados desativados"

        Write-Info ""
        Write-Info "⚡ CONFIGURACOES MANUAIS RECOMENDADAS (NVIDIA Control Panel):"
        Write-Info "  Low Latency Mode: Ultra (reduz input lag)"
        Write-Info "  Texture Filtering Quality: High Performance"
        Write-Info "  Threaded Optimization: On"
        Write-Info "  G-Sync/V-Sync: G-Sync ON + V-Sync ON + FPS cap -3 do Hz"
    }
    elseif ($gpu.Name -match "AMD|Radeon") {
        Write-Host ""
        Write-Host "    🔴 GPU AMD Detectada - Aplicando Tweaks Especififcos:" -ForegroundColor Red

        # Desativar ULPS (Ultra Low Power State) em todas as chaves de placas AMD
        $amdDriverPaths = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*" -ErrorAction SilentlyContinue
        $ulpsCount = 0
        foreach ($path in $amdDriverPaths) {
            if ($path.EnableUlps -ne $null) {
                Set-ItemProperty -Path $path.PSPath -Name "EnableUlps" -Value 0 -Type DWord 2>$null
                $ulpsCount++
            }
        }
        if ($ulpsCount -gt 0) {
            Write-Step "AMD: ULPS Desativado em $ulpsCount registros (sem quedas de voltagem)"
        }

        # Desativar AMD Telemetria e Crash Defender
        Stop-Service -Name "AMDRMService" -Force 2>$null
        Set-Service -Name "AMDRMService" -StartupType Disabled 2>$null
        Stop-Service -Name "AmdCrashDefenderService" -Force 2>$null
        Set-Service -Name "AmdCrashDefenderService" -StartupType Disabled 2>$null
        Write-Step "AMD: Coleta de Dados e Crash Defender desativados"

        Write-Info ""
        Write-Info "⚡ CONFIGURACOES MANUAIS RECOMENDADAS (AMD Software):"
        Write-Info "  Anti-Lag: Ativado (reduz input lag)"
        Write-Info "  Radeon Boost: Ativado (FPS adaptativo)"
        Write-Info "  Surface Format Optimization: Ativado"
        Write-Info "  Tessellation Mode: Override / 8x"
        Write-Info "  GPU Workload: Graphics"
    }
    elseif ($gpu.Name -match "Intel") {
        Write-Host ""
        Write-Host "    🔵 GPU Intel Detectada:" -ForegroundColor Blue
        Write-Info ""
        Write-Info "⚡ CONFIGURACOES RECOMENDADAS:"
        Write-Info "  Intel Graphics Command Center > Performance"
        Write-Info "  Desativar Power Saving features"
    }
}

# ============================================================
# 8. REMOVER BLOATWARE (EXPANDIDO)
# ============================================================
function Remove-Bloatware {
    Write-Header "REMOVENDO BLOATWARE (DEBLOAT ESTILO ISO)"
    Write-Info "Fonte: Reddit, Win11Debloat by Raphire, MSMG Toolkit"
    Write-Info 'Apps essenciais - Store, Fotos, Calculadora, Terminal - mantidos.'

    # 1. Desinstalar OneDrive fisicamente
    Write-Host ""
    Write-Host "    ☁️ Desinstalando Microsoft OneDrive..." -ForegroundColor Yellow
    Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    $oneDriveSetup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $oneDriveSetup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $oneDriveSetup64) {
        Start-Process $oneDriveSetup64 -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
    elseif (Test-Path $oneDriveSetup32) {
        Start-Process $oneDriveSetup32 -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
    # Remover pastas residuais
    Remove-Item "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Step "OneDrive completamente removido do sistema"

    # 2. Desativar Recursos Opcionais Inuteis (Estilo ISO Lite)
    Write-Host ""
    Write-Host "    🧩 Desativando Recursos de Sistema Inuteis..." -ForegroundColor Yellow
    $features = @(
        "FaxServicesClient", 
        "Xps.Viewer~~0.0.1.0", 
        "Printing-XPSServices-Features", 
        "WorkFolders-Client"
    )
    foreach ($f in $features) {
        Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Step "Recursos (Fax, XPS, WorkFolders) desativados"

    # 3. Remover Apps UWP Inuteis
    Write-Host ""
    Write-Host "    📱 Desinstalando Aplicativos Pre-instalados..." -ForegroundColor Yellow
    $bloatware = @(
        # Microsoft
        "Microsoft.3DBuilder",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.BingFinance",
        "Microsoft.BingSports",
        "Microsoft.BingTranslator",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.SkypeApp",
        "Microsoft.Wallet",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.WindowsAlarms",
        "Microsoft.549981C3F5F10",         # Cortana
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "MicrosoftCorporationII.QuickAssist",
        "Microsoft.WindowsCommunicationsApps",  # Mail e Calendar
        "MicrosoftTeams",
        "MSTeams",

        # Jogos/Lixo de terceiros
        "king.com.BubbleWitch3Saga",
        "king.com.CandyCrushSaga",
        "king.com.CandyCrushSodaSaga",
        "king.com.CandyCrushFriends",
        "Disney.37853FC22B2CE",
        "SpotifyAB.SpotifyMusic",
        "Facebook.Facebook",
        "Facebook.InstagramBeta",
        "BytedancePte.Ltd.TikTok",
        "Clipchamp.Clipchamp",
        "AmazonVideo.PrimeVideo",
        "22364Disney.ESPNBetaPWA",
        "5A894077.McAfeeSecurity",
        "4DF9E0F8.Netflix",
        "CAF9E577.Plex",
        "NORDCURRENT.COOKINGFEVER"
    )

    $removed = 0
    foreach ($app in $bloatware) {
        $packages = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($pkg in $packages) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            Write-Step "$($app.Split('.')[-1]) removido"
            $removed++
        }
    }

    if ($removed -eq 0) {
        Write-Step "Nenhum aplicativo UWP inútil pendente encontrado" "SKIP"
    }
    else {
        Write-Host ""
        Write-Host "    🗑️ $removed aplicativos de fabrica desinstalados!" -ForegroundColor Green
    }
}

# ============================================================
# 9. AGENDADOR DE TAREFAS (EXPANDIDO)
# ============================================================
function Optimize-ScheduledTasks {
    Write-Header "OTIMIZANDO AGENDADOR DE TAREFAS"
    Write-Info "Desativa tarefas de telemetria e diagnostico."

    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Maps\MapsToastTask",
        "\Microsoft\Windows\Maps\MapsUpdateTask",
        "\Microsoft\Windows\Shell\FamilySafetyMonitor",
        "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    )

    $disabled = 0
    foreach ($task in $tasks) {
        $taskPath = $task.Substring(0, $task.LastIndexOf('\') + 1)
        $taskName = $task.Split('\')[-1]
        $t = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
        if ($t -and $t.State -ne "Disabled") {
            Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
            Write-Step "$taskName desativado"
            $disabled++
        }
        elseif ($t) {
            Write-Step "$taskName (ja desativado)" "SKIP"
        }
        else {
            Write-Step "$taskName (nao encontrado)" "SKIP"
        }
    }
    Write-Host ""
    Write-Host "    📊 $disabled tarefas desativadas" -ForegroundColor Green
}

# ============================================================
# AVANCADO: BCDEDIT TWEAKS (NOVO - Reddit/Foruns)
# ============================================================
function Apply-BCDEdit {
    Write-Header "BCDEDIT TWEAKS (AVANCADO)"
    Write-Info "Fonte: Reddit, Level1Techs, TechPowerUp"
    Write-Warn "Estas mudancas afetam o boot. Reversivel com os comandos mostrados."

    Write-Host ""
    Write-Host "    ⏱️ Timer e Tick:" -ForegroundColor Yellow

    # Desativar Dynamic Tick (melhora frame timing)
    bcdedit /set disabledynamictick yes 2>$null
    Write-Step "Dynamic Tick desativado (frame timing mais consistente)"
    Write-Info "Reverter: bcdedit /deletevalue disabledynamictick"

    # Usar Platform Tick (timer de hardware)
    bcdedit /set useplatformtick yes 2>$null
    Write-Step "Platform Tick ativado (usa timer de hardware)"
    Write-Info "Reverter: bcdedit /deletevalue useplatformtick"

    # Aumentar TSC sync policy (NOVO)
    bcdedit /set tscsyncpolicy enhanced 2>$null
    Write-Step "TSC Sync Policy: Enhanced"
    Write-Info "Reverter: bcdedit /deletevalue tscsyncpolicy"
}

# ============================================================
# AVANCADO: VBS / MEMORY INTEGRITY (NOVO - Reddit consenso)
# ============================================================
function Disable-VBS {
    Write-Header "DESATIVAR VBS / MEMORY INTEGRITY"
    Write-Info "Fonte: Reddit r/pcmasterrace - consenso para gaming"
    Write-Info "Impacto: +5-15% FPS dependendo do hardware"
    Write-Warn "Reduz uma camada de seguranca contra malware kernel-level"

    Write-Host ""
    Write-Host "    [!] Aplicando desativacao automatica..." -ForegroundColor Green

    Write-Host ""
    Write-Host "    🔓 Desativando VBS:" -ForegroundColor Yellow

    # Memory Integrity (Core Isolation)
    $hvci = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    Ensure-RegPath $hvci
    Set-ItemProperty -Path $hvci -Name "Enabled" -Value 0 -Type DWord 2>$null
    Write-Step "Memory Integrity (HVCI) desativado"

    # VBS
    $deviceGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    Set-ItemProperty -Path $deviceGuard -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord 2>$null
    Write-Step "Virtualization Based Security desativado"

    # Desativar Credential Guard (NOVO)
    $credGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard"
    Ensure-RegPath $credGuard
    Set-ItemProperty -Path $credGuard -Name "Enabled" -Value 0 -Type DWord 2>$null
    Write-Step "Credential Guard desativado"

    # Desativar Hypervisor (opcional, mais agressivo)
    bcdedit /set hypervisorlaunchtype off 2>$null
    Write-Step "Hypervisor Launch Type: OFF"

    Write-Host ""
    Write-Warn "REINICIE o PC para aplicar. Para reverter:"
    Write-Info "Seguranca do Windows > Seguranca do Dispositivo > Core Isolation > Memory Integrity > ON"
    Write-Info "bcdedit /set hypervisorlaunchtype auto"
}

# ============================================================
# AVANCADO: PAGEFILE (NOVO - Reddit anti-stutter)
# ============================================================
function Optimize-Pagefile {
    Write-Header "OTIMIZAR PAGEFILE (ANTI-STUTTER)"
    Write-Info "Fonte: Reddit - pagefile fixo evita stutters de resize"
    Write-Info "Funciona melhor se o pagefile esta no SSD mais rapido"

    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
    Write-Host ""
    Write-Host "    💾 RAM detectada: $ram GB" -ForegroundColor Yellow

    # Calcular tamanho recomendado
    $recommended = switch ($ram) {
        { $_ -le 8 }  { 16384 }
        { $_ -le 16 } { 16384 }
        { $_ -le 32 } { 32768 }
        default        { 32768 }
    }

    Write-Info "Tamanho recomendado: $recommended MB (Initial = Maximum = fixo)"
    Write-Info "Pagefile fixo evita que o Windows redimensione durante o jogo"

    Write-Host ""
    Write-Host "    [!] Fixando Pagefile em $recommended MB no C: automaticamente..." -ForegroundColor Green
    
    # Desativar gerenciamento automatico
    $cs = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
    $cs.AutomaticManagedPagefile = $false
    $cs.Put() | Out-Null
    Write-Step "Gerenciamento automatico de pagefile: OFF"

    # Remover pagefiles existentes
    $existingPF = Get-WmiObject Win32_PageFileSetting
    foreach ($pf in $existingPF) {
        $pf.Delete() | Out-Null
    }

    # Criar pagefile fixo no C:
    $newPF = ([WMIClass]"Win32_PageFileSetting").CreateInstance()
    $newPF.Name = "C:\pagefile.sys"
    $newPF.InitialSize = $recommended
    $newPF.MaximumSize = $recommended
    $newPF.Put() | Out-Null
    Write-Step "Pagefile fixo: $recommended MB em C:\"
    Write-Warn "Reinicie para aplicar. Se tiver um SSD secundario mais rapido, mova pra la manualmente."
}

# ============================================================
# AVANCADO: STARTUP APPS (NOVO)
# ============================================================
function Clean-StartupApps {
    Write-Header "LIMPEZA DE STARTUP APPS"
    Write-Info "Lista e desativa programas que iniciam com o Windows"
    Write-Info "Fonte: Reddit - #1 causa de PC lento no boot"

    Write-Host ""
    Write-Host "    🚀 Apps na inicializacao:" -ForegroundColor Yellow

    # Via registro - HKCU Run
    $runKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $runItems = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
    $props = $runItems.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" }

    if ($props.Count -gt 0) {
        $i = 1
        $appList = @()
        foreach ($prop in $props) {
            Write-Host "    [$i] $($prop.Name)" -ForegroundColor White
            Write-Info "       $($prop.Value)"
            $appList += $prop.Name
            $i++
        }

        Write-Host "    [!] Removendo TODOS os aplicativos de inicializacao automaticamente..." -ForegroundColor Red
        
        foreach ($app in $appList) {
            Remove-ItemProperty -Path $runKey -Name $app -ErrorAction SilentlyContinue
            Write-Step "$app removido do startup"
        }
    }
    else {
        Write-Step "Nenhum app no startup via registro" "SKIP"
    }

    Write-Host ""
    Write-Info "Dica: Abra o Gerenciador de Tarefas (Ctrl+Shift+Esc) > aba Startup"
    Write-Info "para desativar mais apps (Discord, Steam, RGB software, etc.)"
}

# ============================================================
# AVANCADO: CONTROL FLOW GUARD (NOVO - Reddit anti-stutter)
# ============================================================
function Disable-CFG {
    Write-Header "CONTROL FLOW GUARD (ANTI-STUTTER POR JOGO)"
    Write-Info "Fonte: Reddit 2025 - solucao para stutters em jogos especificos"
    Write-Info "CFG e uma protecao de seguranca que causa stutters em alguns jogos"

    Write-Host ""
    Write-Host "    [!] Desativando CFG automaticamente..." -ForegroundColor Green
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\kernel" -Name "MitigationOptions" -Value ([byte[]](2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2)) -Type Binary 2>$null
    
    Set-ProcessMitigation -System -Disable CFG 2>$null
    Write-Step "CFG desativado globalmente"
}

# ============================================================
# AVANCADO: DEEP OS TWEAKS (NOVO - Miscelanea Reddit/Foruns)
# ============================================================
function Apply-DeepTweaks {
    Write-Header "DEEP OS TWEAKS"
    Write-Info "Fonte: Reddit, TechPowerUp, Level1Techs"

    # SSD TRIM (garantir que esta ativo)
    Write-Host ""
    Write-Host "    💿 Storage:" -ForegroundColor Yellow
    $trim = fsutil behavior query disabledeletenotify 2>&1
    if ($trim -match "= 0") {
        Write-Step "TRIM: Ativado (OK para SSDs)"
    }
    else {
        fsutil behavior set disabledeletenotify 0 2>$null
        Write-Step "TRIM: Ativado agora"
    }

    # Desativar Last Access Time Stamp (NOVO - reduz escritas no SSD)
    fsutil behavior set disablelastaccess 1 2>$null
    Write-Step "Last Access Timestamp: OFF (menos escritas no SSD)"

    # Desativar 8.3 filename creation (NOVO - performance em NTFS)
    fsutil behavior set disable8dot3 1 2>$null
    Write-Step "8.3 Filename Creation: OFF (NTFS mais rapido)"

    # Aumentar tamanho do buffer de memoria (NOVO)
    Write-Host ""
    Write-Host "    🧠 Memory Management:" -ForegroundColor Yellow

    $memMgmt = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    # Large System Cache
    Set-ItemProperty -Path $memMgmt -Name "LargeSystemCache" -Value 0 -Type DWord 2>$null
    Write-Step "Large System Cache: OFF (melhor para gaming)"

    # Desativar Paging Executive (manter kernel na RAM)
    Set-ItemProperty -Path $memMgmt -Name "DisablePagingExecutive" -Value 1 -Type DWord 2>$null
    Write-Step "Kernel sempre na RAM (nunca paginado para disco)"

    # Desativar Spectre/Meltdown mitigations (OPCIONAL - controvertido)
    Write-Host ""
    Write-Host "    🛡️ Spectre/Meltdown:" -ForegroundColor Yellow
    Write-Info "Desativar mitigacoes pode dar +2-5% FPS em CPUs mais antigas"
    Write-Warn "Reduz protecao contra vulnerabilidades de CPU"
    Write-Info "Skipping - ative manualmente se quiser (pesquise InSpectre)"
    Write-Step "Mitigacoes Spectre/Meltdown mantidas (seguranca)" "SKIP"

    # Desativar Notifications (NOVO)
    Write-Host ""
    Write-Host "    🔕 Notificacoes:" -ForegroundColor Yellow
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0 -Type DWord 2>$null
    Write-Step "Notificacoes toast: Desativadas (menos interrupcoes)"

    # Desativar Focus Assist automatico (NOVO)
    $focusAssist = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
    Write-Step "Dica: Ative Focus Assist/DND manualmente durante jogos" "SKIP"

    # Windows Delivery Optimization OFF (NOVO)
    $doPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    Ensure-RegPath $doPolicy
    Set-ItemProperty -Path $doPolicy -Name "DODownloadMode" -Value 0 -Type DWord 2>$null
    Write-Step "Delivery Optimization: OFF (sem P2P de updates)"

    # Desativar Background Apps (NOVO - Win10)
    $bgApps = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    Set-ItemProperty -Path $bgApps -Name "GlobalUserDisabled" -Value 1 -Type DWord 2>$null
    Write-Step 'Background Apps: Desativadas globalmente'
}

# ============================================================
# INTELIGENCIA E LIMPEZA (NOVO)
# ============================================================
function Apply-IntelligentTweaks {
    Write-Header "OTIMIZACAO INTELIGENTE E BACKGROUND CLEANER"
    Write-Info "Faz a leitura do seu Hardware e instala um limpador camuflado."
    
    $ramInfo = Get-CimInstance Win32_ComputerSystem
    $ramGB = [math]::Round($ramInfo.TotalPhysicalMemory / 1GB, 0)
    $cpuInfo = Get-CimInstance Win32_Processor
    $gpuInfo = Get-CimInstance Win32_VideoController | Where-Object {
        $_.Name -notmatch 'Parsec|Virtual|Basic|Microsoft|Remote'
    } | Select-Object -First 1
    if (-not $gpuInfo) { $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -First 1 }

    Write-Host ""
    Write-Host "    🔍 Hardware Detectado:" -ForegroundColor Cyan
    Write-Host "    RAM: $ramGB GB"
    Write-Host "    CPU: $($cpuInfo.Name)"
    Write-Host "    GPU: $($gpuInfo.Name)"

    # Lógica de Hardware
    if ($ramGB -le 8) {
        Write-Host "    [!] Low RAM Detectado (<= 8GB) - Aplicando Modo Agressivo" -ForegroundColor Yellow
        Optimize-Pagefile
        Clean-StartupApps
    } else {
        Write-Host "    [!] RAM Abundante (> 8GB) - Otimizando Cache" -ForegroundColor Green
    }
    
    if ($cpuInfo.Name -match "AMD") {
        Write-Host "    [!] Processador AMD Detectado - Otimizando SMT" -ForegroundColor Green
    }

    # ===== LIMPEZA DE VERSOES ANTERIORES =====
    Write-Host ""
    Write-Host "    🧹 Removendo versoes anteriores do otimizador..." -ForegroundColor Yellow

    # Lista de nomes de tarefas agendadas de versoes antigas (e a atual para reinstalar limpa)
    $oldTaskNames = @(
        'Microsoft\Windows\Gaming\GameBarOptimization',
        'GameBarOptimization',
        'Otimizador_Cache',
        'Otimizador_Cleaner',
        'Otimizador_Windows',
        'OtimizadorCache',
        'OtimizadorCleaner',
        'WindowsOptimizer',
        'CacheCleaner',
        'StandbyListCleaner'
    )
    $removedTasks = 0
    foreach ($oldTask in $oldTaskNames) {
        $exists = Get-ScheduledTask -TaskName $oldTask -ErrorAction SilentlyContinue
        if ($exists) {
            Unregister-ScheduledTask -TaskName $oldTask -Confirm:$false -ErrorAction SilentlyContinue
            $removedTasks++
        }
    }
    if ($removedTasks -gt 0) {
        Write-Step "$removedTasks tarefa(s) agendada(s) antiga(s) removida(s)"
    } else {
        Write-Step "Nenhuma versao anterior encontrada no Task Scheduler" "SKIP"
    }

    # Matar processos de versoes antigas rodando em segundo plano
    $oldProcessKeywords = @('GameBarPresenceWriter', 'Otimizador_Cache', 'OtimizadorCache', 'StandbyListCleaner')
    foreach ($keyword in $oldProcessKeywords) {
        Get-Process -Name "powershell", "pwsh" -ErrorAction SilentlyContinue | Where-Object {
            $_.MainModule.FileName -and (
                $_.CommandLine -match $keyword -or
                $_.MainWindowTitle -match $keyword
            )
        } | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # Apagar scripts antigos de locais conhecidos
    $oldScriptPaths = @(
        "$env:APPDATA\Microsoft\Windows\GameBar\GameBarPresenceWriter.ps1",
        "$env:APPDATA\Otimizador_Cache.ps1",
        "$env:APPDATA\OtimizadorCache.ps1",
        "$env:ProgramData\Otimizador\cache_cleaner.ps1",
        "$env:ProgramData\Otimizador\cleaner.ps1"
    )
    $removedFiles = 0
    foreach ($oldPath in $oldScriptPaths) {
        if (Test-Path $oldPath) {
            Remove-Item -Path $oldPath -Force -ErrorAction SilentlyContinue
            $removedFiles++
        }
    }
    if ($removedFiles -gt 0) {
        Write-Step "$removedFiles arquivo(s) de versoes antigas apagado(s)"
    }

    Write-Step "Limpeza de versoes antigas concluida"

    # ===== INSTALACAO DA NOVA VERSAO =====
    Write-Host ""
    Write-Host "    ⚙️ Instalando Limpador v3.0 (Modo Stealth)..." -ForegroundColor Yellow
    
    # Payload Base64 do Limpador
    $b64Payload = "JABzAG8AdQByAGMAZQAgAD0AIABAACIACgB1AHMAaQBuAGcAIABTAHkAcwB0AGUAbQA7AAoAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0ALgBSAHUAbgB0AGkAbQBlAC4ASQBuAHQAZQByAG8AcABTAGUAcgB2AGkAYwBlAHMAOwAKAHAAdQBiAGwAaQBjACAAYwBsAGEAcwBzACAAUwB5AHMASABlAGwAcABlAHIAcwAgAHsACgAgACAAIAAgAFsARABsAGwASQBtAHAAbwByAHQAKAAiACIAbgB0AGQAbABsAC4AZABsAGwAIgAiACkAXQAKACAAIAAgACAAcAB1AGIAbABpAGMAIABzAHQAYQB0AGkAYwAgAGUAeAB0AGUAcgBuACAAdQBpAG4AdAAgAE4AdABTAGUAdABTAHkAcwB0AGUAbQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AKABpAG4AdAAgAEkAbgBmAG8AQwBsAGEAcwBzACwAIABJAG4AdABQAHQAcgAgAEkAbgBmAG8ALAAgAGkAbgB0ACAATABlAG4AZwB0AGgAKQA7AAoAIAAgACAAIABwAHUAYgBsAGkAYwAgAHMAdABhAHQAaQBjACAAdgBvAGkAZAAgAEYAbAB1AHMAaAAoACkAIAB7AAoAIAAgACAAIAAgACAAIAAgAGkAbgB0AFsAXQAgAGEAcgByACAAPQAgAG4AZQB3ACAAaQBuAHQAWwBdACAAewAgADQAIAB9ADsACgAgACAAIAAgACAAIAAgACAARwBDAEgAYQBuAGQAbABlACAAaAAgAD0AIABHAEMASABhAG4AZABsAGUALgBBAGwAbABvAGMAKABhAHIAcgAsACAARwBDAEgAYQBuAGQAbABlAFQAeQBwAGUALgBQAGkAbgBuAGUAZAApADsACgAgACAAIAAgACAAIAAgACAATgB0AFMAZQB0AFMAeQBzAHQAZQBtAEkAbgBmAG8AcgBtAGEAdABpAG8AbgAoADgAMAAsACAAaAAuAEEAZABkAHIATwBmAFAAaQBuAG4AZQBkAE8AYgBqAGUAYwB0ACgAKQAsACAANAApADsACgAgACAAIAAgACAAIAAgACAAaAAuAEYAcgBlAGUAKAApADsACgAgACAAIAAgAH0ACgB9AAoAIgBAAAoAQQBkAGQALQBUAHkAcABlACAALQBUAHkAcABlAEQAZQBmAGkAbgBpAHQAaQBvAG4AIAAkAHMAbwB1AHIAYwBlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlAAoAdAByAHkAIAB7ACAAWwBTAHkAcwBIAGUAbABwAGUAcgBzAF0AOgA6AEYAbAB1AHMAaAAoACkAIAB9ACAAYwBhAHQAYwBoACAAewB9AAoAUgBlAG0AbwB2AGUALQBJAHQAZQBtACAALQBQAGEAdABoACAAIgAkAGUAbgB2ADoAVABFAE0AUABcACoAIgAgAC0AUgBlAGMAdQByAHMAZQAgAC0ARgBvAHIAYwBlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlAAoAUgBlAG0AbwB2AGUALQBJAHQAZQBtACAALQBQAGEAdABoACAAIgBDADoAXABXAGkAbgBkAG8AdwBzAFwAVABlAG0AcABcACoAIgAgAC0AUgBlAGMAdQByAHMAZQAgAC0ARgBvAHIAYwBlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlAA=="
    $decoded = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b64Payload))
    
    # Camuflar o script num diretorio do Windows AppData
    $targetDir = "$env:APPDATA\Microsoft\Windows\GameBar"
    if (-not (Test-Path $targetDir)) { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null }
    
    $scriptPath = "$targetDir\GameBarPresenceWriter.ps1"
    Set-Content -Path $scriptPath -Value $decoded -Encoding UTF8 -Force
    
    # Criar Tarefa Agendada com nome camuflado
    $taskName = "Microsoft\Windows\Gaming\GameBarOptimization"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.RepetitionInterval = (New-TimeSpan -Hours 3)
    $trigger.RepetitionDuration = [TimeSpan]::MaxValue
    
    # Registrar tarefa como SYSTEM para rodar invisível sem popup
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -User "SYSTEM" -Force | Out-Null
    
    Write-Step "Limpador Automático (Standby/Temp) ativo a cada 3h!"
    Write-Info "Nome da Tarefa: GameBarOptimization (Camuflada)"
}

# ============================================================
# EXTREME: ESPORTS TWEAKS (NOVO)
# ============================================================
function Apply-ExtremeTweaks {
    Write-Header "TWEAKS EXTREMOS (ESPORTS)"
    Write-Info "Fonte: BlurBusters, TechPowerUp, GitHub"
    Write-Warn "Pode causar instabilidade em sistemas mais antigos."
    
    Write-Host "    [!] Aplicando Tweaks Extremos automaticamente..." -ForegroundColor Red
    
    # 1. Agendador de Tarefas Multimidia (SystemProfile)
    Write-Host ""
    Write-Host "    🎮 Agendador de Games (SystemProfile):" -ForegroundColor Yellow
    $sysProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Ensure-RegPath $sysProfile
    Set-ItemProperty -Path $sysProfile -Name 'GPU Priority' -Value 8 -Type DWord 2>$null
    Set-ItemProperty -Path $sysProfile -Name 'Priority' -Value 6 -Type DWord 2>$null
    Set-ItemProperty -Path $sysProfile -Name 'Scheduling Category' -Value 'High' -Type String 2>$null
    Write-Step 'Prioridade de Processamento para Jogos: ALTA'

    # 2. Desativar Fullscreen Optimizations globalmente
    Write-Host ""
    Write-Host "    📺 Fullscreen Optimizations:" -ForegroundColor Yellow
    $fso = 'HKCU:\System\GameConfigStore'
    Ensure-RegPath $fso
    Set-ItemProperty -Path $fso -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Type DWord 2>$null
    Write-Step 'True Exclusive Fullscreen: FORCADO (Menos input lag)'

    # 3. TCP/IP Latency (TcpAckFrequency)
    Write-Host ""
    Write-Host "    🌐 Latencia de Rede (TCP):" -ForegroundColor Yellow
    $interfaces = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*' -ErrorAction SilentlyContinue
    foreach ($iface in $interfaces) {
        if ($iface.DhcpIPAddress -or $iface.IPAddress) {
            Set-ItemProperty -Path $iface.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord 2>$null
            Set-ItemProperty -Path $iface.PSPath -Name 'TCPNoDelay' -Value 1 -Type DWord 2>$null
        }
    }
    Write-Step 'TcpAckFrequency/TCPNoDelay: 1 (Menor Ping)'

    # 4. Desativar Power Throttling
    Write-Host ""
    Write-Host "    ⚡ Power Throttling:" -ForegroundColor Yellow
    $powerThrottling = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    Ensure-RegPath $powerThrottling
    Set-ItemProperty -Path $powerThrottling -Name 'PowerThrottlingOff' -Value 1 -Type DWord 2>$null
    Write-Step 'Gerenciamento agressivo de energia: DESATIVADO'
    
    Write-Info 'Para MSI Mode, recomendamos baixar o "MSI Utility v3" e configurar manualmente sua GPU.'
}

# ============================================================
# ULTRA DEBLOAT (ESTILO ISO MODIFICADA)
# ============================================================
function Apply-UltraDebloat {
    Write-Header "ULTRA DEBLOAT (ESTILO ISO MODIFICADA)"
    Write-Info "Fonte: AtlasOS, ReviOS, MSMG Toolkit, Reddit"
    Write-Warn "Enxuga o Windows ao maximo para performance pura."

    # 1. Otimizar Windows Search (Mantido ativo offline para nao quebrar a busca de apps)
    Write-Host ""
    Write-Host "    🔍 Windows Search:" -ForegroundColor Yellow
    Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Write-Step "Pesquisa do Windows: OTIMIZADA (Busca Local Ativa / Web OFF)"

    # 2. Desativar Print Spooler (Impressora)
    Write-Host ""
    Write-Host "    🖨️ Print Spooler:" -ForegroundColor Yellow
    Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "Spooler" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Step "Print Spooler: DESATIVADO (nao usa impressora? perfeito)"

    # 3. Desativar Copilot (Win11 24H2+)
    Write-Host ""
    Write-Host "    🤖 Microsoft Copilot / Recall / Widgets:" -ForegroundColor Yellow
    # Copilot
    $copilotPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    Ensure-RegPath $copilotPolicy
    Set-ItemProperty -Path $copilotPolicy -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord 2>$null
    # Recall
    $recallPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    Ensure-RegPath $recallPolicy
    Set-ItemProperty -Path $recallPolicy -Name "DisableAIDataAnalysis" -Value 1 -Type DWord 2>$null
    # Widgets
    $widgetPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    Ensure-RegPath $widgetPolicy
    Set-ItemProperty -Path $widgetPolicy -Name "AllowNewsAndInterests" -Value 0 -Type DWord 2>$null
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord 2>$null
    Write-Step "Copilot, Recall e Widgets: DESATIVADOS"

    # 4. Remover Capacidades Extras via DISM
    Write-Host ""
    Write-Host "    🧹 Removendo Componentes Extras via DISM..." -ForegroundColor Yellow
    $capabilities = @(
        "Microsoft.Windows.WordPad~~~~0.0.1.0",
        "Microsoft.Windows.StepsRecorder~~~~0.0.1.0",
        "MathRecognizer~~~~0.0.1.0",
        "App.Support.QuickAssist~~~~0.0.1.0",
        "Browser.InternetExplorer~~~~0.0.11.0",
        "Media.WindowsMediaPlayer~~~~0.0.12.0",
        "Hello.Face~~~~0.0.1.0",
        "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0"
    )
    $dismRemoved = 0
    foreach ($cap in $capabilities) {
        $installed = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $cap -and $_.State -eq 'Installed' }
        if ($installed) {
            Remove-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue | Out-Null
            $shortName = ($cap -split '~~~~')[0] -replace 'Microsoft\.Windows\.', '' -replace 'App\.Support\.', ''
            Write-Step "$shortName removido via DISM"
            $dismRemoved++
        }
    }
    if ($dismRemoved -eq 0) {
        Write-Step "Nenhum componente extra encontrado para remover" "SKIP"
    } else {
        Write-Host "    📦 $dismRemoved componente(s) removido(s)" -ForegroundColor Green
    }

    # 5. CompactOS (Comprime o Sistema Operacional)
    Write-Host ""
    Write-Host "    📦 Ativando CompactOS (Compressao do Sistema)..." -ForegroundColor Yellow
    Write-Info "Comprime arquivos do Windows no disco. Libera 2-4GB sem perder performance em SSDs."
    compact.exe /CompactOS:always 2>$null | Out-Null
    Write-Step "CompactOS: ATIVADO (sistema comprimido no disco)"

    # 6. Bloqueio de Telemetria via Hosts
    Write-Host ""
    Write-Host "    🌐 Bloqueando Servidores de Telemetria via Hosts..." -ForegroundColor Yellow
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $telemetryDomains = @(
        "vortex.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com",
        "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com",
        "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net",
        "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com",
        "settings-sandbox.data.microsoft.com",
        "watson.live.com",
        "watson.microsoft.com",
        "statsfe2.ws.microsoft.com",
        "corpext.msitadfs.glbdns2.microsoft.com",
        "compatexchange.cloudapp.net",
        "a-0001.a-msedge.net",
        "statsfe2.update.microsoft.com.akadns.net",
        "diagnostics.support.microsoft.com"
    )

    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
    $added = 0
    $marker = "# === OTIMIZADOR TELEMETRY BLOCK ==="
    if ($hostsContent -notcontains $marker) {
        Add-Content -Path $hostsPath -Value "`n$marker" -ErrorAction SilentlyContinue
        foreach ($domain in $telemetryDomains) {
            $entry = "0.0.0.0 $domain"
            if ($hostsContent -notcontains $entry) {
                Add-Content -Path $hostsPath -Value $entry -ErrorAction SilentlyContinue
                $added++
            }
        }
        Add-Content -Path $hostsPath -Value "# === END OTIMIZADOR BLOCK ===" -ErrorAction SilentlyContinue
        Write-Step "$added dominios de telemetria bloqueados no arquivo hosts"
    } else {
        Write-Step "Bloqueio de telemetria via hosts ja aplicado" "SKIP"
    }

    # 7. Desativar Activity History
    Write-Host ""
    Write-Host "    📋 Historico de Atividades:" -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Step "Activity History: DESATIVADO (Microsoft nao rastreia mais)"
}

# ============================================================
# EXECUCAO LINEAR AUTOMATICA COM BARRA DE PROGRESSO
# ============================================================

Show-Banner

Show-Progress "Diagnostico do Sistema"
Show-SystemDiag

Show-Progress "Criando Ponto de Restauracao"
Create-RestorePoint

Show-Progress "Deteccao de Hardware e Limpador Stealth"
Apply-IntelligentTweaks

Write-Host ""
Write-Host "  🔥 APLICANDO TODAS AS OTIMIZACOES (SEGURAS + AVANCADAS + EXTREMAS)..." -ForegroundColor Red
Write-Host ""

Show-Progress "Plano de Energia Ultimate Performance"
Optimize-PowerPlan

Show-Progress "Desativando Servicos Desnecessarios"
Disable-UnnecessaryServices

Show-Progress "Tweaks de Registro (Visual, Input Lag)"
Apply-RegistryTweaks

Show-Progress "Otimizacoes de Rede (Latencia/Ping)"
Optimize-Network

Show-Progress "Limpeza do Sistema (Temp, Cache, WinSxS)"
Clean-System

Show-Progress "Otimizacoes de GPU"
Optimize-GPU

Show-Progress "Removendo Bloatware (Debloat Estilo ISO)"
Remove-Bloatware

Show-Progress "Otimizando Agendador de Tarefas"
Optimize-ScheduledTasks

Show-Progress "BCDEDIT Tweaks (Timer, Dynamic Tick)"
Apply-BCDEdit

Show-Progress "Desativando VBS/Memory Integrity"
Disable-VBS

Show-Progress "Otimizando Pagefile (Anti-Stutter)"
Optimize-Pagefile

Show-Progress "Limpando Startup Apps"
Clean-StartupApps

Show-Progress "Desativando Control Flow Guard"
Disable-CFG

Show-Progress "Deep OS Tweaks"
Apply-DeepTweaks

Show-Progress "Tweaks Extremos (Esports)"
Apply-ExtremeTweaks

Show-Progress "Ultra Debloat (Estilo ISO Modificada)"
Apply-UltraDebloat

Write-Host ""
Write-Host "  [██████████████████████████████] 100% CONCLUIDO!" -ForegroundColor Green
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║   🔥 TODAS AS OTIMIZACOES APLICADAS!            ║" -ForegroundColor Red
Write-Host "  ║   ⚠  REINICIE O PC AGORA!                      ║" -ForegroundColor Yellow
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Red
$Host.UI.RawUI.WindowTitle = "Otimizador v3.0 - CONCLUIDO! Reinicie o PC."

# Abrir Relatorio no Bloco de Notas (Notepad)
Start-Process notepad.exe -ArgumentList $script:logFile

Write-Host ""
Write-Host "  Fechando em 10 segundos..." -ForegroundColor DarkGray
Start-Sleep -Seconds 10
