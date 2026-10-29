#!/usr/bin/env python3
"""Print the Keybinds-tab model from hypr/hyprland.lua as JSON."""

import json
import re
from pathlib import Path

HOME = Path.home()
LUA = HOME / ".config/hypr/hyprland.lua"

MOD_NAMES = {
    "SUPER": "Win",
    "SHIFT": "Shift",
    "CTRL": "Ctrl",
    "ALT": "Alt",
    "MOD4": "Win",
}

KEY_LABELS = {
    "SPACE": "Space",
    "TAB": "Tab",
    "Print": "Print",
    "left": "Left",
    "right": "Right",
    "up": "Up",
    "down": "Down",
    "mouse_down": "Scroll down",
    "mouse_up": "Scroll up",
    "mouse:272": "Left click",
    "mouse:273": "Right click",
    "XF86AudioRaiseVolume": "Volume up",
    "XF86AudioLowerVolume": "Volume down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic mute",
    "XF86MonBrightnessUp": "Brightness up",
    "XF86MonBrightnessDown": "Brightness down",
    "XF86AudioNext": "Next",
    "XF86AudioPause": "Pause",
    "XF86AudioPlay": "Play",
    "XF86AudioPrev": "Previous",
}


def load_vars(text: str) -> dict:
    found = {}
    for match in re.finditer(r'^local\s+(\w+)\s*=\s*"([^"]*)"', text, re.M):
        found[match.group(1)] = match.group(2)
    found.setdefault("terminal", "kitty")
    found.setdefault("fileManager", "dolphin")
    found.setdefault("mainMod", "SUPER")
    found.setdefault("menu", f"{HOME}/.config/hypr/scripts/rofi_show.sh")
    return found


def keybinding_section(text: str) -> str:
    start = text.find("---- KEYBINDINGS ----")
    end = text.find("---- WINDOWS AND WORKSPACES ----")
    if start >= 0 and end > start:
        return text[start:end]
    return text


def split_concat(expr: str) -> list:
    parts = []
    buf = []
    quote = None
    i = 0
    while i < len(expr):
        c = expr[i]
        if quote:
            buf.append(c)
            if c == quote and expr[i - 1] != "\\":
                quote = None
            i += 1
            continue
        if c in "\"'":
            quote = c
            buf.append(c)
            i += 1
            continue
        if expr.startswith("..", i):
            parts.append("".join(buf).strip())
            buf = []
            i += 2
            continue
        buf.append(c)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return [p for p in parts if p]


def eval_expr(expr: str, variables: dict) -> str:
    expr = expr.strip().rstrip(",").strip()
    expr = re.sub(r'os\.getenv\(\s*"HOME"\s*\)', f'"{HOME}"', expr)
    out = []
    for part in split_concat(expr):
        if len(part) >= 2 and part[0] == part[-1] and part[0] in "\"'":
            out.append(part[1:-1])
        elif part in variables:
            out.append(variables[part])
        elif part == "key":
            out.append("{key}")
        else:
            out.append(part)
    return "".join(out)


def extract_call(rest: str, name: str):
    token = name + "("
    i = rest.find(token)
    if i < 0:
        return None
    j = i + len(token)
    depth = 1
    quote = None
    buf = []
    while j < len(rest) and depth:
        c = rest[j]
        if quote:
            buf.append(c)
            if c == quote and rest[j - 1] != "\\":
                quote = None
        elif c in "\"'":
            quote = c
            buf.append(c)
        elif c == "(":
            depth += 1
            buf.append(c)
        elif c == ")":
            depth -= 1
            if depth:
                buf.append(c)
        else:
            buf.append(c)
        j += 1
    return "".join(buf).strip()


def split_combo(combo: str):
    parts = [p.strip() for p in combo.split("+") if p.strip()]
    mods = []
    keys = []
    for part in parts:
        if part.upper() in MOD_NAMES:
            mods.append(MOD_NAMES[part.upper()])
        else:
            keys.append(KEY_LABELS.get(part, part))
    key = "+".join(keys)
    if not mods:
        return (key or combo), ""
    if len(mods) == 1:
        return mods[0], key
    return "+".join(mods), key


