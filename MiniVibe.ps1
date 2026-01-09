<# 
.SYNOPSIS
    Vibe Coding Installer – Configura VS Code + IA (Ollama, Tabby, Continue.dev, Roo Code), Docker, WSL2 y estética.
.DESCRIPTION
    • Detecta RAM y elige automáticamente un modelo LLM (ligero o potente).  
    • Instala WSL2 (Ubuntu), Docker Desktop, Ollama, VS Code y sus extensiones.  
    • Descarga los modelos seleccionados en Ollama.  
    • Lanza Tabby en Docker (endpoint local).  
    • Configura VS Code (tema Tokyo Night, fuente Cascadia Code, ajustes IA).  
    • Genera documentación en el escritorio.  
    • Parámetro -DryRun muestra lo que haría sin tocar nada.
.PARAMETER Uninstall
    Ejecuta la rutina de desinstalación.
.PARAMETER DryRun
    Simula toda la ejecución (no escribe ni instala nada).  
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$DryRun
)

# -------------------------------------------------------------------------
# 0️⃣  Variables globales y helpers
# -------------------------------------------------------------------------
$global:VibeVersion = '5.0'
$global:DryRun     = $DryRun.IsPresent

$Banner = "VIBE CODING INSTALLER - Version $VibeVersion"

function Write-Info ($Msg) { Write-Host "INFO: $Msg" -ForegroundColor Cyan }
function Write-Ok ($Msg) { Write-Host "OK: $Msg" -ForegroundColor Green }
function Write-Warning ($Msg) { Write-Host "WARNING: $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg ($Msg) { Write-Host "ERROR: $Msg" -ForegroundColor Red }
function Write-Header ($Msg) { Write-Host "`n==== $Msg ====" -ForegroundColor Magenta }
function Write-Step ($Msg) { Write-Host "`nSTEP: $Msg" -ForegroundColor Cyan }

# -------------------------------------------------------------------------
# 1️⃣  Elevación de privilegios
# -------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Request-Admin {
    if (Test-Admin) { return }
    Write-Warning "Se requieren permisos de administrador."
    $script = $MyInvocation.MyCommand.Path
    $args   = @()
    if ($Uninstall) { $args += '-Uninstall' }
    if ($DryRun)   { $args += '-DryRun'   }
    $argStr = $args -join ' '
    $cmd    = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" $argStr"
    Start-Process powershell -Verb RunAs -ArgumentList $cmd -Wait
    exit
}

# -------------------------------------------------------------------------
# 2️⃣  Helper genérico (dry‑run consciente)
# -------------------------------------------------------------------------
function Invoke-MyCommand {
    param(
        [string]$Command,
        [switch]$IgnoreErrors
    )
    if ($global:DryRun) {
        Write-Host "[DRY-RUN] $Command"
        return @{Success=$true;Output='[DRY-RUN]'}
    }
    try {
        $out = Invoke-Expression $Command 2>&1
        return @{Success=$true;Output=$out}
    } catch {
        if (-not $IgnoreErrors) {
            Write-ErrorMsg "Error ejecutando: $Command"
            Write-ErrorMsg $_.Exception.Message
        }
        return @{Success=$false;Output=$_.Exception.Message}
    }
}
function Expand-Path { param([string]$Path) $Path.Replace('~',$HOME) }

function Prompt-YesNo {
    param([string]$Message)
    if ($global:DryRun) { return $true }
    Write-Host "[y/n] $Message" -ForegroundColor Cyan -NoNewline
    $r = Read-Host
    return $r -match '^[YySs]$'
}

