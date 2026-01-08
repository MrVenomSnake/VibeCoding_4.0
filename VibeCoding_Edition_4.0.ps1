# ======================================================================================
# AI CODING INSTALLER - ULTIMATE VIBE EDITION (Windows)
# ======================================================================================
# Descripción:
#     La experiencia definitiva. Instala Entorno + IA + Estética + Control de Versiones.
#     Ajusta el rendimiento según tu RAM automáticamente.
#
# Versión: 4.0 (Ultimate)
# ======================================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

param([switch]$Uninstall)

# ======================================================================================
# 0. DETECCIÓN DE HARDWARE INTELIGENTE
# ======================================================================================

function Get-HardwareInfo {
    $ramObj = Get-CimInstance Win32_ComputerSystem
    $ramGB = [Math]::Round($ramObj.TotalPhysicalMemory / 1GB)
    
    # Decisión del modelo según RAM
    if ($ramGB -lt 16) {
        $model = "qwen2.5-coder:1.5b"
        $msg = "RAM detectada: ${ramGB}GB. Usando modelo LIGERO ($model) para evitar lentitud."
    } else {
        $model = "qwen2.5-coder:7b"
        $msg = "RAM detectada: ${ramGB}GB. Usando modelo POTENTE ($model)."
    }
    return @{ Model = $model; Msg = $msg }
}

# ======================================================================================
# CONFIGURACIÓN
# ======================================================================================

$Texts = @{
    wsl_restart = "⚠️  SE REQUIERE REINICIO PARA WSL2. Reinicia y vuelve a ejecutar."
    installing = "Instalando"
    success = "¡Entorno Ultimate Vibe Listo!"
    aesthetics = "Aplicando estética 'Pro' (Fuentes y Tema)..."
    git_config = "Configurando Git básico..."
    error_running = "Error al ejecutar"
}

# Obtener info de hardware antes de definir configuración
$HwInfo = Get-HardwareInfo
if (-not $HwInfo -or -not $HwInfo.Model) {
    Write-Host "   ❌ ERROR: No se pudo detectar la información de hardware. Usando modelo predeterminado." -ForegroundColor Red
    $HwInfo = @{ 
        Model = "qwen2.5-coder:1.5b"; 
        Msg = "Usando modelo predeterminado (qwen2.5-coder:1.5b)." 
    }
}

$Config = @{
    OllamaPort = 11434
    TabbyPort = 8080
    VSCodeSettings = "$env:APPDATA\Code\User\settings.json"
    ProjectDir = "$HOME\VibeProjects"
    
    # Modelo dinámico seleccionado arriba
    SelectedModel = $HwInfo.Model
    
    Extensions = @{
        "Codeium.codeium"       = "Codeium (Autocompletado Cloud)"
        "TabbyML.vscode-tabby"  = "Tabby (IA Local Privada)"
        "Continue.continue"     = "Continue (Chat)"
        "RooVetGit.roo-cline"   = "Roo Code (Agente Autónomo)"
        "enkia.tokyo-night"     = "Tema Tokyo Night (Estética)"
        "eamodio.gitlens"       = "GitLens (Control de versiones visual)"
    }
}

# ======================================================================================
# UTILIDADES
# ======================================================================================

function Write-Step($msg) { Write-Host "`n🔹 $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   ✅ $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "   ℹ️  $msg" -ForegroundColor Yellow }
function Write-Error($msg) { Write-Host "   ❌ $msg" -ForegroundColor Red }

# ======================================================================================
# 1. SISTEMA (WSL / DOCKER)
# ======================================================================================

function Enable-WindowsFeatures {
    Write-Step "Verificando características de Windows..."
    $restart = $false
    @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform") | ForEach-Object {
        if ((Get-WindowsOptionalFeature -Online -FeatureName $_).State -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName $_ -NoRestart | Out-Null
            $restart = $true
        }
    }
    if ($restart) {
        Write-Host "`n⛔ $($Texts.wsl_restart)" -ForegroundColor Red
        Read-Host "Presiona Enter para reiniciar"; Restart-Computer; exit
    }
    return $true
}

