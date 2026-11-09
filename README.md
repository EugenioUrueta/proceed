# proceed ⚡📋

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-brightgreen.svg)](https://www.python.org/)
[![Terminal: Herdr](https://img.shields.io/badge/terminal-Herdr%20%2B%20Kitty-blueviolet.svg)](https://github.com/eugeniourueta/herdr)
[![Renderer: Glow](https://img.shields.io/badge/markdown-Glow-ff69b4.svg)](https://github.com/charmbracelet/glow)

> **Terminal-native Markdown plan reviewer & approver for AI coding agents ([Antigravity](https://github.com) & [Pi](https://github.com/earendil-works/pi)) inside [Herdr](https://github.com) multiplexer.**

Inspect, review, and approve agent implementation plans without leaving your terminal or switching to VS Code.

---

## 💡 Why `proceed`?

When working inside a terminal multiplexer like **Herdr** with autonomous coding agents:
1. The agent pauses to ask for human approval on an implementation plan (`plan_*.md` or `walkthrough.md`).
2. Usually, you have to leave your terminal, open VS Code or a browser, find the hidden artifact directory, read it, and return to the terminal to type `Proceed`.
3. **`proceed`** solves this: press **`Ctrl+b p`** (or run `proceed` in terminal), and an integrated **85% x 85% modal popup** appears with your formatted Markdown in full **Glow** color. Press **`a`** to approve (`Proceed`), **`f`** to send feedback, or **`Esc`** to dismiss instantly without performing any actions.

---

## ✨ Features

- 🖥️ **Herdr Modal Popup**: Bound to `prefix + p` (`Ctrl+b p`), spawning an instantaneous popup over your active agent pane.
- 🎨 **Rich Glow Markdown Rendering**: Headers, tables, diffs, code blocks, and checklists styled in full ANSI terminal colors.
- ⚡ **Instant Raw-Mode Keystrokes**:
  - **`Esc` / `q`**: Exits the list or viewer instantly (no `Enter` required).
  - **`1` - `9`**: Opens any listed document in one keystroke.
  - **`Enter`**: Opens the newest document (`[1]`).
- 🤖 **Multi-Agent Context Awareness**:
  - Automatically queries `herdr api snapshot` to identify the active agent.
  - Works seamlessly with **Antigravity CLI (`agy`)** and **Pi (`pi`)**.
  - Directs `Proceed` or feedback directly to the exact Herdr pane running the agent.
- 📂 **Chronological Artifact Browser**:
  - Lists plans and walkthroughs in descending order of modification time.
  - Shows file size, timestamp, status tags, and summaries.
  - For `agy`, reads from internal session brain (`~/.gemini/antigravity-cli/brain/<session_id>/`).
  - For `pi`, scans workspace `.md` files and `.plans/*.md` directories.
- 🛡️ **Accident-Proof Safety**:
  - Exiting a walkthrough automatically closes the modal (no extra menus).
  - Exiting a plan with `Esc`, `q`, or `Enter` closes safely with **zero commands sent**.
  - `Proceed` is only dispatched if you intentionally press **`a`**.
- 📊 **Interactive Mermaid Diagram Viewer**:
  - Automatically parses and identifies all Mermaid diagram code blocks (`flowchart`, `sequenceDiagram`, `stateDiagram`, `erDiagram`, etc.).
  - Shows diagram count badges in document lists and notifications.
  - Press **`m`** to instantly open a beautiful, dark-themed standalone viewer with zoom controls, code copy, and section navigation.
  - Zero cloud leakage and 100% offline-ready: inlines local `mermaid.min.js` directly into the generated view.
- 🔔 **Proactive Notifications**:
  - Integrated Antigravity hook sounds an alert and displays a Herdr toast whenever a new plan is ready for review (with diagram indicators).

---

## 🚀 Quick Start

### One-Line Install

Clone the repository and run the installer:

```bash
git clone https://github.com/eugeniourueta/proceed.git ~/proceed
cd ~/proceed
./install.sh
```

### What `install.sh` Does Automatically:
1. Checks and installs [`glow`](https://github.com/charmbracelet/glow) via Homebrew if needed.
2. Installs `~/.local/bin/proceed` (plus backwards-compatible symlinks `agy-plan` and `pi-plan`).
3. Installs the Antigravity lifecycle hook in `~/.gemini/config/hooks/on-plan-created.py`.
4. Registers the Herdr popup keybinding (`prefix + p`) in `~/.config/herdr/config.toml`.
5. Reloads the Herdr configuration live (`herdr server reload-config`).

> [!TIP]
> Ensure `~/.local/bin` is in your `PATH`. If not, add this to your `~/.zshrc` or `~/.bashrc`:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

---

## ⌨️ Keybindings Reference

### In Document List:
| Key | Action |
| :--- | :--- |
| **`1` .. `9`** | Open document #1 to #9 immediately |
| **`Enter`** | Open the most recent document (`[1]`) |
| **`m`** | Open Mermaid diagrams of latest document in interactive viewer |
| **`Esc`** / **`q`** | Close popup modal immediately |

### Inside Viewer (`glow`):
| Key | Action |
| :--- | :--- |
| **`j` / `k`** or **Arrows** | Scroll down / up |
| **`Space`** / **`b`** | Page down / page up |
| **`Esc`** / **`q`** | Exit viewer immediately |

### Post-Reading Action Bar (Plans only):
| Key | Action |
| :--- | :--- |
| **`a`** | **Approve plan** (Sends `Proceed` directly to agent pane) |
| **`f`** | **Send feedback** (Prompts for comment and sends to agent) |
| **`m`** | **View Mermaid diagrams** (Opens interactive viewer in browser) |
| **`l`** | Return to document list |
| **`o`** | Open document in `$EDITOR` (e.g. Neovim) |
| **`c`** | Save a local copy in current workspace directory |
| **`Esc`** / **`q`** / **`Enter`** | **Exit immediately without performing any action** |

---

## 🛠️ CLI Usage

You can also run `proceed` directly from your shell:

```bash
# Interactive viewer for the active session
proceed

# View a specific markdown file
proceed path/to/document.md

# Open Mermaid diagrams directly in interactive viewer
proceed -m
proceed --mermaid path/to/document.md

# List all session documents with summaries and timestamps
proceed --list

# Print only the absolute path to the latest plan
proceed --path

# Approve directly from terminal (sends 'Proceed' to target agent pane)
proceed --approve

# Copy the latest plan to current directory on demand
proceed --copy
```

*(Aliases `agy-plan` and `pi-plan` are also available).*

---

## 🏗️ Architecture

```mermaid
flowchart TD
    A["Agent (agy / pi) generates Plan"] --> B["Antigravity Hook / Tool Execution"]
    B --> C["Herdr Notification Toast + Sound"]
    C --> D["User presses prefix + p (Ctrl+b p)"]
    D --> E["Herdr spawns proceed (85% x 85% Modal)"]
    E --> F["herdr api snapshot identifies active agent"]
    F -->|agy| G["Load artifacts from brain session"]
    F -->|pi| H["Load artifacts from workspace & .plans/"]
    G --> I["Interactive List / Instant Preview"]
    H --> I
    I -->|Press Esc/q| J["Exit cleanly (No action)"]
    I -->|Press a| K["herdr pane run <id> Proceed"]
    I -->|Press f| L["Send feedback to agent pane"]
```

---

## 📋 Requirements

- **Operating System**: macOS or Linux
- **Terminal Multiplexer**: [Herdr](https://github.com)
- **Markdown Pager**: [Glow](https://github.com/charmbracelet/glow) (`brew install glow`)
- **Python**: 3.8+ (uses standard library: `termios`, `tty`, `select`, `json`, `subprocess`)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