# -------------------------------------------------------------------------
# 3️⃣  Información de hardware → modelo IA
# -------------------------------------------------------------------------
function Get-HardwareInfo {
    try {
        $cs  = Get-CimInstance Win32_ComputerSystem
        $ram = [Math]::Round($cs.TotalPhysicalMemory/1GB)
        if ($ram -lt 16) { $model='qwen2.5-coder:1.5b'; $msg="RAM $ram GB -> modelo ligero: $model" }
        else             { $model='qwen2.5-coder:7b';   $msg="RAM $ram GB -> modelo potente: $model" }
        return @{Model=$model;Message=$msg}
    } catch {
        Write-Warning "No se pudo leer la RAM → modelo predeterminado."
        return @{Model='qwen2.5-coder:1.5b';Message='Modelo predeterminado (ligero)'}
    }
}

# -------------------------------------------------------------------------
# 4️⃣  Configuración de datos estáticos (debe estar antes de usarse)
# -------------------------------------------------------------------------
$VibeConfig = @{
    OllamaPort   = 11434
    TabbyPort    = 8080
    VSCodeSettings = Join-Path $env:APPDATA 'Code\User\settings.json'
    ProjectDir   = Join-Path $HOME 'VibeProjects'
    ContinueDir  = '~/.continue'
    ConfigFile   = '.vibe_coding_config.json'

    Models = @{
        'qwen2.5-coder:1.5b'   = @{description='Ligero 1.5B'; size='1.5GB'}
        'qwen2.5-coder:7b'     = @{description='Balanceado 7B'; size='7GB'  }
        'deepseek-coder-v2:16b'= @{description='Potente 16B'; size='16GB' }
        'llama3:8b'            = @{description='Conversacional 8B'; size='8GB'   }
        'mistral:7b'           = @{description='Multilingue 7B'; size='7GB'   }
    }

    Extensions = @{
        'Codeium.codeium'        = 'Codeium autocompletado'
        'TabbyML.vscode-tabby'   = 'Tabby IA local'
        'Continue.continue'      = 'Continue.dev chat'
        'RooVetGit.roo-cline'    = 'Roo Code agente'
        'enkia.tokyo-night'      = 'Tema Tokyo Night'
        'eamodio.gitlens'        = 'GitLens visual'
    }
}

# -------------------------------------------------------------------------
# 5️⃣  Selección de modelo(s)
# -------------------------------------------------------------------------
function Select-Models {
    Write-Header "Selección de modelos IA"

    $i = 1
    foreach ($key in $VibeConfig.Models.Keys) {
        $info = $VibeConfig.Models[$key]
        Write-Host ("{0,2}. {1,-25} {2} ({3})" -f $i,$key,$info.description,$info.size)
        $i++
    }
    Write-Host "0. Modelo automático basado en RAM ($($HwInfo.Model))"
    while ($true) {
        $choice = Read-Host "Selecciona (0 o lista separada por comas)"
        if ($choice.Trim() -eq '0') { return @($HwInfo.Model) }

        $indices = $choice -split ',' | ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -match '^\d+$' } |
                    ForEach-Object { [int]$_ }

        $selected = @()
        foreach ($idx in $indices) {
            if ($idx -ge 1 -and $idx -le $VibeConfig.Models.Count) {
                $selected += $VibeConfig.Models.Keys[$idx-1]
            }
        }
        if ($selected) { return $selected }
        Write-Warning "Selección inválida."
    }
}

