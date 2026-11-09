#!/usr/bin/env python3
"""
Antigravity PostToolUse Hook: Runs when write_file or edit_file creates/updates a plan artifact.
Notifies Herdr with sound and toast.
"""

import sys
import os
import json
import subprocess

def main():
    try:
        raw = sys.stdin.read()
        if not raw:
            print("{}")
            return
        payload = json.loads(raw)
    except Exception:
        print("{}")
        return

    tool_call = payload.get("toolCall", {})
    args = tool_call.get("args", {})

    path = args.get("Path", "")
    if not path or not path.endswith(".md"):
        print("{}")
        return

    meta = args.get("ArtifactMetadata", {}) or {}
    is_feedback_artifact = meta.get("RequestFeedback") is True
    is_brain_path = "/brain/" in path
    is_plan_name = os.path.basename(path).startswith("plan_") or "plan" in os.path.basename(path).lower()

    if is_feedback_artifact or (is_brain_path and is_plan_name):
        if os.environ.get("HERDR_ENV") == "1":
            try:
                plan_name = os.path.basename(path)
                has_diagrams = False
                content = args.get("Content", "")
                if "```mermaid" in content:
                    has_diagrams = True
                elif os.path.exists(path):
                    try:
                        with open(path, "r", encoding="utf-8", errors="ignore") as pf:
                            if "```mermaid" in pf.read():
                                has_diagrams = True
                    except Exception:
                        pass

                diag_badge = " (📊 con diagramas)" if has_diagrams else ""
                subprocess.run(
                    [
                        "herdr", "notification", "show",
                        "📋 Plan listo para revisión",
                        "--body", f"{plan_name}{diag_badge} • Presiona prefix+p o ejecuta proceed",
                        "--sound", "request",
                    ],
                    capture_output=True,
                    timeout=3,
                )
            except Exception:
                pass

    print("{}")

if __name__ == "__main__":
    main()