function Ensure-DockerRunning {
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) { 
        Write-Info "Docker no está instalado o no está en PATH."
        return $false 
    }
    if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
        $path = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $path) { 
            Start-Process $path 
            Write-Info "Iniciando Docker Desktop, esto puede tardar unos minutos..."
        }
    }
    $i=0; 
    while($i -lt 60) { # Aumentado a 60 intentos (2 minutos)
        try {
            docker ps >$null 2>$null
            if($LASTEXITCODE -eq 0){
                Write-Ok "Docker está listo."
                return $true
            }
        } catch {}
        Start-Sleep 2; $i++ 
        if ($i % 10 -eq 0) { Write-Info "Esperando a que Docker esté disponible..." }
    }
    Write-Error "Docker no pudo iniciarse después de 2 minutos."
    return $false
}

# ======================================================================================
# 2. INSTALACIÓN DE COMPONENTES
# ======================================================================================

function Install-App($Id, $Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Step "$($Texts.installing) $Name..."
        try {
            winget install -e --id $Id --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Error "ERROR: winget falló al instalar $Id ($Name). Código: $LASTEXITCODE"
                return $false
            } else {
                Write-Ok "$Name instalado exitosamente."
                # Actualizar PATH para esta sesión
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                            [System.Environment]::GetEnvironmentVariable("Path", "User")
                return $true
            }
        } catch {
            Write-Error "ERROR: Excepción al instalar $Name: $($_.Exception.Message)"
            return $false
        }
    } else { 
        Write-Ok "$Name detectado." 
        return $true
    }
}

function Install-VibeEssentials {
    Write-Step "Instalando Runtimes y Herramientas..."
    
    # Lenguajes
    $pythonInstalled = Install-App "Python.Python.3.12" "python"
    $nodeInstalled = Install-App "OpenJS.NodeJS.LTS" "node"

    # Git y Fuentes
    $gitInstalled = Install-App "Git.Git" "git"
    
    Write-Step "$($Texts.installing) Cascadia Code..."
    try {
        winget install -e --id Microsoft.CascadiaCode --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ERROR: No se pudo instalar Cascadia Code. Código: $LASTEXITCODE"
        } else {
            Write-Ok "Cascadia Code instalado exitosamente."
        }
    } catch {
        Write-Error "ERROR: Excepción al instalar Cascadia Code: $($_.Exception.Message)"
    }
    
    return ($pythonInstalled -and $nodeInstalled -and $gitInstalled)
}

# ======================================================================================
# 3. CONFIGURACIÓN FINAL (EL "VIBE")
# ======================================================================================

function Configure-Git {
    # Configuración básica para que el principiante no tenga errores al commitear
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-Step $Texts.git_config
        $email = git config --global user.email
        if ([string]::IsNullOrWhiteSpace($email)) {
            Write-Info "Configurando usuario Git genérico (necesario para VSCode)..."
            git config --global user.email "vibecoder@local.com"
            git config --global user.name "Vibe Coder"
            Write-Ok "Git configurado con usuario genérico."
        } else {
            Write-Ok "Git ya está configurado con usuario: $email"
        }
        return $true
    }
    Write-Error "Git no está disponible. No se pudo configurar."
    return $false
}

