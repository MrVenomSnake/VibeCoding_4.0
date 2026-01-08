# VibeCoding Edition 4.0

## Cómo ejecutar

### Desde PowerShell

Ejecuta el siguiente comando en PowerShell como Administrador:

```
powershell.exe -ExecutionPolicy Bypass -File "VibeCoding_Edition_4.0.ps1"
```

### Desde .bat

Haz doble clic en `Install_Vibe4.0.bat`. Asegúrate de ejecutar como Administrador si es necesario.

## Lo que instala

El script instala y configura un entorno completo de desarrollo con IA integrada:

### Herramientas y Software

- **WSL2**: Subsistema de Linux para Windows.
- **Docker Desktop**: Para contenedores, usado para Tabby.
- **Visual Studio Code**: Editor de código.
- **Ollama**: Plataforma para ejecutar modelos de IA localmente.
- **Python 3.12**: Lenguaje de programación.
- **Node.js LTS**: Para desarrollo web.
- **Git**: Sistema de control de versiones.
- **Cascadia Code**: Fuente de código con ligaduras.

### Extensiones de VSCode

- **Codeium**: Autocompletado basado en IA en la nube.
- **Tabby (TabbyML)**: IA local para autocompletado.
- **Continue**: Chat de IA.
- **Roo Code (Roo Cline)**: Agente autónomo de IA.
- **Tokyo Night**: Tema oscuro y moderno.
- **GitLens**: Mejora la integración con Git.

### Configuraciones

- Tema de VSCode: Tokyo Night.
- Fuente: Cascadia Code con ligaduras.
- Configuración de Roo Code para usar Ollama localmente con modelo basado en RAM (qwen2.5-coder:1.5b para <16GB RAM, 7b para >=16GB).
- Endpoint de Tabby configurado en localhost:8080.
- Perfil de terminal: PowerShell.

### Servicios Iniciados

- **Ollama**: Ejecuta en segundo plano con el modelo seleccionado, puerto 11434.
- **Tabby**: Contenedor Docker con modelo StarCoder-1B, puerto 8080.

### Carpeta de Proyectos

Crea la carpeta `C:\Users\<TuUsuario>\VibeProjects` y abre VSCode ahí.

### Desinstalación

Para desinstalar: Ejecuta el script con el parámetro -Uninstall.

```
powershell.exe -ExecutionPolicy Bypass -File "VibeCoding_Edition_4.0.ps1" -Uninstall