# -------------------------------------------------------------------------
# 6️⃣  Instalación de apps con winget (dry‑run aware)
# -------------------------------------------------------------------------
function Install-App {
    param([string]$WingetId,[string]$CommandName)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Ok "$CommandName ya está presente."
        return $true
    }
    Write-Step "Instalando $CommandName via winget..."
    $cmd = "winget install -e --id $WingetId --silent --accept-package-agreements --accept-source-agreements"
    $res = Invoke-MyCommand $cmd
    if ($res.Success) {
        Write-Ok "$CommandName instalado."
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + `
                    [Environment]::GetEnvironmentVariable('Path','User')
        return $true
    } else {
        Write-ErrorMsg "Fallo al instalar $CommandName."
        return $false
    }
}

# -------------------------------------------------------------------------
# 7️⃣  WSL 2 & Ubuntu
# -------------------------------------------------------------------------
function Enable-WindowsFeatures {
    Write-Step "Comprobando WSL 2 y VirtualMachinePlatform..."
    $restart=$false
    foreach ($feat in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feat).State
        if ($state -ne 'Enabled') {
            if ($global:DryRun) {
                Write-Host "[DRY‑RUN] Enable‑WindowsOptionalFeature -Online -FeatureName $feat"
            } else {
                Enable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart | Out-Null
            }
            $restart=$true
        }
    }
    if ($restart) {
        Write-Warning "Se necesita reiniciar para aplicar WSL 2."
        if (-not $global:DryRun) {
            if (Prompt-YesNo "Reiniciar ahora?") { Restart-Computer -Force }
        } else { Write-Host "[DRY‑RUN] Reinicio omitido." }
    }
    return $true
}
function Ensure-UbuntuDistro {
    Write-Step "Comprobando si Ubuntu está presente en WSL..."
    $list = wsl -l -v 2>$null
    if ($list -match 'Ubuntu') { Write-Ok "Ubuntu ya está instalado."
    } else {
        Write-Info "Instalando Ubuntu como distro por defecto."
        if ($global:DryRun) { Write-Host "[DRY‑RUN] wsl --install -d Ubuntu" }
        else {
            $res = Invoke-MyCommand "wsl --install -d Ubuntu"
            if (-not $res.Success) { Write-ErrorMsg "Falló la instalación de Ubuntu." }
        }
    }
    return $true
}

# -------------------------------------------------------------------------
# 8️⃣  Docker
# -------------------------------------------------------------------------
function Ensure-DockerRunning {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Docker no está instalado o no está en PATH."
        return $false
    }
    if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
        $exe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $exe) {
            Write-Info "Iniciando Docker Desktop..."
            if (-not $global:DryRun) {
                Start-Process $exe
                Write-Info "Esperando a que Docker esté listo (máx 2 min)…"
                $i=0
                while ($i -lt 60) {
                    try { docker ps >$null 2>$null; if($LASTEXITCODE -eq 0){ Write-Ok "Docker listo."; return $true } }
                    catch {}
                    Start-Sleep -Seconds 2; $i++
                }
                Write-ErrorMsg "Docker no respondió en 2 min."
                return $false
            } else { Write-Host "[DRY‑RUN] Iniciar Docker Desktop" }
        } else { Write-ErrorMsg "Docker Desktop no encontrado en $exe" ; return $false }
    } else { Write-Ok "Docker Desktop ya está ejecutándose." }
    return $true
}

# -------------------------------------------------------------------------
# 9️⃣  Ollama
# -------------------------------------------------------------------------
function Start-OllamaService {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Ollama no está instalado o no está en PATH."
        return $false
    }
    $running=$false
    try {
        Invoke-RestMethod -Uri "http://localhost:$($VibeConfig.OllamaPort)" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue | Out-Null
        $running=$true
        Write-Info "Ollama ya está activo."
    } catch {}
    if (-not $running) {
        Write-Step "Arrancando Ollama (serve)…"
        if ($global:DryRun) { Write-Host "[DRY‑RUN] ollama serve" }
        else { Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden }
        $i=0; while($i -lt 30) {
            try {
                Invoke-RestMethod -Uri "http://localhost:$($VibeConfig.OllamaPort)" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue | Out-Null
                $running=$true; break
            } catch { Start-Sleep -Seconds 2; $i++ }
        }
        if (-not $running) { Write-ErrorMsg "Ollama no respondió tras 60 s."; return $false }
        Write-Ok "Ollama corriendo."
    }

    foreach ($model in $VibeConfig.SelectedModels) {
        $exists=$false
        try { $exists = (ollama list 2>$null | Select-String $model) -ne $null } catch {}
        if ($exists) { Write-Ok "$model ya está disponible."; continue }

        Write-Info "Descargando modelo $model (puede tardar)…"
        $res = Invoke-MyCommand "ollama pull $model"
        if (-not $res.Success) { Write-ErrorMsg "Falló la descarga de $model."; return $false }
        Write-Ok "Modelo $model descargado."
    }
    return $true
}

# -------------------------------------------------------------------------
# 10️⃣  Detección simple de GPU (CUDA)
# -------------------------------------------------------------------------
function Get-GPUInfo {
    $info = @{CUDA=$false}
    try {
        $gpus = Get-CimInstance Win32_VideoController
        foreach ($gpu in $gpus) {
            if ($gpu.Name -match 'NVIDIA') {
                $info.CUDA=$true
                Write-Info "GPU NVIDIA detectada: $($gpu.Name)"
                break
            }
        }
    } catch {}
    return $info
}

# -------------------------------------------------------------------------
# 11️⃣  Tabby (Docker)
# -------------------------------------------------------------------------
function Start-TabbyService {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Docker no está disponible → Tabby no se iniciará."
        return $false
    }
    Write-Step "Iniciando Tabby (Docker)…"
    $dataDir = Join-Path $HOME ".tabby"
    if (-not (Test-Path $dataDir)) { if (-not $global:DryRun) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null } }

    $gpu = Get-GPUInfo
    $device = if ($gpu.CUDA) { 'cuda' } else { 'cpu' }
    Write-Info "Tabby usará el dispositivo: $device"

    $image = 'tabbyml/tabby'
    if (-not $global:DryRun) { docker pull $image >$null 2>&1 } else { Write-Host "[DRY‑RUN] docker pull $image" }

    Invoke-MyCommand "docker rm -f tabby" -IgnoreErrors | Out-Null

    $model='StarCoder-1B'
    $run = "docker run -d --name tabby -p $($VibeConfig.TabbyPort):8080 -v `"$dataDir`":/data $image serve --model $model --device $device"
    $res = Invoke-MyCommand $run
    if (-not $res.Success) { Write-ErrorMsg "Error al lanzar contenedor Tabby."; return $false }

    $i=0; while($i -lt 30) {
        try {
            Invoke-RestMethod -Uri "http://localhost:$($VibeConfig.TabbyPort)/v1/health" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue | Out-Null
            Write-Ok "Tabby activo → http://localhost:$($VibeConfig.TabbyPort)"
            return $true
        } catch { Start-Sleep -Seconds 2; $i++ }
    }
    Write-ErrorMsg "Tabby no respondió tras 60 s."
    return $false
}