function Configure-VSCodeSettings {
    Write-Step $Texts.aesthetics
    
    $settingsPath = $Config.VSCodeSettings
    $dir = Split-Path $settingsPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    try { 
        if (Test-Path $settingsPath) {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json 
        } else {
            $json = [PSCustomObject]@{}
        }
    } catch { 
        Write-Info "Creando nueva configuración de VSCode..."
        $json = [PSCustomObject]@{} 
    }
    
    if ($json -isnot [PSCustomObject]) { $json = [PSCustomObject]@{} }

    # --- IA (ROO CODE) ---
    Add-Member -InputObject $json -MemberType NoteProperty -Name "roo-cline.apiProvider" -Value "ollama" -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "roo-cline.ollamaBaseUrl" -Value "http://localhost:11434" -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "roo-cline.ollamaModelId" -Value $Config.SelectedModel -Force

    # --- PERSONALIDAD ---
    $prompt = @"
Eres un mentor experto en 'Vibe Coding'. 
1. MANTÉN EL FLUJO: Ejecuta el código (Python/Node) automáticamente para probarlo.
2. CERO TECNICISMOS: Si falta una librería, instálala (pip install) sin preguntar mucho.
3. ESTÉTICA: Si haces una web, usa estilos modernos y bonitos por defecto.
4. GIT: Si te pido guardar, haz un commit.
"@
    Add-Member -InputObject $json -MemberType NoteProperty -Name "roo-cline.customInstructions" -Value $prompt -Force

    # --- ESTÉTICA (LOOK & FEEL) ---
    Add-Member -InputObject $json -MemberType NoteProperty -Name "workbench.colorTheme" -Value "Tokyo Night" -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "editor.fontFamily" -Value "'Cascadia Code', Consolas, 'Courier New', monospace" -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "editor.fontLigatures" -Value $true -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "editor.minimap.enabled" -Value $false -Force
    Add-Member -InputObject $json -MemberType NoteProperty -Name "terminal.integrated.defaultProfile.windows" -Value "PowerShell" -Force

    # --- TABBY ---
    Add-Member -InputObject $json -MemberType NoteProperty -Name "tabby.api.endpoint" -Value "http://localhost:$($Config.TabbyPort)" -Force

    $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Ok "VSCode: Tema Tokyo Night + Cascadia Code + Roo Configurado."
    return $true
}

function Start-OllamaService {
    if (Get-Command "ollama" -ErrorAction SilentlyContinue) {
        Write-Step "Preparando Cerebro IA..."
        
        # Comprobar si Ollama ya está corriendo
        $ollamaRunning = $false
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Config.OllamaPort)" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
            $ollamaRunning = $true
            Write-Info "Ollama ya está en ejecución."
        } catch {}
        
        # Iniciar Ollama si no está corriendo
        if (-not $ollamaRunning) {
            Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -ErrorAction SilentlyContinue
            
            # Esperar a que Ollama esté listo
            $i=0
            $ollamaReady = $false
            while($i -lt 30 -and -not $ollamaReady) {
                try {
                    Invoke-RestMethod -Uri "http://localhost:$($Config.OllamaPort)" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
                    $ollamaReady = $true
                } catch {}
                
                if (-not $ollamaReady) {
                    Start-Sleep -Seconds 2
                    $i++
                    if ($i % 5 -eq 0) { Write-Info "Esperando a que Ollama inicie ($i/30)..." }
                }
            }
            
            if (-not $ollamaReady) {
                Write-Error "Ollama no pudo iniciarse después de 60 segundos."
                return $false
            } else {
                Write-Ok "Ollama iniciado correctamente."
            }
        }
        
        $m = $Config.SelectedModel
        $modelExists = $false
        try {
            $modelExists = (ollama list 2>$null | Select-String $m) -ne $null
        } catch {
            Write-Error "Error al verificar modelos de Ollama: $($_.Exception.Message)"
        }
        
        if (-not $modelExists) {
            Write-Host "   ⬇️  Descargando $m (Optimizado para tu RAM)..." -ForegroundColor Cyan
            try {
                ollama pull $m 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "No se pudo descargar el modelo $m"
                    return $false
                }
            } catch {
                Write-Error "Error al descargar el modelo $m: $($_.Exception.Message)"
                return $false
            }
        } else { 
            Write-Ok "$m listo." 
        }
        
        return $true
    }
    
    Write-Error "Ollama no está instalado o no está en PATH."
    return $false
}

