# Guía de MiniVibeClau.ps1

Esta guía se basa únicamente en el contenido del script `MiniVibeClau.ps1` para explicar cómo ejecutar la instalación, desinstalar, qué instala y comandos básicos para usar las extensiones.

## Comandos para Ejecutar (Instalación)

Para instalar todo, ejecuta el script en PowerShell con privilegios de administrador:

```powershell
.\MiniVibeClau.ps1
```

- El script detectará automáticamente la RAM y sugerirá modelos ligeros o potentes.
- Pedirá selección de modelos IA (Ollama).
- Instalación puede tardar tiempo (descargas de modelos, Docker, etc.).
- Requiere reinicio si no están activadas las características de WSL2.

Para simular sin instalar nada:

```powershell
.\MiniVibeClau.ps1 -DryRun
```

## Comandos para Desinstalar

El script tiene el parámetro `-Uninstall`, pero la lógica de desinstalación no está implementada (solo imprime "Desinstalación completa.").

Para desinstalar manualmente, basándose en lo que instala, ejecuta estos comandos:

```powershell
# Detener y eliminar contenedor Tabby
docker stop tabby
docker rm tabby

# Eliminar modelos Ollama (reemplaza <model> con el modelo, ej. qwen2.5-coder:1.5b)
ollama rm <model>

# Desinstalar aplicaciones vía winget
winget uninstall --id Microsoft.VisualStudioCode
winget uninstall --id Git.Git
winget uninstall --id Python.Python.3.12
winget uninstall --id OpenJS.NodeJS.LTS
winget uninstall --id Docker.DockerDesktop
winget uninstall --id Ollama.Ollama

# Eliminar directorios creados (ajusta ~ a tu directorio home)
Remove-Item -Recurse -Force ~\.tabby
Remove-Item -Recurse -Force ~\.continue
Remove-Item -Recurse -Force ~\VibeProjects

# Eliminar archivo de config
Remove-Item ~\.vibe_coding_config.json

# Desactivar características Windows (manual, desde Panel de Control o PowerShell)
# Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
# Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
# wsl --unregister Ubuntu
```

Nota: La desinstalación no elimina extensiones de VS Code ni restaura settings.json (hay backup automático).

## Explicación de lo que Instala

El script instala y configura herramientas para desarrollo con IA:

- **Aplicaciones vía winget**:
  - VS Code (Microsoft.VisualStudioCode)
  - Git (Git.Git)
  - Python 3.12 (Python.Python.3.12)
  - Node.js LTS (OpenJS.NodeJS.LTS)
  - Docker Desktop (Docker.DockerDesktop)
  - Ollama (Ollama.Ollama)

- **Características Windows**:
  - Habilita WSL2 (Microsoft-Windows-Subsystem-Linux y VirtualMachinePlatform).
  - Puede requerir reinicio.

- **WSL y Ubuntu**:
  - Instala la distro Ubuntu en WSL si no existe.

- **Ollama**:
  - Inicia Ollama como servicio.
  - Descarga modelos IA seleccionados (ej. qwen2.5-coder:1.5b o 7b, otros disponibles).

- **Tabby**:
  - Descarga imagen Docker tabbyml/tabby.
  - Ejecuta contenedor Tabby con modelo StarCoder-1B, accesible en http://localhost:8080.

- **Extensiones VS Code**:
  - Codeium.codeium: Autocompletado IA.
  - TabbyML.vscode-tabby: IA local Tabby.
  - Continue.continue: Chat IA con Ollama.
  - RooVetGit.roo-cline: Agente autónomo Roo Code.
  - enkia.tokyo-night: Tema Tokyo Night.
  - eamodio.gitlens: Visualización Git.

- **Configuraciones VS Code**:
  - Tema: Tokyo Night.
  - Fuente: Cascadia Code con ligaduras.
  - Minimap deshabilitado.
  - Perfil terminal: PowerShell.
  - Config para Roo Code: Provider Ollama, modelo seleccionado, instrucciones personalizadas.
  - Endpoint Tabby en settings.

- **Continue.dev**:
  - Crea config.json en ~/.continue/ con modelos Ollama.

- **Otros**:
  - Crea directorio VibeProjects.
  - Archivo config unificado ~/.vibe_coding_config.json.
  - Genera guía en escritorio (Guia_VibeCoding.md).

## Comandos Básicos para Usar las Extensiones

Una vez instalado:

- **Abrir carpeta de proyectos**: `code ~\VibeProjects`

- **Roo Code**: Ctrl+L (o Cmd+L en Mac) para abrir chat IA.

- **Codeium**: Tab para aceptar sugerencia de autocompletado.

- **Continue.dev**: Abre la barra lateral en VS Code, selecciona modelo y chatea.

- **Tabby**: Configurado automáticamente en VS Code, usa endpoint local.

- **GitLens**: En VS Code, vista Git en barra lateral.

- **Tokyo Night**: Tema aplicado automáticamente.

Enlaces útiles (del script):
- Ollama: https://ollama.ai/
- Tabby: https://tabby.tabbyml.com/
- Continue.dev: https://continue.dev/
- Roo Code: https://roocode.com/
- Developer: https://github.com/MrVenomSnake