def short_cmd(cmd: str) -> str:
    low = cmd.lower()
    if "qs_manager.sh" in low and "toggle launcher" in low:
        return "App launcher"
    if "rofi_show.sh" in low:
        return "App launcher"
    if "lock.sh" in low:
        return "Lock screen"
    if "power-toggle" in low:
        return "Power menu"
    if "pkill" in low and "quickshell" in low:
        return "Restart shell"
    if "wallpaper" in low:
        return "Wallpaper picker"
    if "game-launcher" in low:
        return "Game launcher"
    if "hyprshutdown" in low or "dispatch exit" in low:
        return "Exit Hyprland"
    if "zen-browser" in low or "google.com" in low:
        return "Zen Browser"
    if "instructure.com" in low:
        return "Canvas"
    if "outlook.com" in low:
        return "Outlook"
    if "wl-copy" in low:
        return "Screenshot to clipboard"
    if "slurp" in low:
        return "Region screenshot"
    if "grim" in low:
        return "Screenshot"
    if "playerctl next" in low:
        return "Next track"
    if "playerctl previous" in low:
        return "Previous track"
    if "play-pause" in low:
        return "Play / pause"
    if "osd_brightness.sh up" in low:
        return "Brightness up"
    if "osd_brightness.sh down" in low:
        return "Brightness down"
    if "set-volume" in low and "5%+" in cmd:
        return "Volume up"
    if "set-volume" in low:
        return "Volume down"
    if "audio_source" in low or "@default_audio_source@" in low:
        return "Mute microphone"
    if "set-mute" in low:
        return "Mute audio"
    if "kill -9" in low:
        return "Force close window"
    name = Path(cmd.strip().split()[0]).name if cmd.strip() else ""
    labels = {
        "kitty": "Open terminal",
        "dolphin": "Open files",
        "spotify": "Spotify",
        "discord": "Discord",
        "cursor": "Cursor",
    }
    return labels.get(name, name or "Run command")


def describe(rest: str, variables: dict):
    inner = extract_call(rest, "exec_cmd")
    if inner is not None:
        cmd = eval_expr(inner, variables)
        return short_cmd(cmd), cmd
    if "window.float" in rest:
        return "Toggle floating", ""
    if "window.pseudo" in rest:
        return "Pseudo tile", ""
    if "window.close" in rest:
        return "Close window", ""
    if "window.drag" in rest:
        return "Drag window", ""
    if "window.resize" in rest:
        return "Resize window", ""
    if "togglesplit" in rest:
        return "Toggle split", ""
    direction = re.search(r'direction\s*=\s*"(\w+)"', rest)
    if direction and "focus" in rest:
        return f"Focus {direction.group(1)}", ""
    workspace = re.search(r'workspace\s*=\s*("([^"]+)"|(\w+))', rest)
    if workspace:
        raw = workspace.group(2) or workspace.group(3) or ""
        move = "window.move" in rest
        named = {
            "e+1": "Next workspace" if not move else "Move to next workspace",
            "e-1": "Previous workspace" if not move else "Move to previous workspace",
            "emptynm": "Empty workspace" if not move else "Move to empty workspace",
        }
        if raw in named:
            return named[raw], ""
        prefix = "Move window to workspace" if move else "Go to workspace"
        return f"{prefix} {raw}", ""
    return "Keybind", ""


def parse(text: str) -> list:
    variables = load_vars(text)
    section = keybinding_section(text)
    rows = []
    in_for = False
    saw_workspace_loop = False
    for raw in section.splitlines():
        line = raw.strip()
        if line.startswith("for ") and "do" in line:
            in_for = True
            continue
        if in_for:
            if "hl.bind" in line and "{key}" not in line and ".." in line and "key" in line:
                saw_workspace_loop = True
            if line == "end" or line.startswith("end ") or line.startswith("end--"):
                in_for = False
                if saw_workspace_loop:
                    rows.append(("Win", "1–0", "Go to workspace", ""))
                    rows.append(("Win+Shift", "1–0", "Move window to workspace", ""))
                    saw_workspace_loop = False
            continue
        if not line.startswith("hl.bind("):
            continue
        body = line[len("hl.bind("):]
        if body.endswith(")"):
            body = body[:-1]
        comma = body.find(",")
        if comma < 0:
            continue
        combo = eval_expr(body[:comma], variables)
        action, cmd = describe(body[comma + 1 :], variables)
        k1, k2 = split_combo(combo)
        rows.append((k1, k2, action, cmd))
    return [{"k1": a, "k2": b, "action": c, "cmd": d} for a, b, c, d in rows]


def main() -> None:
    print(json.dumps(parse(LUA.read_text()), ensure_ascii=False))


if __name__ == "__main__":
    main()
