import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base: "#0d0f0e"
    property color mantle: "#0a0c0b"
    property color crust: "#070808"
    property color text: "#c8c2b6"
    property color subtext0: "#8f8a7f"
    property color subtext1: "#6b6a63"
    property color surface0: "#161917"
    property color surface1: "#1e211f"
    property color surface2: "#282b29"
    property color overlay0: "#3a3d3b"
    property color overlay1: "#4c4f4d"
    property color overlay2: "#6b6a63"
    property color blue: "#7a8a82"
    property color sapphire: "#5a6a62"
    property color peach: "#c96a4a"
    property color green: "#5a6b52"
    property color red: "#c96a4a"
    property color mauve: "#8a4a34"
    property color pink: "#d68b70"
    property color yellow: "#c9a878"
    property color maroon: "#8a4a34"
    property color teal: "#7a8a82"

    property string rawJson: ""
    readonly property string colorsPath: Quickshell.env("HOME") + "/.cache/quickshell/qs_colors.json"
    readonly property string colorsFallback: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"

    function applyColors(txt) {
        if (!txt || txt.trim() === "" || txt === root.rawJson)
            return;
        root.rawJson = txt;
        try {
            let c = JSON.parse(txt);
            if (c.base) root.base = c.base;
            if (c.mantle) root.mantle = c.mantle;
            if (c.crust) root.crust = c.crust;
            if (c.text) root.text = c.text;
            if (c.subtext0) root.subtext0 = c.subtext0;
            if (c.subtext1) root.subtext1 = c.subtext1;
            if (c.surface0) root.surface0 = c.surface0;
            if (c.surface1) root.surface1 = c.surface1;
            if (c.surface2) root.surface2 = c.surface2;
            if (c.overlay0) root.overlay0 = c.overlay0;
            if (c.overlay1) root.overlay1 = c.overlay1;
            if (c.overlay2) root.overlay2 = c.overlay2;
            if (c.blue) root.blue = c.blue;
            if (c.sapphire) root.sapphire = c.sapphire;
            if (c.peach) root.peach = c.peach;
            if (c.green) root.green = c.green;
            if (c.red) root.red = c.red;
            if (c.mauve) root.mauve = c.mauve;
            if (c.pink) root.pink = c.pink;
            if (c.yellow) root.yellow = c.yellow;
            if (c.maroon) root.maroon = c.maroon;
            if (c.teal) root.teal = c.teal;
        } catch (e) {}
    }

    FileView {
        id: themeFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyColors(text())
        Component.onCompleted: reload()
    }

    FileView {
        id: themeFallback
        path: root.colorsFallback
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!themeFile.text() || themeFile.text().trim() === "")
                root.applyColors(text())
        }
        Component.onCompleted: reload()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            themeFile.reload()
            themeFallback.reload()
        }
    }
}