function Start-TabbyService($dockerReady) {
    if (-not $dockerReady) {
        Write-Error "Docker no está listo. No se puede iniciar Tabby."
        return $false
    }
    
    Write-Step "Iniciando Tabby..."
    $tabbyPath = "$HOME\.tabby"
    if (-not (Test-Path $tabbyPath)) { 
        New-Item -ItemType Directory -Path $tabbyPath -Force | Out-Null 
        Write-Info "Creado directorio para Tabby en $tabbyPath"
    }

    try {
        $tabbyModel = "StarCoder-1B"
        $gpuFlag = if ((Get-Command nvidia-smi -ErrorAction SilentlyContinue) -and 
                        (& nvidia-smi 2>$null; $LASTEXITCODE -eq 0)) { 
            "--device cuda" 
        } else { "" }
        
        # Verificar si la imagen existe
        $imageExists = $false
        try {
            $imageExists = (docker images tabbyml/tabby --quiet | Measure-Object).Count -gt 0
        } catch {}
        
        if (-not $imageExists) {
            Write-Host "   ⬇️  Descargando imagen Tabby..." -ForegroundColor Cyan
            docker pull tabbyml/tabby 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "No se pudo descargar la imagen de Tabby"
                return $false
            }
        }
        
        # Detener contenedor existente si existe
        docker rm -f tabby 2>$null | Out-Null
        
        # Iniciar nuevo contenedor
        Invoke-Expression "docker run -d --name tabby -p $($Config.TabbyPort):8080 -v ${tabbyPath}:/data $gpuFlag tabbyml/tabby serve --model $tabbyModel" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error al iniciar el contenedor de Tabby"
            return $false
        }
        
        # Verificar que Tabby esté funcionando
        $i = 0
        $tabbyReady = $false
        while ($i -lt 30 -and -not $tabbyReady) {
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:$($Config.TabbyPort)/v1/health" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
                $tabbyReady = $true
            } catch {}
            
            if (-not $tabbyReady) {
                Start-Sleep -Seconds 2
                $i++
                if ($i % 5 -eq 0) { Write-Info "Esperando a que Tabby inicie ($i/30)..." }
            }
        }
        
        if ($tabbyReady) {
            Write-Ok "Tabby activo y funcionando."
            return $true
        } else {
            Write-Error "Tabby no pudo iniciarse después de 60 segundos."
            return $false
        }
    } catch {
        Write-Error "Excepción al iniciar Tabby: $($_.Exception.Message)"
        return $false
    }
}

# ======================================================================================
# EJECUCIÓN MAIN
# ======================================================================================