# -------------------------------------------------------------------------
# 12️⃣  VS Code – encontrar ejecutable
# -------------------------------------------------------------------------
function Find-VSCode {
    foreach ($c in @('code','code-insiders','codium')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { Write-Ok "VS Code encontrado: $c"; return $c }
    }
    return $null
}
function Install-VSCodeExtensions {
    $code = Find-VSCode
    if (-not $code) { Write-ErrorMsg "VS Code no encontrado → no se instalarán extensiones."; return $false }
    $failed = @()
    foreach ($id in $VibeConfig.Extensions.Keys) {
        $cmd = "$code --install-extension $id --force"
        $res = Invoke-MyCommand $cmd -IgnoreErrors
        if ($res.Success) { Write-Ok "Instalada: $($VibeConfig.Extensions[$id])" }
        else { $failed += $id; Write-Warning "Falló: $id" }
    }
    if ($failed) { Write-Warning "Fallaron algunas extensiones: $($failed -join ', ')" }
    return $true
}

# -------------------------------------------------------------------------
# 13️⃣  Configuración del settings.json de VS Code
# -------------------------------------------------------------------------
function Configure-VSCodeSettings {
    $settings = $VibeConfig.VSCodeSettings
    $backup   = "$settings.bak"

    if (-not (Test-Path $backup) -and (Test-Path $settings)) {
        if (-not $global:DryRun) { Copy-Item $settings -Destination $backup -Force }
        else { Write-Host "[DRY‑RUN] Copia de backup $settings → $backup" }
    }

    $json = @{}
    if (Test-Path $settings) {
        try { $json = Get-Content $settings -Raw | ConvertFrom-Json -ErrorAction Stop }
        catch { Write-Warning "No se pudo leer settings.json → se crea uno nuevo." }
    }

    # Tema y fuente
    $json.'workbench.colorTheme'                     = 'Tokyo Night'
    $json.'editor.fontFamily'                        = "'Cascadia Code', Consolas, 'Courier New', monospace"
    $json.'editor.fontLigatures'                     = $true
    $json.'editor.minimap.enabled'                    = $false
    $json.'terminal.integrated.defaultProfile.windows'= 'PowerShell'

    # Roo‑Code (usa Ollama)
    $json.'roo-cline.apiProvider'   = 'ollama'
    $json.'roo-cline.ollamaBaseUrl' = "http://localhost:$($VibeConfig.OllamaPort)"
    $json.'roo-cline.ollamaModelId' = $VibeConfig.SelectedModel
    $json.'roo-cline.customInstructions' = @"
Eres un mentor experto en Vibe Coding.
- Ejecuta automáticamente el código que sugieras (Python/Node).  
- Instala librerías que falten sin preguntar.  
- Usa estilos modernos y bonitos por defecto.  
- Haz commit a Git cuando se indique.  
"@

    # Tabby endpoint
    $json.'tabby.api.endpoint' = "http://localhost:$($VibeConfig.TabbyPort)"

    if ($global:DryRun) {
        Write-Host "[DRY‑RUN] Nuevo settings.json (JSON):"
        $json | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settings -Encoding UTF8
        Write-Ok "VS Code configurado (tema, fuente, IA)."
    }
    return $true
}

