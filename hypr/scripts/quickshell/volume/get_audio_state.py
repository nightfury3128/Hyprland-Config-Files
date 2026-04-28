#!/usr/bin/env python3
import json
import re
import subprocess


def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
    except Exception:
        return ""


def parse_json(output, fallback):
    try:
        return json.loads(output) if output else fallback
    except Exception:
        return fallback


def first_valid(*values):
    for v in values:
        if v is not None:
            s = str(v).strip()
            if s and s.lower() not in ("null", "none"):
                return s
    return ""


def parse_percent(raw):
    m = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*%", str(raw))
    if not m:
        return 0
    try:
        return int(float(m.group(1)))
    except Exception:
        return 0


def get_default_nodes():
    text = run_cmd("pactl info")
    default_sink = ""
    default_source = ""
    for line in text.splitlines():
        if line.startswith("Default Sink:"):
            default_sink = line.split(":", 1)[1].strip()
        elif line.startswith("Default Source:"):
            default_source = line.split(":", 1)[1].strip()
    return default_sink, default_source


def get_volume(kind, node_id):
    return parse_percent(run_cmd(f"pactl get-{kind}-volume '{node_id}'"))


def get_mute(kind, node_id):
    return "yes" in run_cmd(f"pactl get-{kind}-mute '{node_id}'").lower()


def fallback_nodes(kind):
    # kind: sink | source | sink-input
    raw = run_cmd(f"pactl list short {kind}s")
    nodes = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        idx = parts[0].strip()
        name = parts[1].strip()
        if not idx or not name:
            continue
        nodes.append({
            "index": idx,
            "name": name,
            "mute": get_mute(kind, idx),
            "volume": {
                "mono": {
                    "value_percent": f"{get_volume(kind, idx)}%"
                }
            },
            "properties": {
                "device.description": name
            }
        })
    return nodes


def parse_wpctl_status():
    text = run_cmd("wpctl status")
    if not text:
        return [], [], []

    sinks = []
    sources = []
    apps = []
    section = ""
    domain = ""

    for raw in text.splitlines():
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped:
            continue

        if stripped == "Audio":
            domain = "audio"
            section = ""
            continue
        if stripped == "Video":
            domain = "video"
            section = ""
            continue

        if "Sinks:" in stripped:
            section = "sinks"
            continue
        if "Sources:" in stripped:
            section = "sources"
            continue
        if "Streams:" in stripped:
            section = "streams"
            continue
        if stripped.startswith("Filters:") or stripped.startswith("Devices:") or stripped.startswith("Settings"):
            section = ""
            continue

        # Ignore nested stream channel rows like "120. output_FL > ..."
        if ">" in stripped:
            continue

        if domain == "audio" and section in ("sinks", "sources"):
            m = re.search(r"^\s*[│ ]*(\*)?\s*([0-9]+)\.\s+(.+?)\s+\[vol:\s*([0-9.]+)\]", line)
            if not m:
                continue
            is_default = bool(m.group(1))
            node_id = m.group(2)
            desc = m.group(3).strip()
            vol = int(float(m.group(4)) * 100)
            node = {
                "index": node_id,
                "name": node_id,
                "mute": "[muted]" in line.lower(),
                "volume": {"mono": {"value_percent": f"{vol}%"}},
                "properties": {
                    "device.description": desc,
                    "device.icon_name": "audio-card",
                },
                "_is_default": is_default,
            }
            if section == "sinks":
                sinks.append(node)
            else:
                sources.append(node)
            continue

        if domain == "audio" and section == "streams":
            m = re.search(r"^\s*[│ ]*([0-9]+)\.\s+(.+)$", line)
            if not m:
                continue
            stream_id = m.group(1).strip()
            name = m.group(2).strip()
            if not name:
                continue
            apps.append({
                "index": stream_id,
                "name": stream_id,
                "mute": "[muted]" in line.lower(),
                "volume": {"mono": {"value_percent": "100%"}},
                "properties": {
                    "application.name": name,
                    "media.name": name,
                },
            })

    return sinks, sources, apps


def format_node(node, is_default=False, is_app=False):
    vol = 0
    vol_data = node.get("volume", {})
    if isinstance(vol_data, dict):
        if "front-left" in vol_data:
            vol = parse_percent(vol_data.get("front-left", {}).get("value_percent", "0%"))
        elif "mono" in vol_data:
            vol = parse_percent(vol_data.get("mono", {}).get("value_percent", "0%"))

    props = node.get("properties", {})
    if is_app:
        display_name = first_valid(
            props.get("application.name"),
            props.get("application.process.binary"),
            "Unknown App",
        )
        sub_desc = first_valid(
            props.get("media.name"),
            props.get("window.title"),
            props.get("media.role"),
            "Audio Stream",
        )
    else:
        display_name = first_valid(props.get("device.description"), node.get("name"), "Unknown Device")
        sub_desc = first_valid(node.get("name"), "Unknown")

    icon = first_valid(props.get("application.icon_name"), props.get("device.icon_name"), "audio-card")
    return {
        "id": str(node.get("index", "")),
        "name": sub_desc,
        "description": display_name,
        "volume": vol,
        "mute": bool(node.get("mute", False)),
        "is_default": bool(is_default),
        "icon": icon,
    }


def get_data():
    sinks = parse_json(run_cmd("pactl -f json list sinks"), [])
    sources = parse_json(run_cmd("pactl -f json list sources"), [])
    sink_inputs = parse_json(run_cmd("pactl -f json list sink-inputs"), [])
    default_sink, default_source = get_default_nodes()

    # Fallback for systems where pactl JSON output is unavailable/unreliable.
    if not sinks:
        sinks = fallback_nodes("sink")
    if not sources:
        sources = fallback_nodes("source")
    if not sink_inputs:
        sink_inputs = fallback_nodes("sink-input")

    # PipeWire-first fallback for environments where pactl cannot connect.
    if not sinks and not sources:
        w_sinks, w_sources, w_apps = parse_wpctl_status()
        if w_sinks:
            sinks = w_sinks
        if w_sources:
            sources = w_sources
        if w_apps:
            sink_inputs = w_apps

    apps = []
    for s in sink_inputs:
        props = s.get("properties", {})
        if props.get("application.id") != "org.PulseAudio.pavucontrol":
            apps.append(format_node(s, is_app=True))

    out = {
        "outputs": [format_node(s, s.get("_is_default", False) or s.get("name") == default_sink) for s in sinks],
        "inputs": [format_node(s, s.get("_is_default", False) or s.get("name") == default_source) for s in sources],
        "apps": apps,
    }
    print(json.dumps(out))


if __name__ == "__main__":
    get_data()