function Uninstall-Environment {
    Write-Host "Desinstalando configuración..." -ForegroundColor Yellow
    
    # Detener y eliminar contenedores
    if (Get-Command "docker" -ErrorAction SilentlyContinue) {
        Write-Info "Deteniendo contenedores Docker..."
        docker rm -f tabby 2>$null
    }
    
    # Detener servicios
    if (Get-Command "ollama" -ErrorAction SilentlyContinue) {
        Write-Info "Deteniendo Ollama..."
        try {
            Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    # Restaurar configuración de VSCode
    $settingsPath = $Config.VSCodeSettings
    if (Test-Path $settingsPath) {
        Write-Info "Restaurando configuración de VSCode..."
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            # Eliminar configuraciones específicas
            @(
                "roo-cline.apiProvider", 
                "roo-cline.ollamaBaseUrl", 
                "roo-cline.ollamaModelId",
                "roo-cline.customInstructions",
                "tabby.api.endpoint"
            ) | ForEach-Object {
                if (Get-Member -InputObject $json -Name $_ -MemberType NoteProperty) {
                    $json.PSObject.Properties.Remove($_)
                }
            }
            
            $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
            Write-Ok "Configuración de VSCode restaurada."
        } catch {
            Write-Error "No se pudo restaurar la configuración de VSCode: $($_.Exception.Message)"
        }
    }
    
    Write-Ok "Desinstalación completada. Para desinstalar completamente, elimina manualmente:"
    Write-Host "  - VSCode y sus extensiones"
    Write-Host "  - Docker Desktop"
    Write-Host "  - Ollama"
    Write-Host "  - Python, Node.js y Git"
    Write-Host "  - La carpeta de proyectos: $($Config.ProjectDir)"
}

# INICIO DEL SCRIPT PRINCIPAL
Clear-Host
Write-Host "===================================================" -ForegroundColor Magenta
Write-Host "   ✨ ULTIMATE VIBE CODING INSTALLER ✨" -ForegroundColor White
Write-Host "==================================================="
Write-Info $HwInfo.Msg

if ($Uninstall) {
    Uninstall-Environment
    exit
}

# 1. Sistema Base
$wslEnabled = Enable-WindowsFeatures
$vsCodeInstalled = Install-App "Microsoft.VisualStudioCode" "code"
$ollamaInstalled = Install-App "Ollama.Ollama" "ollama"
$dockerInstalled = Install-App "Docker.DockerDesktop" "docker"

# 2. Herramientas Dev (Lenguajes + Git + Fuentes)
$essentialsInstalled = Install-VibeEssentials
$gitConfigured = Configure-Git

# 3. Iniciar Servicios IA
$dockerReady = Ensure-DockerRunning
$ollamaReady = Start-OllamaService

# 4. Configurar VSCode
$vscodeConfigured = $false
if ($vsCodeInstalled) {
    Write-Step "Instalando Extensiones (IA + Estética)..."
    $extensionsFailed = @()
    foreach ($ext in $Config.Extensions.Keys) {
        try {
            code --install-extension $ext --force | Out-Null
            Write-Ok "Instalado: $($Config.Extensions[$ext])"
        } catch {
            $extensionsFailed += $ext
            Write-Error "Error al instalar $ext: $($_.Exception.Message)"
        }
    }
    
    if ($extensionsFailed.Count -gt 0) {
        Write-Info "Algunas extensiones fallaron: $($extensionsFailed -join ', ')"
    }
    
    $vscodeConfigured = Configure-VSCodeSettings
} else {
    Write-Error "VSCode no está disponible. No se pudieron instalar las extensiones."
}

# 5. Tabby
$tabbyReady = Start-TabbyService -dockerReady $dockerReady

# 6. Crear Workspace
if (-not (Test-Path $Config.ProjectDir)) { 
    New-Item -ItemType Directory -Path $Config.ProjectDir -Force | Out-Null 
    Write-Ok "Carpeta de proyectos creada: $($Config.ProjectDir)"
}

# Resumen de servicios instalados
$serviciosActivos = @()
if ($dockerReady) { $serviciosActivos += "Docker" }
if ($ollamaReady) { $serviciosActivos += "Ollama ($($Config.SelectedModel))" }
if ($tabbyReady) { $serviciosActivos += "Tabby" }

Write-Host "`n===================================================" -ForegroundColor Green
Write-Host "   $($Texts.success)" -ForegroundColor Green
Write-Host "==================================================="
if ($serviciosActivos.Count -gt 0) {
    Write-Host "Servicios activos: $($serviciosActivos -join ', ')"
} else {
    Write-Info "Advertencia: No hay servicios de IA activos."
}

Write-Host "1. Se abrirá VSCode automáticamente en tu carpeta de proyectos."
Write-Host "2. Verás que el tema es oscuro y moderno (Tokyo Night)."
Write-Host "3. Haz clic en el ROBOT (Roo Code) y dile qué quieres crear."

# Abrir VSCode en la carpeta de proyectos
if ($vsCodeInstalled) {
    Start-Sleep -Seconds 2
    try {
        code $Config.ProjectDir
        Write-Ok "VSCode abierto en $($Config.ProjectDir)"
    } catch {
        Write-Error "No se pudo abrir VSCode: $($_.Exception.Message)"
        Write-Info "Abre VSCode manualmente y abre la carpeta: $($Config.ProjectDir)"
    }
} else {
    Write-Info "Instala VSCode manualmente para completar la configuración."
}