# -------------------------------------------------------------------------
# 14️⃣  Configuración de Continue.dev
# -------------------------------------------------------------------------
function Configure-Continue {
    Write-Step "Generando config para Continue.dev"
    $cDir = Expand-Path $VibeConfig.ContinueDir
    if (-not (Test-Path $cDir)) {
        if (-not $global:DryRun) { New-Item -ItemType Directory -Path $cDir -Force | Out-Null }
        Write-Info "Creado $cDir"
    }

    $models = @()
    foreach ($model in $VibeConfig.SelectedModels) {
        $entry = @{
            title    = $model
            provider = 'ollama'
            model    = $model
            roles    = @('chat')
        }
        switch -Wildcard ($model) {
            '*1.5b*' { $entry.title='Qwen 1.5B (rápido)'; $entry.roles=@('autocomplete') }
            '*7b*'   { $entry.title='Qwen 7B (balanceado)'; $entry.roles=@('chat','edit','apply') }
        }
        $models += $entry
    }

    $cfg = @{
        models = $models
        allowAnonymousTelemetry = $false
        systemMessage = "Eres un asistente experto en programación. Responde siempre en español, código limpio y documentado."
    }

    $cfgPath = Join-Path $cDir "config.json"
    if ($global:DryRun) {
        Write-Host "[DRY‑RUN] Continue.dev config.json (JSON):"
        $cfg | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $cfgPath -Encoding UTF8
        Write-Ok "Configuración Continue.dev guardada en $cfgPath"
    }
}

# -------------------------------------------------------------------------
# 15️⃣  Configuración unificada (JSON)
# -------------------------------------------------------------------------
function Create-UnifiedConfig {
    Write-Step "Creando archivo de configuración unificada"
    $cfg = @{
        version       = $VibeVersion
        installed_at  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        system        = $PSVersionTable.Platform
        models        = $VibeConfig.SelectedModels
        endpoints = @{
            ollama   = "http://localhost:$($VibeConfig.OllamaPort)"
            tabby    = "http://localhost:$($VibeConfig.TabbyPort)"
            continue = Expand-Path "$($VibeConfig.ContinueDir)/config.json"
        }
        extensions    = $VibeConfig.Extensions.Keys
        project_dir   = $VibeConfig.ProjectDir
        vscode_settings = $VibeConfig.VSCodeSettings
    }
    $path = Join-Path $HOME $VibeConfig.ConfigFile
    if ($global:DryRun) {
        Write-Host "[DRY‑RUN] Unified config ($path):"
        $cfg | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        Write-Ok "Configuración unificada creada: $path"
    }
}

