#!/usr/bin/env bash
# ==============================================================================
# agy-plan / pi-plan: Installer for macOS & Linux
# Terminal-native Markdown plan reviewer & approver for Herdr, agy & Pi.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin"
HERDR_CONF="$HOME/.config/herdr/config.toml"
GEMINI_HOOKS_DIR="$HOME/.gemini/config/hooks"
GEMINI_HOOKS_CONF="$HOME/.gemini/config/hooks.json"

echo -e "\033[1;36m==> Instalando agy-plan / pi-plan (Terminal Plan Reviewer)...\033[0m"

# 1. Verificar / Instalar glow
if ! command -v glow >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo -e "\033[33m-> Instalando 'glow' mediante Homebrew...\033[0m"
        brew install glow
    else
        echo -e "\033[33m[!] 'glow' no encontrado. Por favor instálalo (ej. brew install glow).\033[0m"
    fi
else
    echo -e "\033[32m✓ glow ya se encuentra instalado.\033[0m"
fi

# 2. Crear directorios base
mkdir -p "$BIN_DEST"
mkdir -p "$HOME/.config/herdr"
mkdir -p "$GEMINI_HOOKS_DIR"

# 3. Instalar binario agy-plan
echo -e "\033[34m-> Instalando $BIN_DEST/agy-plan...\033[0m"
if [ -f "$SCRIPT_DIR/bin/agy-plan" ]; then
    cp "$SCRIPT_DIR/bin/agy-plan" "$BIN_DEST/agy-plan"
else
    # Fallback si se ejecuta vía curl directo desde GitHub
    REPO_URL="${AGY_PLAN_REPO_URL:-https://raw.githubusercontent.com/eugeniourueta/agy-plan/main}"
    echo -e "\033[33m-> Descargando agy-plan desde repositorio...\033[0m"
    curl -fsSL "$REPO_URL/bin/agy-plan" -o "$BIN_DEST/agy-plan"
fi
chmod +x "$BIN_DEST/agy-plan"
echo -e "\033[32m✓ $BIN_DEST/agy-plan instalado con éxito.\033[0m"

# 4. Crear symlink pi-plan
ln -sf "$BIN_DEST/agy-plan" "$BIN_DEST/pi-plan"
chmod +x "$BIN_DEST/pi-plan"
echo -e "\033[32m✓ $BIN_DEST/pi-plan symlink creado.\033[0m"

# 5. Instalar hook de Antigravity (on-plan-created.py)
echo -e "\033[34m-> Configurando hook de notificación...\033[0m"
if [ -f "$SCRIPT_DIR/hooks/on-plan-created.py" ]; then
    cp "$SCRIPT_DIR/hooks/on-plan-created.py" "$GEMINI_HOOKS_DIR/on-plan-created.py"
else
    REPO_URL="${AGY_PLAN_REPO_URL:-https://raw.githubusercontent.com/eugeniourueta/agy-plan/main}"
    curl -fsSL "$REPO_URL/hooks/on-plan-created.py" -o "$GEMINI_HOOKS_DIR/on-plan-created.py"
fi
chmod +x "$GEMINI_HOOKS_DIR/on-plan-created.py"
echo -e "\033[32m✓ Hook $GEMINI_HOOKS_DIR/on-plan-created.py instalado.\033[0m"

# 6. Registrar keybinding en Herdr (~/.config/herdr/config.toml)
echo -e "\033[34m-> Configurando atajo prefix+p en Herdr...\033[0m"
touch "$HERDR_CONF"
if ! grep -q "command = \"agy-plan\"" "$HERDR_CONF" && ! grep -q "command = 'agy-plan'" "$HERDR_CONF"; then
    cat << 'EOF' >> "$HERDR_CONF"

# Custom commands: agy-plan modal popup
[[keys.command]]
key = "prefix+p"
type = "popup"
command = "agy-plan"
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

echo -e "\n\033[1;32m🎉 ¡Instalación completada con éxito!\033[0m"
echo -e "Puedes abrirlo en cualquier momento pulsando \033[1mCtrl+b p\033[0m en Herdr o ejecutando \033[1magy-plan\033[0m / \033[1mpi-plan\033[0m.\n"
