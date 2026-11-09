# AGENTS.md — Guía Operativa para Agentes de IA

Este documento define la arquitectura, directrices de desarrollo, diseño técnico y normas de verificación para agentes autónomos (y desarrolladores) que trabajen en el proyecto **proceed**.

---

## 1. Visión General del Proyecto

- **Nombre:** `proceed` (anteriormente `agy-plan` / `pi-plan`)
- **Propósito:** Revisor y aprobador nativo en terminal de planes de implementación y documentos Markdown (`plan_*.md`, `walkthrough.md`) generados por agentes de IA ([Antigravity / `agy`](https://github.com) y [Pi / `pi`](https://github.com/earendil-works/pi)), integrado en el multiplexor de terminales [Herdr](https://github.com) sobre Kitty/Ghostty.
- **Filosofía Central:**
  - **Zero-Dependency Python:** Funciona exclusivamente con la biblioteca estándar de Python 3.8+ (`termios`, `tty`, `select`, `subprocess`, `json`, `shutil`, `glob`). **PROHIBIDO** añadir dependencias externas de PyPI (`pip`, `rich`, `click`, etc.).
  - **Latencia Cero & Modal Popup:** Diseñado para abrirse en una ventana modal emergente (85% x 85% de pantalla en Herdr vía `prefix + p`), responder a pulsaciones únicas inmediatas en modo crudo (`raw terminal mode`) sin necesidad de presionar `Enter`, y cerrarse instantáneamente con `Esc` o `q`.
  - **Seguridad a Prueba de Accidentes (Accident-Proof):** La salida por `Esc`, `q` o `Enter` jamás envía comandos a los agentes. La aprobación con `Proceed` requiere pulsar deliberadamente la tecla `a`.
  - **Multi-Agente Inteligente:** Detecta automáticamente el pane activo, pestaña o directorio de trabajo de agentes `agy` o `pi` mediante la API de Herdr (`herdr api snapshot`).

---

## 2. Arquitectura del Sistema y Flujo Operativo

```mermaid
flowchart TD
    A["Agente IA (agy o pi) genera Plan/Walkthrough"] --> B["Antigravity Hook (hooks/on-plan-created.py)"]
    B --> C["Notificación Herdr (Toast + Sonido 'request')"]
    C --> D["Usuario presiona prefix + p (Ctrl+b p)"]
    D --> E["Herdr lanza bin/proceed (Modal Popup 85%x85%)"]
    E --> F["Consulta Herdr snapshot (herdr api snapshot)"]
    F --> G{"Identificación de Agente"}
    G -->|Antigravity (agy)| H["Lee brain (~/.gemini/antigravity-cli/brain/<session_id>/*.md)"]
    G -->|Pi (pi)| I["Lee workspace, .plans/*.md, plans/*.md"]
    G -->|Fallback Global| J["Escanea carpetas brain globales"]
    H --> K["Lista interactiva ordenada por mtime descendente"]
    I --> K
    J --> K
    K -->|Selección 1..9 / Enter| L["Renderizado con Glow (modo menos interactivo con Esc/q habilitados)"]
    L --> M{"Tipo de Documento"}
    M -->|Walkthrough / Resumen / Nota| N["Cierra popup al salir de Glow (Sin acciones)"]
    M -->|Plan de Implementación| O["Barra de Acciones Post-Lectura"]
    O -->|'a'| P["herdr pane run <pane_id> Proceed"]
    O -->|'f'| Q["Captura comentario y envía a pane_id"]
    O -->|'l'| K
    O -->|'o'| R["Abre documento en $EDITOR (nvim/vim)"]
    O -->|'c'| S["Copia archivo .md al directorio actual"]
    O -->|'Esc' / 'q' / 'Enter'| T["Cierre seguro inmediato sin acciones"]
```

---

## 3. Estructura del Código

```text
proceed/
├── bin/
│   └── proceed                 # CLI principal ejecutable en Python 3 (autocontenido)
├── hooks/
│   └── on-plan-created.py      # Hook PostToolUse para ciclo de vida de Antigravity
├── install.sh                  # Instalador automatizado para macOS / Linux (symlinks, glow, herdr config)
├── README.md                   # Documentación pública y referencia de atajos
├── LICENSE                     # Licencia MIT
├── .gitignore                  # Exclusiones de Git
└── AGENTS.md                   # Este documento operativo para agentes
```

### Roles de los Archivos

1. **`bin/proceed`**:
   - Binario ejecutable monolítico escrito en Python puro.
   - Lee teclado en modo crudo (`get_single_key`) manejando `termios`, buffers de escape y secuencias ANSI.
   - Inspecciona el árbol de procesos y estado de Herdr a través de `herdr api snapshot`.
   - Rastrea artefactos `.md` y lee metadatos `.metadata.json` para extraer resúmenes (`summary`) y banderas de retroalimentación (`requestFeedback`).
   - Extrae bloques ` ```mermaid ` con sus encabezados de contexto y genera visores HTML interactivos con tema oscuro Vesper y controles (zoom, copia de código, navegación).
   - Inyecta `mermaid.min.js` en línea desde `~/.local/share/proceed/mermaid.min.js` para funcionamiento 100% offline y privado.
   - Invoca el visor en cascada inteligente: prioridad `leaf` (diagramas Mermaid Unicode nativos en terminal, TOC y búsqueda interactiva), fallback a `glow` (con banner de advertencia y `lesskey`), o `less`.
   - Modos no interactivos soportados: `--list`, `--path`, `--approve`, `--copy`, `--mermaid` (`-m`), `--viewer`.

2. **`hooks/on-plan-created.py`**:
   - Gancho de integración ejecutado tras `write_file` o `edit_file` en Antigravity.
   - Recibe payload JSON por `stdin`.
   - Detecta si el archivo es un plan (`ArtifactMetadata.RequestFeedback == true` o ruta en `/brain/` con nombre que contiene `plan`).
   - Identifica si contiene diagramas Mermaid para reflejarlo en la notificación.
   - Si `HERDR_ENV == "1"`, dispara una alerta nativa usando `herdr notification show "📋 Plan listo para revisión" --sound request`.

3. **`install.sh`**:
   - Script Bash con `set -euo pipefail`.
   - Instala `bin/proceed` en `~/.local/bin/proceed`.
   - Configura symlinks hacia `agy-plan` y `pi-plan` para compatibilidad retroactiva.
   - Crea `~/.local/share/proceed` y descarga `mermaid.min.js` para soporte offline.
   - Copia el hook en `~/.gemini/config/hooks/on-plan-created.py` y lo registra si es necesario.
   - Modifica `~/.config/herdr/config.toml` agregando el binding `prefix + p` (`popup "proceed" --width 85% --height 85%`).
   - Ejecuta `herdr server reload-config` para aplicar cambios en caliente.

---

## 4. Componentes Clave & Detalles de Implementación

### A. Modo de Terminal Crudo (`get_single_key`)
- El script no utiliza `input()` para navegación ni selección de documentos, ya que `input()` bloquea hasta presionar `Enter`.
- Usa `termios.tcgetattr`, `tty.setraw` y `select.select` con timeout de 50ms para diferenciar una pulsación solitaria de `Escape` (`\x1b`) de secuencias de escape ANSI completas (como flechas de dirección).
- Teclas mapeadas:
  - `Esc`, `Ctrl+C`, `Ctrl+D`, `Ctrl+Z` -> Retornan `'esc'`.
  - `q`, `Q` -> Retornan `'q'`.
  - `Enter` (`\r`, `\n`) -> Retorna `'enter'`.
  - Caracteres estándar -> Retornan el carácter en minúsculas.

### B. Algoritmo de Resolución de Agentes (`resolve_agy_agent`)
Cuando hay múltiples paneles o pestañas en Herdr, `proceed` aplica la siguiente prioridad de resolución:
1. **Pane de Origen (`HERDR_PANE_ID`):** Si `proceed` se ejecuta dentro de un terminal hijo del pane del agente.
2. **Pane Enfocado (`focused_pane_id`):** Si el usuario pulsó el atajo `prefix + p` mientras estaba posicionado sobre el pane del agente.
3. **Pestaña Enfocada (`focused_tab_id`):** Si hay un agente en la pestaña actual.
4. **Directorio de Trabajo (`cwd`):** Coincidencia entre el directorio de ejecución y el `cwd` del agente.
5. **Selector Interactivo:** Si aún existen ambigüedades, despliega un menú numerado mostrando el nombre del agente, pestaña, pane y último documento generado.

### C. Detección Inteligente del Tipo de Documento
- **Walkthroughs y Resúmenes Informativos:** Si el documento no requiere aprobación (`is_walkthrough` o sin `request_feedback`), al salir de `glow` el programa finaliza de inmediato (`sys.exit(0)`), cerrando la ventana modal de Herdr sin pasos extra.
- **Planes de Implementación:** Si el archivo es un plan o solicita retroalimentación, tras el visor `glow` se presenta la barra interactiva con opciones de aprobación (`[a]`), comentarios (`[f]`), ver diagramas (`[m]`), lista (`[l]`), editor (`[o]`), copia (`[c]`) o salida segura (`[Esc/q/Enter]`).

### D. Motor de Visualización de Diagramas Mermaid (`open_mermaid_viewer`)
- **Extracción contextual:** Parsea bloques ` ```mermaid ` y los asocia al encabezado de sección precedente más cercano.
- **Renderizado HTML Autónomo:** Genera una página local en `/tmp/proceed_<name>_<hash>.html` con tema oscuro adaptado a la estética Vesper de Herdr.
- **Soporte Offline & Privacidad:** Si existe `~/.local/share/proceed/mermaid.min.js`, el script JavaScript se incrusta directamente en el archivo HTML, eliminando llamadas de red y garantizando funcionamiento offline sin filtración de datos de arquitectura.
- **Navegación Fluida:** El visor en navegador se lanza de forma asíncrona (`open` / `xdg-open`), manteniendo el popup de Herdr interactivo para enviar aprobaciones o comentarios sin interrupciones.

---

## 5. Reglas Mandatorias para Agentes de IA

Cualquier agente que modifique o extienda este repositorio DEBE acatar estrictamente:

1. **Cero Dependencias Externas en Python:**
   - Mantener el script estrictamente autocontenido en la biblioteca estándar de Python.
   - No usar paquetes que requieran `pip install`.
2. **Preservación de la Compatibilidad Retroactiva:**
   - No alterar el soporte para la ejecución mediante los nombres de alias `agy-plan` y `pi-plan`.
   - Ambos nombres son leídos en `sys.argv[0]` para priorizar la resolución del tipo de agente (`agy` vs `pi`).
3. **Seguridad en Salidas (Zero Unintended Approvals):**
   - `Esc`, `q` y `Enter` en la barra post-lectura deben finalizar con código de salida 0 sin ejecutar comandos sobre panes de Herdr.
   - Nunca asumir aprobación automática ni ejecutar `herdr pane run` sin confirmación explícita `a`.
4. **No Bloquear Terminales:**
   - Evitar llamadas bloqueantes o sleeps extensos.
   - Respetar timeouts cortos (3 a 5 segundos) en subprocesos con `herdr`.
5. **Formato de Commits:**
   - Commits atómicos y claros en **español** siguiendo Conventional Commits (`feat: ...`, `fix: ...`, `refactor: ...`, `test: ...`, `chore: ...`).
   - Sin firmas de IA o marcas tipo `Co-authored-by`.

---

## 6. Verificación y Calidad

Antes de finalizar cualquier cambio en este repositorio, se deben ejecutar los siguientes pasos de verificación:

### A. Comprobación de Sintaxis Python
```bash
python3 -m py_compile bin/proceed hooks/on-plan-created.py
```
*Debe retornar código 0 sin advertencias ni errores de sintaxis.*

### B. Comprobación de Scripts Shell
```bash
bash -n install.sh
```
*Debe validar la sintaxis sin errores.*

### C. Prueba de Ejecución de Ayuda y Flags CLI
```bash
./bin/proceed --help
```
*Debe desplegar la descripción del parser argparse correctamente.*

### D. Pruebas de Modos No Interactivos (si hay planes disponibles)
```bash
./bin/proceed --list
./bin/proceed --path
```
