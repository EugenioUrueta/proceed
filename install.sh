#!/usr/bin/env bash
# ==============================================================================
# proceed: Installer for macOS & Linux
# Terminal-native Markdown plan reviewer & approver for Herdr, agy & Pi.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin"
HERDR_CONF="$HOME/.config/herdr/config.toml"
GEMINI_HOOKS_DIR="$HOME/.gemini/config/hooks"
GEMINI_HOOKS_CONF="$HOME/.gemini/config/hooks.json"

echo -e "\033[1;36m==> Instalando proceed (Terminal Plan Reviewer & Approver)...\033[0m"

# 1. Verificar / Instalar visor de Markdown (leaf o glow)
if ! command -v leaf >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo -e "\033[33m-> Instalando 'leaf-markdown-viewer' (renderizado nativo de diagramas Mermaid y TOC)...\033[0m"
        brew install leaf-markdown-viewer || true
    fi
fi

if command -v leaf >/dev/null 2>&1; then
    echo -e "\033[32m✓ leaf (leaf-markdown-viewer) está disponible.\033[0m"
elif command -v glow >/dev/null 2>&1; then
    echo -e "\033[32m✓ glow está disponible como visor alternativo.\033[0m"
else
    if command -v brew >/dev/null 2>&1; then
        echo -e "\033[33m-> Instalando 'glow' mediante Homebrew...\033[0m"
        brew install glow || true
    else
        echo -e "\033[33m[!] Ni 'leaf' ni 'glow' encontrados. Instala uno de ellos para visualización óptima (ej. brew install leaf-markdown-viewer).\033[0m"
    fi
fi

# 2. Crear directorios base
mkdir -p "$BIN_DEST"
mkdir -p "$HOME/.config/herdr"
mkdir -p "$GEMINI_HOOKS_DIR"
SHARE_DEST="$HOME/.local/share/proceed"
mkdir -p "$SHARE_DEST"

# 3. Instalar binario principal proceed
echo -e "\033[34m-> Instalando $BIN_DEST/proceed...\033[0m"
if [ -f "$SCRIPT_DIR/bin/proceed" ]; then
    # Usar symlink para que el desarrollo local se refleje en tiempo real
    ln -sf "$SCRIPT_DIR/bin/proceed" "$BIN_DEST/proceed"
else
    REPO_URL="${PROCEED_REPO_URL:-https://raw.githubusercontent.com/eugeniourueta/proceed/main}"
    echo -e "\033[33m-> Descargando proceed desde repositorio...\033[0m"
    curl -fsSL "$REPO_URL/bin/proceed" -o "$BIN_DEST/proceed"
fi
chmod +x "$BIN_DEST/proceed"
echo -e "\033[32m✓ $BIN_DEST/proceed instalado con éxito.\033[0m"

# 4. Crear symlinks compatibles (agy-plan y pi-plan)
ln -sf "$BIN_DEST/proceed" "$BIN_DEST/agy-plan"
ln -sf "$BIN_DEST/proceed" "$BIN_DEST/pi-plan"
chmod +x "$BIN_DEST/agy-plan" "$BIN_DEST/pi-plan"
echo -e "\033[32m✓ Symlinks agy-plan y pi-plan vinculados a proceed.\033[0m"

# 4b. Descargar / Cachear mermaid.min.js para soporte de diagramas offline
MERMAID_CACHE="$SHARE_DEST/mermaid.min.js"
if [ ! -f "$MERMAID_CACHE" ]; then
    echo -e "\033[34m-> Descargando mermaid.min.js para visor de diagramas offline...\033[0m"
    if curl -fsSL --connect-timeout 5 "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js" -o "$MERMAID_CACHE" 2>/dev/null; then
        echo -e "\033[32m✓ mermaid.min.js descargado en $MERMAID_CACHE (soporte offline activo).\033[0m"
    else
        echo -e "\033[33m[!] No se pudo descargar mermaid.min.js en caché local (se usará fallback por CDN).\033[0m"
    fi
else
    echo -e "\033[32m✓ mermaid.min.js ya disponible en caché local ($MERMAID_CACHE).\033[0m"
fi

# 5. Instalar hook de Antigravity (on-plan-created.py)
echo -e "\033[34m-> Configurando hook de notificación...\033[0m"
if [ -f "$SCRIPT_DIR/hooks/on-plan-created.py" ]; then
    cp "$SCRIPT_DIR/hooks/on-plan-created.py" "$GEMINI_HOOKS_DIR/on-plan-created.py"
else
    REPO_URL="${PROCEED_REPO_URL:-https://raw.githubusercontent.com/eugeniourueta/proceed/main}"
    curl -fsSL "$REPO_URL/hooks/on-plan-created.py" -o "$GEMINI_HOOKS_DIR/on-plan-created.py"
fi
chmod +x "$GEMINI_HOOKS_DIR/on-plan-created.py"
echo -e "\033[32m✓ Hook $GEMINI_HOOKS_DIR/on-plan-created.py instalado.\033[0m"

# 6. Registrar keybinding en Herdr (~/.config/herdr/config.toml)
echo -e "\033[34m-> Configurando atajo prefix+p en Herdr...\033[0m"
touch "$HERDR_CONF"
if ! grep -q "command = \"proceed\"" "$HERDR_CONF" && ! grep -q "command = 'proceed'" "$HERDR_CONF"; then
    # Limpiar entradas antiguas si existían
    sed -i '' '/command = "agy-plan"/d' "$HERDR_CONF" 2>/dev/null || sed -i '/command = "agy-plan"/d' "$HERDR_CONF" 2>/dev/null || true
    cat << 'EOF' >> "$HERDR_CONF"

# Custom commands: proceed modal popup
[[keys.command]]
key = "prefix+p"
type = "popup"
command = "proceed"
width = "85%"
height = "85%"
EOF
    echo -e "\033[32m✓ Atajo prefix+p registrado en ~/.config/herdr/config.toml.\033[0m"
else
    echo -e "\033[32m✓ Atajo prefix+p ya configurado en Herdr.\033[0m"
fi

if command -v herdr >/dev/null 2>&1; then
    herdr server reload-config >/dev/null 2>&1 || true
    echo -e "\033[32m✓ Servidor Herdr recargado.\033[0m"
fi

# 7. Registrar Hook en ~/.gemini/config/hooks.json
if command -v python3 >/dev/null 2>&1; then
    python3 - << 'PYEOF'
import json, os

hooks_path = os.path.expanduser("~/.gemini/config/hooks.json")
data = {}
if os.path.exists(hooks_path):
    try:
        with open(hooks_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}

data["plan-reviewer"] = {
    "PostToolUse": [
        {
            "matcher": "write_file|edit_file",
            "hooks": [
                {
                    "command": "python3 ~/.gemini/config/hooks/on-plan-created.py",
                    "timeout": 5,
                    "type": "command"
                }
            ]
        }
    ]
}

os.makedirs(os.path.dirname(hooks_path), exist_ok=True)
with open(hooks_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("\033[32m✓ Hook registrado en ~/.gemini/config/hooks.json.\033[0m")
PYEOF
fi

# 8. Comprobación final de PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\033[33m[!] Recuerda agregar ~/.local/bin a tu PATH en ~/.zshrc o ~/.bashrc:\033[0m"
    echo -e "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo -e "\n\033[1;32m🎉 ¡Instalación de proceed completada con éxito!\033[0m"
echo -e "Puedes abrirlo en cualquier momento pulsando \033[1mCtrl+b p\033[0m en Herdr o ejecutando \033[1mproceed\033[0m.\n"