# -------------------------------------------------------------------------
# 16️⃣  Guía de usuario (Markdown en el escritorio)
# -------------------------------------------------------------------------
function Generate-Documentation {
    Write-Step "Generando guía (Guia_VibeCoding.md) en el escritorio"
    $desk = [Environment]::GetFolderPath('Desktop')
    $docPath = Join-Path $desk "Guia_VibeCoding.md"
    $modelList = $VibeConfig.SelectedModels -join ', '

    $content = @"
# Guia rapida – Vibe Coding Installer

**Fecha:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Version:** $VibeVersion

## Herramientas instaladas

- **VS Code** – tema Tokyo Night, fuente Cascadia Code
- **Ollama** – modelos: $modelList
- **Tabby** – http://localhost:$($VibeConfig.TabbyPort) (IA local)
- **Continue.dev** – usa los modelos locales de Ollama
- **Roo Code** – agente autonomo integrado en VS Code
- **Docker Desktop**, **WSL2 (Ubuntu)**, **Git**, **Python 3.12**, **Node LTS**

## Primeros pasos

1. Abre la carpeta de proyectos: code $($VibeConfig.ProjectDir)
2. En la barra lateral, usa Roo Code o Continue.dev para conversar con la IA.
3. Atajos utiles: Ctrl+L / Cmd+L -> chat, Tab -> aceptar sugerencia de Codeium.

## Enlaces

- Ollama -> https://ollama.ai/
- Tabby -> https://tabby.tabbyml.com/
- Continue.dev -> https://continue.dev/
- Roo Code -> https://roocode.com/

## Desinstalar (manteniendo modelos y datos de Tabby)

```powershell
.\VibeCoding_Edition.ps1 -Uninstall

```

"@

    if ($global:DryRun) {

        Write-Host "[DRY-RUN] Guía generada en $docPath"

    } else {

        Set-Content -Path $docPath -Value $content -Encoding UTF8

        Write-Ok "Guía generada en $docPath"

    }

}

# -------------------------------------------------------------------------

# Main script

# -------------------------------------------------------------------------

Request-Admin

Write-Host $Banner -ForegroundColor Magenta

$HwInfo = Get-HardwareInfo

Write-Info $HwInfo.Message

if (-not $Uninstall) {

    # Seleccionar modelos

    $VibeConfig.SelectedModels = Select-Models

    $VibeConfig.SelectedModel = $VibeConfig.SelectedModels[0]  # Para Roo-Code

    # Instalar apps

    Install-App 'Microsoft.VisualStudioCode' 'code'

    Install-App 'Git.Git' 'git'

    Install-App 'Python.Python.3.12' 'python'

    Install-App 'OpenJS.NodeJS.LTS' 'node'

    Install-App 'Docker.DockerDesktop' 'docker'

    Install-App 'Ollama.Ollama' 'ollama'

    # WSL

    Enable-WindowsFeatures

    Ensure-UbuntuDistro

    # Docker

    Ensure-DockerRunning

    # Ollama

    Start-OllamaService

    # Tabby

    Start-TabbyService

    # VS Code

    Install-VSCodeExtensions

    Configure-VSCodeSettings

    # Continue

    Configure-Continue

    # Unified config

    Create-UnifiedConfig

    # Documentation

    Generate-Documentation

    Write-Ok "Instalacion completa!"

} else {

    Write-Header "Desinstalación"

    Write-Ok "Desinstalación completa."

}
