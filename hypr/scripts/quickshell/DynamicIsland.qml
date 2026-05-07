import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."
import "./pet"
import "./pages"
import "./collapsed"

PanelWindow {
    id: islandWindow

    WlrLayershell.namespace: "qs-island"
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: expanded
    color: "transparent"
    screen: islandWindow.targetScreen

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(v) { return scaler.s(v); }

    implicitHeight: s(720)

    // =========================================================
    // --- THEME ---
    // =========================================================
    MatugenColors { id: mocha }
    readonly property color base:     mocha.base
    readonly property color surface0: mocha.surface0
    readonly property color surface1: mocha.surface1
    readonly property color surface2: mocha.surface2
    readonly property color text:     mocha.text
    readonly property color subtext0: mocha.subtext0
    readonly property color mauve:    mocha.mauve
    readonly property color blue:     mocha.blue
    readonly property color peach:    mocha.peach
    readonly property color green:    mocha.green
    readonly property color pink:     mocha.pink
    readonly property color teal:     mocha.teal
    readonly property color red:      mocha.red
    readonly property color yellow:   mocha.yellow

    // =========================================================
    // --- STATE ---
    // =========================================================
    property bool expanded:      false
    property bool hovered:       false
    property bool userIsSeeking: false
    property string activeWindowClass: ""
    property string activeWindowTitle: ""
    // Hyprland fullscreen: 0 none, 1 fullscreen, 2 maximized — hide chrome only for real fullscreen.
    property bool activeWindowFullscreen: false
    property bool bravePriorityActive: false
    property double braveSuppressUntil: 0
    readonly property bool isSpotifyWindow: (activeWindowClass || "").toLowerCase().indexOf("spotify") >= 0
    readonly property bool isBraveWindow: {
        let c = (activeWindowClass || "").toLowerCase();
        return c.indexOf("brave") >= 0;
    }
    readonly property bool braveAutoAllowed: Date.now() >= braveSuppressUntil

    // Multi-screen: island follows the focused monitor
    property string activeMonitor: ""
    property var targetScreen: {
        let screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === islandWindow.activeMonitor) return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // Page navigation: "clock" | "timer" | "music" | "notifs"
    property string currentPage: "clock"
    property string prevPage:    "clock"
    property bool   notifAutoSwitched: false
    property double manualPageHoldUntil: 0
    onCurrentPageChanged: {
        if (currentPage !== "notifs") { prevPage = currentPage; notifAutoSwitched = false; }
        if (currentPage === "notifs" && !expanded && notifAutoSwitched) notifPageRevertTimer.restart();
        else notifPageRevertTimer.stop();
    }
    property var availablePages: {
        let p = ["clock", "timer"];
        if (islandWindow.isBraveWindow && islandWindow.activeWindowTitle !== "") p.push("app");
        if (islandWindow.isRecording)   p.push("recording");
        if (islandWindow.discordInCall) p.push("discord");
        if (islandWindow.isMediaActive) p.push("music");
        if (notifHistory.count > 0 || islandWindow.notifActive) p.push("notifs");
        if (islandWindow.stashModel.count > 0) p.push("stash");
        return p;
    }
    onAvailablePagesChanged: {
        if (availablePages.indexOf(currentPage) < 0)
            currentPage = availablePages.length > 0 ? availablePages[0] : "clock";
    }
    function navigateNext() {
        manualPageHoldUntil = Date.now() + 2500;
        let i = availablePages.indexOf(currentPage);
        currentPage = availablePages[(i + 1) % availablePages.length];
    }
    function navigatePrev() {
        manualPageHoldUntil = Date.now() + 2500;
        let i = availablePages.indexOf(currentPage);
        currentPage = availablePages[(i - 1 + availablePages.length) % availablePages.length];
    }

    // Timer / Stopwatch
    property int timerPresetSec: 300
    property int timerRemainingSec: 0
    property bool timerRunning: false
    property int stopwatchElapsedSec: 0
    property bool stopwatchRunning: false
    readonly property bool chronoActive: timerRunning || stopwatchRunning || timerRemainingSec > 0 || stopwatchElapsedSec > 0
    readonly property bool timerChipVisible: !expanded && !osdActive && (timerRunning || timerRemainingSec > 0)
    readonly property bool stopwatchChipVisible: !expanded && !osdActive && (stopwatchRunning || stopwatchElapsedSec > 0)
    readonly property bool chronoEdgeCompact: !expanded || currentPage !== "timer"

    function fmtChrono(sec) {
        let t = Math.max(0, parseInt(sec) || 0);
        let h = Math.floor(t / 3600);
        let m = Math.floor((t % 3600) / 60);
        let s2 = t % 60;
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s2 < 10 ? "0" : "") + s2;
        return (m < 10 ? "0" : "") + m + ":" + (s2 < 10 ? "0" : "") + s2;
    }

    function parseChronoInput(raw) {
        let t = (raw || "").trim();
        if (t === "") return 0;
        let parts = t.split(":");
        let nums = [];
        for (let i = 0; i < parts.length; i++) {
            let n = parseInt(parts[i]);
            if (isNaN(n) || n < 0) return 0;
            nums.push(n);
        }
        if (nums.length === 1) return nums[0]; // "30" => 30 seconds
        if (nums.length === 2) return nums[0] * 60 + nums[1]; // mm:ss
        if (nums.length === 3) return nums[0] * 3600 + nums[1] * 60 + nums[2]; // hh:mm:ss
        return 0;
    }

    function startTimer(seconds) {
        let val = Math.max(1, parseInt(seconds) || 0);
        timerRemainingSec = val;
        timerPresetSec = val;
        timerRunning = true;
        stopwatchRunning = false;
    }

    function toggleTimer() {
        if (timerRemainingSec <= 0) timerRemainingSec = Math.max(1, timerPresetSec || 300);
        timerRunning = !timerRunning;
        if (timerRunning) stopwatchRunning = false;
    }

    function resetTimer() {
        timerRunning = false;
        timerRemainingSec = 0;
    }

    function toggleStopwatch() {
        stopwatchRunning = !stopwatchRunning;
        if (stopwatchRunning) timerRunning = false;
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchElapsedSec = 0;
    }

    // Music
    property var musicData: ({
        "status": "Stopped", "title": "", "artist": "", "artUrl": "",
        "percent": 0, "positionStr": "00:00", "lengthStr": "00:00",
        "length": 1, "playerName": ""
    })
    property bool isMediaActive: musicData.status !== "Stopped" && musicData.title !== "" && musicData.title !== "Not Playing"

    // Equalizer
    property var eqData: ({ "preset": "Flat", "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
                             "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0 })

    // CAVA live bars — individual real props so QML bindings update reliably
    property real cavaBar0: 0.1
    property real cavaBar1: 0.1
    property real cavaBar2: 0.1
    property real cavaBar3: 0.1
    property real cavaMax:  0.1  // loudest bar, drives glow

    // Notifications
    property bool notifActive:            false
    property var  notifData:              null
    property bool wasExpandedBeforeNotif: false
    property bool notifBadgeVisible:      false
    property bool dndEnabled:             false

    // Launcher
    property bool launcherActive: false

    // Discord voice
    property bool discordInCall:     false
    property int  discordCallSeconds: 0
    property int  _discordCallStart:  0

    // OSD
    property bool   osdActive: false
    property string osdType:   ""   // "layout" | "volume" | "brightness"
    property string osdValue:  ""

    Timer {
        id: osdTimer; interval: 1500
        onTriggered: islandWindow.osdActive = false
    }

    // VPN
    property bool   vpnActive:       false
    property string vpnInterface:    ""
    property bool   vpnBadgeVisible: false
    property bool   vpnBadgeConnect: true

    onVpnActiveChanged: {
        vpnBadgeConnect = vpnActive;
        vpnBadgeVisible = true;
        vpnBadgeTimer.restart();
    }

    // Screen recording
    property bool isRecording:          false
    property bool isRecordingPaused:    false
    property int  recordingSeconds:     0
    property real recordingDotOpacity:  1.0

    ListModel { id: notifHistoryList }
    property alias notifHistory: notifHistoryList

    ListModel { id: stashModelList }
    property alias stashModel: stashModelList
    property bool isDragHovered: false
    property bool _dropJustOccurred: false
    property int stashExpandedHeight: 260
    property bool _isRefreshingStash: false

    Process {
        id: stashScanner
        command: ["bash", "-c", "mkdir -p \"$HOME/Downloads/qs_stash\" && ls -1p \"$HOME/Downloads/qs_stash/\" 2>/dev/null | grep -v 'drop_debug.txt' | grep -v 'drop_log.txt' | sed \"s|^|$HOME/Downloads/qs_stash/|\""]
        stdout: StdioCollector {
            onStreamFinished: {
                islandWindow._isRefreshingStash = true;
                let files = this.text.trim().split('\n');
                islandWindow.stashModel.clear();
                for (let i = 0; i < files.length; i++) {
                    if (files[i]) {
                        var isDirectory = files[i].endsWith('/');
                        var fullPath = isDirectory ? files[i].slice(0, -1) : files[i];
                        islandWindow.stashModel.append({
                            fileURL: "file://" + fullPath,
                            filePath: fullPath,
                            isFav: false,
                            isDir: isDirectory
                        });
                    }
                }
                islandWindow._isRefreshingStash = false;
            }
        }
    }

    Component.onCompleted: stashScanner.running = true

    ListModel { id: topSitesModel }
    property alias topSites: topSitesModel

    // Pulse animations — lifted to island level so pages can bind to them
    property real notifPulse: 0.9
    SequentialAnimation on notifPulse {
        running: islandWindow.notifActive; loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.9; duration: 900; easing.type: Easing.InOutSine }
    }

    property real musicPulse: 0.22
    SequentialAnimation on musicPulse {
        running: islandWindow.isMediaActive && islandWindow.musicData.status === "Playing" && !islandWindow.expanded && !islandWindow.notifActive
        loops: Animation.Infinite
        NumberAnimation { to: 0.72; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.22; duration: 1000; easing.type: Easing.InOutSine }
    }

    SequentialAnimation on recordingDotOpacity {
        running: islandWindow.isRecording && !islandWindow.isRecordingPaused; loops: Animation.Infinite
        NumberAnimation { to: 0.15; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
    }

    onIsRecordingPausedChanged: { if (isRecordingPaused) recordingDotOpacity = 0.38; }

    // Recording seconds counter — paused when recording is paused
    Timer {
        id: recordingSecTimer
        interval: 1000; repeat: true
        running: islandWindow.isRecording && !islandWindow.isRecordingPaused
        onTriggered: islandWindow.recordingSeconds++
    }

    // Volume drag
    property int  currentVol:      50
    property real volStretch:      0.0
    property bool volDragging:     false
    property real volDragStartX:   0.0
    property int  volDragStartVol: 50

    SpringAnimation on volStretch {
        to: 0.0; spring: 5.0; damping: 0.45
        running: !islandWindow.volDragging
    }

    // Visual edge shift caused by elastic stretch (origin at 8%/92% of collapsedW)
    readonly property real volRightExtra: volStretch > 0 ? islandShape.collapsedW * 0.92 * volStretch * 0.26 : 0
    readonly property real volLeftExtra:  volStretch < 0 ? islandShape.collapsedW * 0.92 * (-volStretch) * 0.26 : 0

    // Clock / Weather
    property string timeStr:     ""
    property string timeStrSec:  ""
    property string dateStr:     ""
    property string weatherIcon: ""
    property string weatherTemp: "--°"
    property string geoTimezone: ""

    // =========================================================
    // --- HELPERS ---
    // =========================================================
    function exec(cmd) { Quickshell.execDetached(["bash", "-c", cmd]); }
    function shellEsc(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }
    function handleImageDrop(urls) {
        var hasFiles = false;
        var targetDir = "$HOME/Downloads/qs_stash/";
        if (urls.length > 1) {
            var groupName = "group_" + Date.now();
            targetDir = "$HOME/Downloads/qs_stash/" + groupName + "/";
            exec("mkdir -p " + targetDir);
        }
        for (var i = 0; i < urls.length; i++) {
            var url = urls[i].toString().trim();
            if (url.startsWith("http://") || url.startsWith("https://")) {
                exec("mkdir -p $HOME/Downloads/qs_stash && wget -q -P $HOME/Downloads/qs_stash/ " + shellEsc(url) + " &");
                hasFiles = true;
            } else if (url.startsWith("file://")) {
                var filePath = decodeURIComponent(url.replace('file://', ''));
                exec("mkdir -p $HOME/Downloads/qs_stash && cp -r " + shellEsc(filePath) + " " + targetDir + " &");
                hasFiles = true;
            } else if (url !== "") {
                exec("mkdir -p $HOME/Downloads/qs_stash && cp -r " + shellEsc(url) + " " + targetDir + " &");
                hasFiles = true;
            }
        }
        if (hasFiles) {
            currentPage = "stash";
            expanded = true;
            stashRefreshTimer.restart();
        }
    }
    function openUrl(url) {
        if (!url || url === "") return;
        Quickshell.execDetached(["xdg-open", url]);
    }

    function playSound(type) {
        let map = {
            "notification": "/usr/share/sounds/freedesktop/stereo/message.oga",
            "volume":       "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga",
            "timer_end":    "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
        };
        let f = map[type] || "";
        if (!f) return;
        exec(
            "if [ -f \"" + f + "\" ]; then " +
            " (pw-play \"" + f + "\" >/dev/null 2>&1 || paplay \"" + f + "\" >/dev/null 2>&1 || canberra-gtk-play -f \"" + f + "\" >/dev/null 2>&1) & " +
            "fi"
        );
    }

    function saveNotifHistory() {
        let items = [];
        for (let i = 0; i < Math.min(notifHistory.count, 100); i++) {
            let it = notifHistory.get(i);
            items.push({ appName: it.appName, title: it.title, body: it.body, icon: it.icon });
        }
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p ~/.cache/quickshell && printf '%s' \"$1\" > ~/.cache/quickshell/notifications.json",
            "qs_save", JSON.stringify(items)
        ]);
    }

    // Deterministic accent color from app name
    function appAccentColor(appName) {
        let hash = 0;
        let str = appName || "System";
        for (let i = 0; i < str.length; i++) hash = (str.charCodeAt(i) + ((hash << 5) - hash)) | 0;
        let palette = [islandWindow.mauve, islandWindow.blue, islandWindow.green,
                       islandWindow.peach, islandWindow.pink, islandWindow.teal];
        return palette[Math.abs(hash) % palette.length];
    }

    // =========================================================
    // --- PAGE REGISTRY ---
    // To add a new page: create pages/YourPage.qml with `property var island`,
    // then add one entry below — everything else (loading, transitions, nav) is automatic.
    // =========================================================
    property var pageRegistry: [
        { name: "clock",     expandedH: 350, comp: clockPageComp     },
        { name: "timer",     expandedH: 400, comp: timerPageComp     },
        { name: "app",       expandedH: 300, comp: appPageComp       },
        { name: "recording", expandedH: 320, comp: recordingPageComp },
        { name: "discord",   expandedH: 270, comp: discordPageComp   },
        { name: "music",     expandedH: 630, comp: musicPageComp     },
        { name: "notifs",    expandedH: 450, comp: notifsPageComp    },
        { name: "stash",     expandedH: 260, comp: stashPageComp     },
    ]

    Component { id: clockPageComp;     ClockPage     { island: islandWindow } }
    Component {
        id: timerPageComp
        Item {
            id: timerRoot
            property var island: islandWindow
            property string mode: "timer" // timer | stopwatch
            property string customInput: "00:05:00"
            property bool inlineEdit: false
            readonly property bool timerMode: mode === "timer"

            Item {
                anchors.fill: parent
                anchors.margins: island.s(24)
                anchors.bottomMargin: island.s(72)
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: island.s(14)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: island.s(14)

                        Rectangle {
                            Layout.preferredWidth: island.s(88)
                            Layout.preferredHeight: island.s(88)
                            radius: island.s(14)
                            color: Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.72)
                            border.width: 1
                            border.color: Qt.rgba(island.text.r, island.text.g, island.text.b, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: timerRoot.timerMode ? "󰔛" : "󱎫"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: island.s(42)
                                color: timerRoot.timerMode ? island.mauve : island.blue
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: island.s(4)
                            Text {
                                text: timerRoot.timerMode ? "Timer" : "Stopwatch"
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(20)
                                font.weight: Font.Black
                                color: island.text
                            }
                            Text {
                                text: timerRoot.timerMode
                                    ? (island.timerRunning ? "Countdown active" : "Set duration and start")
                                    : (island.stopwatchRunning ? "Tracking elapsed time" : "Ready to track time")
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(11)
                                color: island.subtext0
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: island.s(44)
                        radius: island.s(12)
                        color: Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.64)
                        border.width: 1
                        border.color: Qt.rgba(island.text.r, island.text.g, island.text.b, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: island.s(4)
                            spacing: island.s(6)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: island.s(10)
                                color: timerRoot.timerMode ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.18) : "transparent"
                                border.width: timerRoot.timerMode ? 1 : 0
                                border.color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.40)
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰔛  Timer"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: island.s(13)
                                    color: timerRoot.timerMode ? island.mauve : island.text
                                }
                                MouseArea { anchors.fill: parent; onClicked: timerRoot.mode = "timer" }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: island.s(10)
                                color: !timerRoot.timerMode ? Qt.rgba(island.blue.r, island.blue.g, island.blue.b, 0.18) : "transparent"
                                border.width: !timerRoot.timerMode ? 1 : 0
                                border.color: Qt.rgba(island.blue.r, island.blue.g, island.blue.b, 0.40)
                                Text {
                                    anchors.centerIn: parent
                                    text: "󱎫  Stopwatch"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: island.s(13)
                                    color: !timerRoot.timerMode ? island.blue : island.text
                                }
                                MouseArea { anchors.fill: parent; onClicked: timerRoot.mode = "stopwatch" }
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: island.s(280)
                        Layout.preferredHeight: island.s(66)
                        radius: island.s(12)
                        color: (timerRoot.timerMode && timerRoot.inlineEdit)
                            ? Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.8)
                            : "transparent"
                        border.width: (timerRoot.timerMode && timerRoot.inlineEdit) ? 1 : 0
                        border.color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.35)

                        Text {
                            anchors.centerIn: parent
                            visible: !(timerRoot.timerMode && timerRoot.inlineEdit)
                            text: timerRoot.timerMode
                                ? island.fmtChrono(island.timerRemainingSec > 0 ? island.timerRemainingSec : island.timerPresetSec)
                                : island.fmtChrono(island.stopwatchElapsedSec)
                            font.family: "JetBrains Mono"
                            font.pixelSize: island.s(48)
                            font.weight: Font.Black
                            color: island.text
                        }

                        TextField {
                            id: inlineTimerEditor
                            anchors.centerIn: parent
                            visible: timerRoot.timerMode && timerRoot.inlineEdit
                            width: island.s(220)
                            text: timerRoot.customInput
                            horizontalAlignment: TextInput.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: island.s(38)
                            font.weight: Font.Black
                            color: island.text
                            placeholderText: "HH:MM:SS"
                            background: Item {}
                            onVisibleChanged: {
                                if (visible) {
                                    forceActiveFocus();
                                    selectAll();
                                }
                            }
                            onAccepted: {
                                let secs = island.parseChronoInput(text);
                                if (secs > 0) {
                                    timerRoot.customInput = text;
                                    island.timerPresetSec = secs;
                                    if (!island.timerRunning || island.timerRemainingSec <= 0) island.timerRemainingSec = secs;
                                }
                                timerRoot.inlineEdit = false;
                            }
                            Keys.onEscapePressed: {
                                timerRoot.inlineEdit = false;
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: timerRoot.timerMode && !timerRoot.inlineEdit
                            onClicked: {
                                timerRoot.customInput = island.fmtChrono(island.timerRemainingSec > 0 ? island.timerRemainingSec : island.timerPresetSec);
                                timerRoot.inlineEdit = true;
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: island.s(12)

                        Rectangle {
                            Layout.preferredWidth: island.s(132)
                            Layout.preferredHeight: island.s(40)
                            radius: island.s(12)
                            color: timerRoot.timerMode
                                ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.82)
                                : Qt.rgba(island.blue.r, island.blue.g, island.blue.b, 0.82)
                            Text {
                                anchors.centerIn: parent
                                text: timerRoot.timerMode
                                    ? (island.timerRunning ? "Pause" : "Start")
                                    : (island.stopwatchRunning ? "Pause" : "Start")
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(12)
                                font.weight: Font.Black
                                color: island.base
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (timerRoot.timerMode) {
                                        // Always honor the latest typed value, even if Enter wasn't pressed.
                                        let raw = timerRoot.inlineEdit ? inlineTimerEditor.text : timerRoot.customInput;
                                        let secs = island.parseChronoInput(raw);
                                        if (secs > 0) {
                                            timerRoot.customInput = raw;
                                            island.timerPresetSec = secs;
                                            if (!island.timerRunning || island.timerRemainingSec <= 0) island.timerRemainingSec = secs;
                                        }
                                        timerRoot.inlineEdit = false;
                                        island.toggleTimer();
                                    } else {
                                        island.toggleStopwatch();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: island.s(98)
                            Layout.preferredHeight: island.s(40)
                            radius: island.s(12)
                            color: Qt.rgba(island.surface1.r, island.surface1.g, island.surface1.b, 0.82)
                            border.width: 1
                            border.color: Qt.rgba(island.text.r, island.text.g, island.text.b, 0.16)
                            Text {
                                anchors.centerIn: parent
                                text: "Reset"
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(12)
                                font.weight: Font.Black
                                color: island.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (timerRoot.timerMode) island.resetTimer();
                                    else island.resetStopwatch();
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: island.s(8)
                        visible: timerRoot.timerMode

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Click the time to edit (HH:MM:SS / MM:SS / minutes)"
                            font.family: "JetBrains Mono"
                            font.pixelSize: island.s(10)
                            color: island.subtext0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: island.s(8)
                            Repeater {
                                model: [300, 600, 900, 1500]
                                delegate: Rectangle {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: island.s(28)
                                    radius: island.s(10)
                                    color: Qt.rgba(island.surface1.r, island.surface1.g, island.surface1.b, 0.66)
                                    border.width: 1
                                    border.color: Qt.rgba(island.text.r, island.text.g, island.text.b, 0.12)
                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(modelData / 60) + "m"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: island.s(10)
                                        font.weight: Font.Bold
                                        color: island.subtext0
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: island.startTimer(modelData) }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
    Component { id: appPageComp;       AppPage       { island: islandWindow } }
    Component { id: recordingPageComp; RecordingPage { island: islandWindow } }
    Component { id: discordPageComp;   DiscordPage   { island: islandWindow } }
    Component { id: musicPageComp;     MusicPage     { island: islandWindow } }
    Component { id: notifsPageComp;    NotifsPage    { island: islandWindow } }
    Component { id: notifExpandedComp; NotifExpandedPage { island: islandWindow } }
    Component { id: stashPageComp;     StashPage         { island: islandWindow } }

    function dismissNotif() {
        notifHideTimer.stop();
        notifActive = false;
        notifData   = null;
        if (!wasExpandedBeforeNotif) expanded = false;
    }

    Timer {
        id: stashRefreshTimer
        interval: 300
        onTriggered: stashScanner.running = true
    }

    // =========================================================
    // --- PROCESSES & TIMERS ---
    // =========================================================

    // Music info polling
    Process {
        id: musicProc
        command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let d = JSON.parse(this.text);
                        if (!islandWindow.userIsSeeking) islandWindow.musicData = d;
                    }
                } catch(e) { console.warn(e) }
            }
        }
    }
    Process {
        id: eqProc
        command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/music/equalizer.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) islandWindow.eqData = JSON.parse(this.text);
                } catch(e) { console.warn(e) }
            }
        }
    }
    readonly property int mediaPollInterval: (islandWindow.isMediaActive || islandWindow.currentPage === "music") ? 1000 : 3000
    Timer { interval: mediaPollInterval; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { musicProc.running = true; eqProc.running = true; } }

    // Watchdog: ensure cavaProc stays in sync with play state (survives reboot/crash)
    Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let should = islandWindow.isMediaActive && islandWindow.musicData.status === "Playing";
            if (should && !cavaProc.running)  cavaProc.running = true;
            if (!should && cavaProc.running) cavaProc.running = false;
        }
    }

    // CAVA: streams 4 bar values per frame in real-time
    // Note: Quickshell Process.running is imperative, not reactive —
    // controlled via onMusicDataChanged below.
    Process {
        id: cavaProc
        command: ["bash", "-c", "cava -p ~/.config/hypr/scripts/quickshell/music/cava_island.cfg 2>/dev/null"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let parts = line.trim().split(" ");
                if (parts.length < 4) return;
                function norm(s) {
                    let v = parseInt(s);
                    // autosens calibrates to ~210 peak; headroom prevents hard clip
                    return isNaN(v) ? 0.05 : Math.max(0.05, Math.min(1.0, v / 600.0));
                }
                let b0 = norm(parts[0]), b1 = norm(parts[1]),
                    b2 = norm(parts[2]), b3 = norm(parts[3]);
                islandWindow.cavaBar0 = b0;
                islandWindow.cavaBar1 = b1;
                islandWindow.cavaBar2 = b2;
                islandWindow.cavaBar3 = b3;
                islandWindow.cavaMax  = Math.max(b0, b1, b2, b3);
            }
        }
        onRunningChanged: {
            if (!running) {
                islandWindow.cavaBar0 = 0.1; islandWindow.cavaBar1 = 0.1;
                islandWindow.cavaBar2 = 0.1; islandWindow.cavaBar3 = 0.1;
                islandWindow.cavaMax  = 0.1;
            }
        }
    }

    Process {
        id: mprisWatcher; running: true
        command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
        onExited: { musicProc.running = true; running = true; }
    }

    // Clock timezone source (derived from dynamic location weather script)
    Process {
        id: timezoneProc
        command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/calendar/weather.sh --timezone 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let tz = this.text.trim();
                if (tz !== "" && tz !== "null") islandWindow.geoTimezone = tz;
            }
        }
    }
    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: timezoneProc.running = true }

    // Clock tick in detected timezone
    Process {
        id: clockProc
        command: ["bash", "-c",
            "tz=\"$1\"; " +
            "if [ -n \"$tz\" ]; then TZ=\"$tz\" date '+%H:%M|%H:%M:%S|%a, %b %d'; " +
            "else date '+%H:%M|%H:%M:%S|%a, %b %d'; fi",
            "qs_clock_tz",
            islandWindow.geoTimezone
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length >= 3) {
                    islandWindow.timeStr = parts[0];
                    islandWindow.timeStrSec = parts[1];
                    islandWindow.dateStr = parts[2];
                }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: clockProc.running = true }

    Timer {
        interval: 1000
        running: islandWindow.timerRunning || islandWindow.stopwatchRunning
        repeat: true
        onTriggered: {
            if (islandWindow.timerRunning) {
                islandWindow.timerRemainingSec = Math.max(0, islandWindow.timerRemainingSec - 1);
                if (islandWindow.timerRemainingSec <= 0) {
                    islandWindow.timerRunning = false;
                    islandWindow.playSound("timer_end");
                    islandWindow.exec("notify-send -u normal -i alarm-symbolic 'Timer Finished' 'Your countdown has ended.'");
                }
            }
            if (islandWindow.stopwatchRunning) {
                islandWindow.stopwatchElapsedSec = islandWindow.stopwatchElapsedSec + 1;
            }
        }
    }

    // Weather (calls --json to refresh cache, then parses hourly slot)
    Process {
        id: weatherProc
        command: ["bash", "-c",
            "data=$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --json 2>/dev/null); " +
            "tz=\"$1\"; " +
            "if [ -n \"$tz\" ]; then ct=$(TZ=\"$tz\" date +%H:%M); else ct=$(date +%H:%M); fi; " +
            "icon=$(echo \"$data\" | jq -r --arg ct \"$ct\" '(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0] | .icon' 2>/dev/null); " +
            "temp=$(echo \"$data\" | jq -r --arg ct \"$ct\" '(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0] | .temp' 2>/dev/null); " +
            "echo \"$icon|$temp\"",
            "qs_weather_tz",
            islandWindow.geoTimezone
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length >= 2) {
                    let icon = parts[0].trim();
                    let temp = parts[1].trim();
                    if (icon !== "" && icon !== "null") islandWindow.weatherIcon = icon;
                    if (temp !== "" && temp !== "null" && temp !== "0.0") islandWindow.weatherTemp = temp + "°C";
                }
            }
        }
    }
    Timer { interval: 180000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: weatherProc.running = true }

    // Notification auto-dismiss: collapse + show badge if wasn't already open
    Timer {
        id: notifHideTimer
        interval: 5000
        onTriggered: {
            islandWindow.notifActive = false;
            islandWindow.notifData   = null;
            // Fully dismiss transient notifications after timeout.
            // Keep user-expanded state intact, but do not leave a badge trail.
            if (!islandWindow.wasExpandedBeforeNotif) islandWindow.expanded = false;
            islandWindow.notifBadgeVisible = false;
        }
    }

    // Auto-revert notifs collapsed page back to previous page
    Timer {
        id: notifPageRevertTimer
        interval: 2500
        onTriggered: {
            if (!islandWindow.expanded && islandWindow.currentPage === "notifs")
                islandWindow.currentPage = islandWindow.prevPage;
        }
    }

    // Volume read + set
    Process {
        id: volReadProc
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\\d+(?=%)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text.trim());
                if (!isNaN(v) && !islandWindow.volDragging) islandWindow.currentVol = v;
            }
        }
    }
    readonly property int volPollInterval: islandWindow.expanded ? 2000 : 3500
    Timer { interval: volPollInterval; running: true; repeat: true; triggeredOnStart: true
        onTriggered: volReadProc.running = true }

    Timer {
        id: volSetThrottle; interval: 40
        property int targetVol: -1
        onTriggered: {
            if (targetVol >= 0) {
                Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + targetVol + "%"]);
                targetVol = -1;
            }
        }
    }

    // VPN state poll (any wireguard interface)
    Process {
        id: vpnProc
        command: ["bash", "-c",
            "iface=$(ip link show up type wireguard 2>/dev/null | " +
            "sed -nE 's/^[0-9]+: ([^:@]+):.*/\\1/p' | head -1); " +
            "[ -n \"$iface\" ] && echo \"1:$iface\" || echo '0:'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(":");
                let active = parts[0] === "1";
                let iface  = parts.slice(1).join(":").trim();
                if (active && iface) islandWindow.vpnInterface = iface;
                islandWindow.vpnActive = active;
            }
        }
    }
    readonly property int vpnPollInterval: islandWindow.expanded ? 3000 : 6000
    Timer { interval: vpnPollInterval; running: true; repeat: true; triggeredOnStart: true
        onTriggered: vpnProc.running = true }

    Timer { id: vpnBadgeTimer; interval: 4000; onTriggered: islandWindow.vpnBadgeVisible = false }

    // Discord voice call detection — mic capture active = in call
    Process {
        id: discordProc
        command: ["bash", "-c",
            "pactl list source-outputs 2>/dev/null | grep -qi 'application.process.binary.*Discord' && echo '1' || echo '0'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let inCall = this.text.trim() === "1"
                if (inCall && !islandWindow.discordInCall) {
                    islandWindow._discordCallStart  = Math.floor(Date.now() / 1000)
                    islandWindow.discordCallSeconds = 0
                }
                if (!inCall) islandWindow.discordCallSeconds = 0
                islandWindow.discordInCall = inCall
            }
        }
    }
    readonly property int discordPollInterval: islandWindow.discordInCall ? 3000 : 6000
    Timer { interval: discordPollInterval; running: true; repeat: true; triggeredOnStart: true
        onTriggered: discordProc.running = true }
    Timer { interval: 1000; running: islandWindow.discordInCall; repeat: true
        onTriggered: {
            islandWindow.discordCallSeconds = Math.max(0,
                Math.floor(Date.now() / 1000) - islandWindow._discordCallStart)
        }
    }

    // Launcher state — hide island pill when launcher is open
    Process {
        id: launcherStateWatcher; running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_launcher_state$' /tmp/ 2>/dev/null; " +
            "[ -f /tmp/qs_launcher_state ] && cat /tmp/qs_launcher_state"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                islandWindow.launcherActive = this.text.trim() === "1"
                launcherStateWatcher.running = false
                launcherStateWatcher.running = true
            }
        }
    }

    // Screen recording state poll
    Process {
        id: recStateProc
        command: ["bash", "-c",
            "PF=~/.cache/qs_recording_state/wl_pid; " +
            "ST=~/.cache/qs_recording_state/start_time; " +
            "PA=~/.cache/qs_recording_state/paused; " +
            "if [ -f \"$PF\" ] && kill -0 $(cat \"$PF\") 2>/dev/null; then " +
            "  p=0; [ -f \"$PA\" ] && p=1; " +
            "  echo \"1:$(cat \"$ST\" 2>/dev/null || date +%s):$p\"; " +
            "else echo '0:0:0'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(":");
                let nowRec    = parts[0] === "1";
                let nowPaused = parts.length > 2 && parts[2] === "1";
                if (!islandWindow.isRecording && nowRec) {
                    let startTs = parseInt(parts[1]) || 0;
                    let nowTs   = Math.floor(Date.now() / 1000);
                    islandWindow.recordingSeconds = Math.max(0, nowTs - startTs);
                }
                islandWindow.isRecording       = nowRec;
                islandWindow.isRecordingPaused = nowRec && nowPaused;
            }
        }
    }
    readonly property int recPollInterval: islandWindow.isRecording ? 1500 : 5000
    Timer { interval: recPollInterval; running: true; repeat: true; triggeredOnStart: true
        onTriggered: recStateProc.running = true }

    // DND state from disk
    Process {
        id: dndInit; running: true
        command: ["bash", "-c", "cat ~/.cache/qs_dnd 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: { islandWindow.dndEnabled = (this.text.trim() === "1"); }
        }
    }

    // Notification history from disk (load once on startup)
    Process {
        id: notifHistoryLoader; running: true
        command: ["bash", "-c", "cat ~/.cache/quickshell/notifications.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text.trim());
                    if (Array.isArray(items)) {
                        for (let i = 0; i < Math.min(items.length, 100); i++) {
                            notifHistory.append({
                                appName: items[i].appName || "System",
                                title:   items[i].title   || "",
                                body:    items[i].body    || "",
                                icon:    items[i].icon    || ""
                            });
                        }
                    }
                } catch(e) { console.warn(e) }
            }
        }
    }

    // --- Focused monitor tracking ---
    Process {
        id: focusedMonProc
        command: ["bash", "-c", "hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let m = this.text.trim();
                if (m !== "" && m !== "null" && islandWindow.activeMonitor !== m)
                    islandWindow.activeMonitor = m;
            }
        }
    }
    Process {
        id: focusedMonWatcher
        running: true
        command: ["bash", "-c",
            "socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - " +
            "| grep -m1 '^focusedmon'"]
        onExited: { focusedMonProc.running = true; running = true; }
    }
    Timer { interval: 150; running: true; triggeredOnStart: true; onTriggered: focusedMonProc.running = true }

    // Focused app watcher (used for app-aware island surfaces)
    Process {
        id: activeWindowProc
        command: ["bash", "-c",
            "hyprctl activewindow -j 2>/dev/null | jq -r '[(.class // \"\"), (.title // \"\"), ((.fullscreen // 0) | tostring)] | @tsv'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (!raw) return;
                let parts = raw.split("\t");
                if (parts.length < 2) return;
                let fsStr = parts[parts.length - 1].trim();
                let fs = parseInt(fsStr, 10);
                if (isNaN(fs)) fs = 0;
                islandWindow.activeWindowFullscreen = (fs === 1);
                islandWindow.activeWindowClass = (parts[0] || "").trim();
                islandWindow.activeWindowTitle = parts.length > 2
                    ? parts.slice(1, parts.length - 1).join("\t").trim()
                    : "";
            }
        }
    }
    Timer { interval: 400; running: true; repeat: true; triggeredOnStart: true; onTriggered: activeWindowProc.running = true }
    Timer {
        id: bravePriorityTimer
        interval: 5000
        onTriggered: {
            islandWindow.bravePriorityActive = false;
            islandWindow.applyContextPage();
        }
    }

    Process {
        id: topSitesProc
        command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/browser/top_sites.sh 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") raw = "[]";
                try {
                    let items = JSON.parse(raw);
                    topSites.clear();
                    for (let i = 0; i < Math.min(items.length, 3); i++) {
                        let t = (items[i].title || "").trim();
                        let h = (items[i].host || "").trim();
                        let label = t !== "" ? t : h;
                        if (label.length > 28) label = label.substring(0, 27) + "…";
                        topSites.append({
                            title: label,
                            host: h,
                            url: (items[i].url || "").trim()
                        });
                    }
                } catch (e) {}
            }
        }
    }
    Timer { interval: 300000; running: true; repeat: true; triggeredOnStart: true; onTriggered: topSitesProc.running = true }

    // --- Reactive state ---
    onMusicDataChanged: {
        let should = isMediaActive && musicData.status === "Playing";
        if (should && !cavaProc.running)  cavaProc.running = true;
        if (!should && cavaProc.running) cavaProc.running = false;
    }
    onIsMediaActiveChanged: {
        let holdActive = Date.now() < manualPageHoldUntil;
        if (isMediaActive) {
            if (!holdActive && currentPage === "clock") currentPage = "music";
        } else {
            if (expanded && !notifActive) expanded = false;
            if (!holdActive && currentPage === "music") currentPage = "clock";
            if (cavaProc.running) cavaProc.running = false;
        }
    }
    onIsRecordingChanged: {
        if (isRecording) {
            recordingSeconds  = 0;
            isRecordingPaused = false;
            // Low priority: don't hijack currentPage — bubble on right shows state
        } else {
            isRecordingPaused = false;
            if (currentPage === "recording") currentPage = "clock";
            if (!expanded) recordingDotOpacity = 1.0;
        }
    }
    onExpandedChanged: {
        if (expanded) {
            islandShape.forceActiveFocus();
            if (notifBadgeVisible) notifBadgeVisible = false;
            notifPageRevertTimer.stop();
        }
        if (!expanded && currentPage === "notifs") notifPageRevertTimer.restart();
    }
    onNotifActiveChanged: {
        if (notifActive) notifBadgeVisible = false;
    }
    function applyContextPage() {
        if (expanded || notifActive) return;
        if (Date.now() < manualPageHoldUntil) return;
        if (isBraveWindow && activeWindowTitle !== "" && bravePriorityActive && braveAutoAllowed) {
            currentPage = "app";
            return;
        }
        if (isMediaActive) {
            currentPage = "music";
            return;
        }
        if (isBraveWindow && activeWindowTitle !== "" && braveAutoAllowed) {
            currentPage = "app";
            return;
        }
        if (currentPage === "app") currentPage = "clock";
    }
    onActiveWindowClassChanged: {
        if (isBraveWindow && activeWindowTitle !== "") {
            bravePriorityActive = true;
            bravePriorityTimer.restart();
        } else {
            // Leaving Brave starts a 5-minute cooldown before Brave can auto-take the page again.
            braveSuppressUntil = Date.now() + (5 * 60 * 1000);
            bravePriorityActive = false;
            bravePriorityTimer.stop();
        }
        applyContextPage();
    }
    onActiveWindowTitleChanged: {
        if (isBraveWindow && activeWindowTitle !== "") {
            bravePriorityActive = true;
            bravePriorityTimer.restart();
        }
        applyContextPage();
    }
    onActiveWindowFullscreenChanged: {
        if (activeWindowFullscreen) {
            expanded = false;
            hovered = false;
        }
    }

    // =========================================================
    // --- INPUT MASK ---
    // Covers island + badge bubble (no overlap with top bar)
    // =========================================================
    mask: expanded ? null : maskedRegion

    Item {
        id: maskBounds
        x: islandWindow.activeWindowFullscreen ? 0 : (Math.floor((Screen.width - islandShape.width) / 2) - s(14))
        y: s(8)
        width: islandWindow.activeWindowFullscreen ? 0 : (islandShape.width + s(28)
                + (recBubble.shouldShow ? recBubble.width + s(8) : 0)
                + (islandWindow.notifBadgeVisible ? s(60) : 0))
        height: islandWindow.activeWindowFullscreen ? 0 : (Math.max(islandShape.height, s(48)) + s(8))
    }
    Region { id: maskedRegion; item: maskBounds }

    // Click-outside-to-close
    MouseArea {
        anchors.fill: parent
        enabled: islandWindow.expanded
        visible: islandWindow.expanded
        z: 0
        onClicked: {
            if (islandWindow.notifActive) {
                notifHideTimer.stop();
                islandWindow.notifActive = false;
                islandWindow.notifData   = null;
            }
            islandWindow.expanded = false;
        }
    }

    // =========================================================
    // --- MAIN ISLAND SHAPE ---
    // =========================================================
    Item {
        id: islandShape
        z: 10

        property int collapsedW: {
            let baseW = 0;
            if (islandWindow.osdActive)                                                return osdCollapsed.preferredWidth;
            if (islandWindow.currentPage === "app"       && islandWindow.isBraveWindow) baseW = appCollapsed.preferredWidth;
            else if (islandWindow.currentPage === "recording" && islandWindow.isRecording) baseW = recordingCollapsed.preferredWidth;
            else if (islandWindow.currentPage === "discord"   && islandWindow.discordInCall) baseW = discordCollapsed.preferredWidth;
            else if (islandWindow.currentPage === "music"     && islandWindow.isMediaActive) baseW = musicCollapsed.preferredWidth;
            else if (islandWindow.currentPage === "timer")                                  baseW = chronoCollapsed.preferredWidth;
            else if (islandWindow.currentPage === "notifs")                                  baseW = notifsCollapsed.preferredWidth;
            else baseW = clockCollapsed.preferredWidth;
            return baseW;
        }
        property int collapsedH: (islandWindow.currentPage === "app" && islandWindow.isBraveWindow) ? s(58) : s(48)
        property int expandedW:  Math.min(s(760), Screen.width - s(32))
        property int expandedH: {
            if (islandWindow.notifActive) return s(88);
            if (islandWindow.currentPage === "stash") return s(islandWindow.stashExpandedHeight);
            let page = islandWindow.pageRegistry.find(p => p.name === islandWindow.currentPage);
            return page ? s(page.expandedH) : s(350);
        }

        width:  islandWindow.expanded ? expandedW  : collapsedW
        height: islandWindow.expanded ? expandedH  : collapsedH
        x: Math.floor((Screen.width - width) / 2)
        y: s(8)

        opacity: (islandWindow.launcherActive || islandWindow.activeWindowFullscreen) ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Behavior on width  { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
        Behavior on height {
            SequentialAnimation {
                // For notifications only: width expands first, height follows after
                PauseAnimation { duration: islandWindow.notifActive && islandWindow.expanded ? 220 : 0 }
                NumberAnimation { duration: 540; easing.type: Easing.OutExpo }
            }
        }

        scale: islandWindow.hovered && !islandWindow.expanded ? 1.025 : 1.0
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }

        // ── Drop shadow — gives floating feeling, stretches with volume drag ──
        Rectangle {
            id: islandShadow
            anchors.fill: parent
            anchors.margins: -s(6)
            anchors.topMargin: s(10)
            radius: bg.radius + s(6)
            Behavior on radius { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
            color: Qt.rgba(0.04, 0.09, 0.12, islandWindow.expanded ? 0.55 : 0.38)
            Behavior on color { ColorAnimation { duration: 400 } }
            z: -1

            transform: Scale {
                xScale: islandWindow.expanded ? 1.0 : (1.0 + Math.abs(islandWindow.volStretch) * 0.26)
                origin.x: islandWindow.volStretch >= 0 ? islandShadow.width * 0.08 : islandShadow.width * 0.92
                origin.y: islandShadow.height * 0.5
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 28
            }
        }

        // ── Background pill ──────────────────────────────────
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: islandWindow.expanded ? s(26) : height / 2
            Behavior on radius { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
            // Elastic volume-drag deform
            transform: Scale {
                xScale: islandWindow.expanded ? 1.0 : (1.0 + Math.abs(islandWindow.volStretch) * 0.26)
                origin.x: islandWindow.volStretch >= 0 ? bg.width * 0.08 : bg.width * 0.92
                origin.y: bg.height * 0.5
            }

            color: {
                let a = islandWindow.expanded ? 0.93
                      : islandWindow.hovered  ? 0.95
                      : islandWindow.isMediaActive ? 0.88 : 0.78;
                return Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, a);
            }
            Behavior on color { ColorAnimation { duration: 300 } }

            border.width: islandWindow.volDragging ? 2 : (islandWindow.isRecording ? 2 : (islandWindow.notifActive ? 2 : (islandWindow.isMediaActive && islandWindow.musicData.status === "Playing" && !islandWindow.expanded ? 2 : 1)))
            Behavior on border.width { NumberAnimation { duration: 300 } }
            border.color: {
                if (islandWindow.osdActive && !islandWindow.expanded) {
                    if (islandWindow.osdType === "volume")     return Qt.rgba(islandWindow.blue.r,  islandWindow.blue.g,  islandWindow.blue.b,  0.55)
                    if (islandWindow.osdType === "brightness") return Qt.rgba(islandWindow.peach.r, islandWindow.peach.g, islandWindow.peach.b, 0.55)
                    return Qt.rgba(islandWindow.teal.r, islandWindow.teal.g, islandWindow.teal.b, 0.55)
                }
                if (islandWindow.volDragging) {
                    let t = islandWindow.currentVol / 100.0;
                    let b = islandWindow.blue, m = islandWindow.mauve;
                    return Qt.rgba(b.r + (m.r - b.r) * t, b.g + (m.g - b.g) * t, b.b + (m.b - b.b) * t,
                                   0.3 + t * 0.7);
                }
                if (islandWindow.isRecording)
                    return Qt.rgba(islandWindow.red.r, islandWindow.red.g, islandWindow.red.b, islandWindow.recordingDotOpacity * 0.85);
                if (islandWindow.notifActive)
                    return Qt.rgba(islandWindow.peach.r, islandWindow.peach.g, islandWindow.peach.b, islandWindow.notifPulse);
                if (islandWindow.isMediaActive && islandWindow.musicData.status === "Playing" && !islandWindow.expanded)
                    return Qt.rgba(islandWindow.mauve.r, islandWindow.mauve.g, islandWindow.mauve.b, islandWindow.musicPulse);
                if (islandWindow.isMediaActive)
                    return Qt.rgba(islandWindow.mauve.r, islandWindow.mauve.g, islandWindow.mauve.b,
                                   islandWindow.hovered || islandWindow.expanded ? 0.45 : 0.22);
                return Qt.rgba(islandWindow.text.r, islandWindow.text.g, islandWindow.text.b,
                               islandWindow.hovered ? 0.15 : 0.06);
            }
            Behavior on border.color { ColorAnimation { duration: islandWindow.volDragging ? 80 : 300 } }

            // Notif / Recording inner glow
            Rectangle {
                anchors.fill: parent; radius: bg.radius
                Behavior on radius { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
                opacity: islandWindow.isRecording
                    ? islandWindow.recordingDotOpacity * 0.12
                    : (islandWindow.notifActive ? islandWindow.notifPulse * 0.18 : 0)
                Behavior on opacity { enabled: !islandWindow.notifActive && !islandWindow.isRecording; NumberAnimation { duration: 400 } }
                color: islandWindow.isRecording ? islandWindow.red : islandWindow.peach
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            // Expanded gradient veil
            Rectangle {
                anchors.fill: parent; radius: bg.radius
                Behavior on radius { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
                visible: islandWindow.expanded
                opacity: islandWindow.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.55) }
                    GradientStop { position: 1.0; color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.85) }
                }
            }

        }

        // ── Music playing outer glow — beat-reactive, matches island stretch ──
        Rectangle {
            anchors.fill: parent
            anchors.margins: -s(3)
            radius: bg.radius + s(3)
            Behavior on radius { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
            color: "transparent"
            border.width: s(2)
            border.color: Qt.rgba(islandWindow.mauve.r, islandWindow.mauve.g, islandWindow.mauve.b, 0.85)
            // opacity drives the beat punch — fast attack, fades only when music stops
            opacity: {
                if (!islandWindow.isMediaActive || islandWindow.musicData.status !== "Playing" || islandWindow.expanded)
                    return 0.0;
                return 0.08 + islandWindow.cavaMax * 0.92;
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: islandWindow.cavaMax > 0.5 ? 35 : 200
                    easing.type: Easing.OutCubic
                }
            }
            z: 0

            // Mirror bg's elastic stretch — origin corrected for -s(3) margin offset
            transform: Scale {
                xScale: islandWindow.expanded ? 1.0 : (1.0 + Math.abs(islandWindow.volStretch) * 0.26)
                origin.x: islandWindow.volStretch >= 0
                    ? (s(3) + bg.width * 0.08)
                    : (s(3) + bg.width * 0.92)
                origin.y: parent.height * 0.5
            }
        }

        // ── Mouse: hover + horizontal volume drag ────────────
        MouseArea {
            id: islandMouse
            anchors.fill: parent
            anchors.leftMargin:  -s(14)
            anchors.rightMargin: -s(14)
            anchors.bottomMargin: -s(8)
            hoverEnabled: true
            enabled: !islandWindow.expanded && !islandWindow.activeWindowFullscreen
            z: 0

            onEntered: islandWindow.hovered = true
            onExited:  islandWindow.hovered = false

            property bool wasDragging: false

            onPressed: (mouse) => {
                wasDragging = false;
                islandWindow.volDragStartX   = mouse.x;
                islandWindow.volDragStartVol = islandWindow.currentVol;
            }
            onPositionChanged: (mouse) => {
                if (!islandMouse.pressed) return;
                let dx = mouse.x - islandWindow.volDragStartX;
                if (Math.abs(dx) > 8 || wasDragging) {
                    wasDragging = true;
                    islandWindow.volDragging = true;
                    islandWindow.volStretch = Math.max(-1.0, Math.min(1.0, dx / 160.0));
                    let nv = Math.max(0, Math.min(100, islandWindow.volDragStartVol + Math.round(dx / 3.0)));
                    if (nv !== islandWindow.currentVol) {
                        islandWindow.currentVol = nv;
                        volSetThrottle.targetVol = nv;
                        if (!volSetThrottle.running) volSetThrottle.start();
                    }
                }
            }
            onReleased: {
                if (wasDragging) {
                    islandWindow.volDragging = false;
                    if (Math.abs(islandWindow.currentVol - islandWindow.volDragStartVol) > 2)
                        islandWindow.playSound("volume");
                }
            }
            onClicked: {
                if (!wasDragging) islandWindow.expanded = true;
            }
        }

        // ── Scroll to switch pages (hover collapsed or expanded) ──
        // To add a new screen: 1) push its name into availablePages
        //                       2) create an Item with matching opacity condition
        Timer { id: scrollCooldown; interval: 240 }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null
            onWheel: (event) => {
                if (scrollCooldown.running || islandWindow.notifActive) {
                    event.accepted = true; return;
                }
                if (event.angleDelta.y > 0) islandWindow.navigatePrev();
                else                        islandWindow.navigateNext();
                scrollCooldown.start();
                event.accepted = true;
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                if (drag.hasUrls) {
                    islandWindow.isDragHovered = true;
                    islandWindow.currentPage = "stash";
                    islandWindow.expanded = true;
                    drag.accept();
                }
            }
            onExited: { islandWindow.isDragHovered = false }
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    islandWindow._dropJustOccurred = true;
                    islandWindow.handleImageDrop(drop.urls);
                    islandWindow.isDragHovered = false;
                    drop.accept();
                }
            }
        }

        // ============================================================
        // COLLAPSED CONTENT — one component per page, crossfade
        // ============================================================
        Item {
            id: collapsedContent
            anchors.fill: parent
            clip: true
            opacity: islandWindow.expanded ? 0 : 1
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
            z: 5

            OSDCollapsed {
                id: osdCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: islandWindow.osdActive ? 1.0 : 0.0
                visible: opacity > 0.001
                z: 6
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
            }

            ClockCollapsed {
                id: clockCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "clock") ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "clock" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }
            Item {
                id: chronoCollapsed
                property int preferredWidth: islandWindow.s(220)
                anchors.centerIn: parent
                width: preferredWidth
                height: islandWindow.s(40)
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "timer") ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "timer" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(islandWindow.surface0.r, islandWindow.surface0.g, islandWindow.surface0.b, 0.74)
                    border.width: 1
                    border.color: Qt.rgba(islandWindow.mauve.r, islandWindow.mauve.g, islandWindow.mauve.b, 0.40)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: islandWindow.s(8)

                    Text {
                        text: (islandWindow.timerRunning || islandWindow.timerRemainingSec > 0) ? "󰔛" : "󱎫"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: islandWindow.s(16)
                        color: (islandWindow.timerRunning || islandWindow.timerRemainingSec > 0) ? islandWindow.mauve : islandWindow.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (islandWindow.timerRunning || islandWindow.timerRemainingSec > 0)
                            ? islandWindow.fmtChrono(islandWindow.timerRemainingSec > 0 ? islandWindow.timerRemainingSec : islandWindow.timerPresetSec)
                            : islandWindow.fmtChrono(islandWindow.stopwatchElapsedSec)
                        font.family: "JetBrains Mono"
                        font.pixelSize: islandWindow.s(13)
                        font.weight: Font.Black
                        color: islandWindow.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (islandWindow.timerRunning || islandWindow.timerRemainingSec > 0) ? "Timer" : "Stopwatch"
                        font.family: "JetBrains Mono"
                        font.pixelSize: islandWindow.s(10)
                        color: islandWindow.subtext0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: islandWindow.expanded = true
                }
            }
            AppCollapsed {
                id: appCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "app" && islandWindow.isBraveWindow) ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "app" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }
            MusicCollapsed {
                id: musicCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "music" && islandWindow.isMediaActive) ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "music" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }
            NotifsCollapsed {
                id: notifsCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "notifs") ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "notifs" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }
            RecordingCollapsed {
                id: recordingCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "recording" && islandWindow.isRecording) ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "recording" && !islandWindow.osdActive ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }

            DiscordCollapsed {
                id: discordCollapsed; island: islandWindow; anchors.centerIn: parent
                opacity: (!islandWindow.osdActive && !islandWindow.volDragging && islandWindow.currentPage === "discord" && islandWindow.discordInCall) ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: islandWindow.currentPage === "discord" ? 60 : 0 }
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }}
            }

            // Music progress bar — inset from sides to clear pill rounded corners
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: s(4)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: s(14)
                anchors.rightMargin: s(14)
                height: s(2); radius: s(1)
                color: Qt.rgba(islandWindow.surface1.r, islandWindow.surface1.g, islandWindow.surface1.b, 0.4)
                opacity: (!islandWindow.volDragging && islandWindow.isMediaActive && islandWindow.currentPage === "music") ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: 350 } }

                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    radius: s(1)
                    width: parent.width * Math.max(0, Math.min(1, (islandWindow.musicData.percent || 0) / 100))
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: islandWindow.mauve }
                        GradientStop { position: 1.0; color: islandWindow.blue }
                    }
                    Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                }
            }

            // Volume text — sibling of liquidOverlay, no transform inheritance
            Row {
                anchors.centerIn: parent; spacing: s(8)
                z: 11
                opacity: islandWindow.volDragging ? 1.0 : 0.0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Text {
                    text: islandWindow.currentVol === 0 ? "󰖁" : (islandWindow.currentVol < 40 ? "󰖀" : "󰕾")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: s(20)
                    color: "white"; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: islandWindow.currentVol + "%"
                    font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: s(19)
                    color: "white"; anchors.verticalCenter: parent.verticalCenter
                }
            }

        }

        // ============================================================
        // EXPANDED: PAGES — loaded from pageRegistry via Loader
        // ============================================================
        Repeater {
            model: islandWindow.pageRegistry
            delegate: Loader {
                anchors.fill: parent
                sourceComponent: modelData.comp
                z: 5

                readonly property bool isCurrent: islandWindow.expanded && !islandWindow.notifActive && islandWindow.currentPage === modelData.name

                opacity: isCurrent ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }

                transform: Translate {
                    y: !islandWindow.notifActive && islandWindow.currentPage === modelData.name ? 0 : islandWindow.s(-8)
                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                }
            }
        }

        // Incoming notification overlay (above pages, z:6)
        Loader {
            anchors.fill: parent
            sourceComponent: notifExpandedComp
            z: 6
            opacity: islandWindow.expanded && islandWindow.notifActive ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutCubic } }
        }

        // ============================================================
        // NAVIGATION BAR: ‹ dots ›
        // ============================================================
        Item {
            id: navBar
            anchors.bottom: parent.bottom; anchors.bottomMargin: s(14)
            anchors.horizontalCenter: parent.horizontalCenter
            height: s(28); width: navRow.width + s(16)
            opacity: islandWindow.expanded && !islandWindow.notifActive && islandWindow.availablePages.length > 1 ? 1.0 : 0.0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
            z: 10

            Row {
                id: navRow; anchors.centerIn: parent; spacing: s(12)

                Rectangle {
                    width: s(28); height: s(28); radius: s(14)
                    color: leftArrowMouse.containsMouse ? Qt.rgba(islandWindow.surface1.r, islandWindow.surface1.g, islandWindow.surface1.b, 0.7) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "‹"; font.family: "JetBrains Mono"; font.pixelSize: s(20); font.weight: Font.Black; color: islandWindow.subtext0 }
                    MouseArea { id: leftArrowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: islandWindow.navigatePrev() }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: s(5)
                    Repeater {
                        model: islandWindow.availablePages.length
                        Rectangle {
                            property bool isActive: islandWindow.availablePages[index] === islandWindow.currentPage
                            width: isActive ? s(18) : s(6); height: s(6); radius: s(3)
                            color: isActive ? islandWindow.mauve : islandWindow.surface2
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    width: s(28); height: s(28); radius: s(14)
                    color: rightArrowMouse.containsMouse ? Qt.rgba(islandWindow.surface1.r, islandWindow.surface1.g, islandWindow.surface1.b, 0.7) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "›"; font.family: "JetBrains Mono"; font.pixelSize: s(20); font.weight: Font.Black; color: islandWindow.subtext0 }
                    MouseArea { id: rightArrowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: islandWindow.navigateNext() }
                }
            }
        }

        focus: islandWindow.expanded
        Keys.onEscapePressed: { if (islandWindow.expanded) { islandWindow.expanded = false; event.accepted = true; } }
        Keys.onPressed: (event) => {
            // If a transient notification popup is open, any typing dismisses it immediately.
            // This keeps typing workflows uninterrupted.
            if (islandWindow.notifActive) {
                islandWindow.notifActive = false;
                islandWindow.notifData = null;
                islandWindow.notifBadgeVisible = false;
                if (!islandWindow.wasExpandedBeforeNotif) islandWindow.expanded = false;
                notifHideTimer.stop();
                event.accepted = true;
            }
        }
    }

    // =========================================================
    // CHRONO EDGE CHIPS
    // Stopwatch on LEFT, Timer on RIGHT
    // =========================================================
    Item {
        id: stopwatchEdgeChip
        z: 10
        height: s(32)
        width: islandWindow.chronoEdgeCompact ? s(32) : (chipRow.implicitWidth + s(20))
        x: Math.floor(Screen.width / 2) - islandShape.collapsedW / 2 - width - s(10) - islandWindow.volLeftExtra
           - ((islandWindow.vpnBadgeVisible || discordBubble.shouldShow) ? (s(42)) : 0)
        y: s(8) + (islandShape.collapsedH - height) / 2

        opacity: islandWindow.stopwatchChipVisible && !islandWindow.activeWindowFullscreen ? 1.0 : 0.0
        visible: opacity > 0.001
        scale: islandWindow.stopwatchChipVisible ? 1.0 : 0.6
        transformOrigin: Item.Right
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.92)
            border.width: 1.2
            border.color: Qt.rgba(islandWindow.blue.r, islandWindow.blue.g, islandWindow.blue.b, 0.55)
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: s(6)
            Text {
                text: "󱎫"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: s(13)
                color: islandWindow.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: !islandWindow.chronoEdgeCompact
                text: islandWindow.fmtChrono(islandWindow.stopwatchElapsedSec)
                font.family: "JetBrains Mono"
                font.pixelSize: s(10)
                font.weight: Font.Black
                color: islandWindow.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                islandWindow.currentPage = "timer";
                islandWindow.expanded = true;
            }
        }
    }

    Item {
        id: timerEdgeChip
        z: 10
        height: s(32)
        width: islandWindow.chronoEdgeCompact ? s(32) : (chipRowR.implicitWidth + s(20))
        x: Math.floor(Screen.width / 2) + islandShape.collapsedW / 2 + s(10) + islandWindow.volRightExtra
           + (recBubble.shouldShow ? (recBubble.width + s(8)) : 0)
           + (islandWindow.notifBadgeVisible ? s(44) : 0)
        y: s(8) + (islandShape.collapsedH - height) / 2

        opacity: islandWindow.timerChipVisible && !islandWindow.activeWindowFullscreen ? 1.0 : 0.0
        visible: opacity > 0.001
        scale: islandWindow.timerChipVisible ? 1.0 : 0.6
        transformOrigin: Item.Left
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.92)
            border.width: 1.2
            border.color: Qt.rgba(islandWindow.mauve.r, islandWindow.mauve.g, islandWindow.mauve.b, 0.58)
        }

        Row {
            id: chipRowR
            anchors.centerIn: parent
            spacing: s(6)
            Text {
                text: "󰔛"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: s(13)
                color: islandWindow.mauve
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: !islandWindow.chronoEdgeCompact
                text: islandWindow.fmtChrono(islandWindow.timerRemainingSec)
                font.family: "JetBrains Mono"
                font.pixelSize: s(10)
                font.weight: Font.Black
                color: islandWindow.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                islandWindow.currentPage = "timer";
                islandWindow.expanded = true;
            }
        }
    }

    // =========================================================
    // NOTIFICATION BADGE BUBBLE
    // Fixed position to the right of the collapsed pill.
    // Shows unread count; scales in from left with spring bounce.
    // =========================================================
    Item {
        id: badgeBubble
        z: 10

        property int sz: s(36)
        x: Math.floor(Screen.width / 2) + islandShape.collapsedW / 2 + s(12)
           + (recBubble.shouldShow ? recBubble.width + s(8) : 0)
           + islandWindow.volRightExtra
        y: s(8) + (islandShape.collapsedH - sz) / 2
        width: sz; height: sz

        opacity: islandWindow.notifBadgeVisible && !islandWindow.expanded && !islandWindow.activeWindowFullscreen ? 1.0 : 0.0
        visible: opacity > 0.001
        scale:   islandWindow.notifBadgeVisible && !islandWindow.expanded ? 1.0 : 0.5
        transformOrigin: Item.Left

        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutBack  } }

        Rectangle {
            anchors.fill: parent; radius: parent.width / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.94)
            border.width: 1.5

            // Slow peach pulse on border
            SequentialAnimation on border.color {
                running: islandWindow.notifBadgeVisible; loops: Animation.Infinite
                ColorAnimation { to: Qt.rgba(islandWindow.peach.r, islandWindow.peach.g, islandWindow.peach.b, 0.65); duration: 1100; easing.type: Easing.InOutSine }
                ColorAnimation { to: Qt.rgba(islandWindow.peach.r, islandWindow.peach.g, islandWindow.peach.b, 0.25); duration: 1100; easing.type: Easing.InOutSine }
            }

            // Bell icon or numeric count
            Text {
                anchors.centerIn: parent
                text: notifHistory.count > 9 ? "9+" : (notifHistory.count > 1 ? notifHistory.count.toString() : "󰂚")
                font.family:  notifHistory.count > 1 ? "JetBrains Mono" : "Iosevka Nerd Font"
                font.weight:  notifHistory.count > 1 ? Font.Black : Font.Normal
                font.pixelSize: notifHistory.count > 1 ? badgeBubble.sz * 0.40 : badgeBubble.sz * 0.48
                color: islandWindow.peach
                Behavior on text { }
            }
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onClicked: {
                islandWindow.notifBadgeVisible = false;
                islandWindow.currentPage = "notifs";
                islandWindow.expanded    = true;
            }
        }
    }

    // =========================================================
    // VPN BADGE BUBBLE
    // Fixed position to the LEFT of the collapsed pill.
    // Shows interface name + lock icon; springs from right.
    // =========================================================
    Item {
        id: vpnBadge
        z: 10

        property int badgeH: s(36)
        height: badgeH

        // Pill width = row content + padding
        width: vpnBadgeRow.implicitWidth + s(28)

        x: Math.floor(Screen.width / 2) - islandShape.collapsedW / 2 - width - s(12) - islandWindow.volLeftExtra
        y: s(8) + (islandShape.collapsedH - badgeH) / 2

        opacity: islandWindow.vpnBadgeVisible && !islandWindow.expanded && !islandWindow.activeWindowFullscreen ? 1.0 : 0.0
        visible: opacity > 0.001
        scale:   islandWindow.vpnBadgeVisible && !islandWindow.expanded ? 1.0 : 0.5
        transformOrigin: Item.Right

        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutBack  } }

        Rectangle {
            anchors.fill: parent; radius: parent.height / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.94)
            border.width: 1.5
            border.color: islandWindow.vpnBadgeConnect
                ? Qt.rgba(islandWindow.green.r, islandWindow.green.g, islandWindow.green.b, 0.65)
                : Qt.rgba(islandWindow.red.r,   islandWindow.red.g,   islandWindow.red.b,   0.65)

            Behavior on border.color { ColorAnimation { duration: 250 } }
        }

        Row {
            id: vpnBadgeRow
            anchors.centerIn: parent
            spacing: s(6)

            Text {
                text: islandWindow.vpnBadgeConnect ? "󰒃" : "󰒄"
                font.family: "Iosevka Nerd Font"; font.pixelSize: vpnBadge.badgeH * 0.42
                color: islandWindow.vpnBadgeConnect ? islandWindow.green : islandWindow.red
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 250 } }
            }
            Text {
                text: islandWindow.vpnInterface || "VPN"
                font.family: "JetBrains Mono"; font.pixelSize: vpnBadge.badgeH * 0.35; font.weight: Font.Bold
                color: islandWindow.vpnBadgeConnect ? islandWindow.green : islandWindow.red
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: islandWindow.vpnBadgeVisible = false
        }
    }

    // =========================================================
    // DISCORD DUAL BUBBLE
    // Appears to the LEFT when in a Discord call while another
    // activity (music/recording) occupies the main pill.
    // =========================================================
    Item {
        id: discordBubble
        z: 10

        property int bubbleH: s(36)
        height: bubbleH
        width:  discordBubbleRow.implicitWidth + s(24)

        // Show when in call AND main pill is showing something else
        property bool shouldShow: islandWindow.discordInCall
            && islandWindow.currentPage !== "discord"
            && !islandWindow.expanded
            && !islandWindow.activeWindowFullscreen

        x: Math.floor(Screen.width / 2) - islandShape.collapsedW / 2 - width - s(10) - islandWindow.volLeftExtra
        y: s(8) + (islandShape.collapsedH - bubbleH) / 2

        opacity: shouldShow ? 1.0 : 0.0
        visible: opacity > 0.001
        scale:   shouldShow ? 1.0 : 0.5
        transformOrigin: Item.Right

        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutBack  } }

        Rectangle {
            anchors.fill: parent; radius: parent.height / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.94)
            border.width: 1.5
            SequentialAnimation on border.color {
                running: discordBubble.shouldShow; loops: Animation.Infinite
                ColorAnimation { to: Qt.rgba(islandWindow.green.r, islandWindow.green.g, islandWindow.green.b, 0.7); duration: 900; easing.type: Easing.InOutSine }
                ColorAnimation { to: Qt.rgba(islandWindow.green.r, islandWindow.green.g, islandWindow.green.b, 0.25); duration: 900; easing.type: Easing.InOutSine }
            }
        }

        Row {
            id: discordBubbleRow
            anchors.centerIn: parent
            spacing: s(6)

            Text {
                text: "󰙯"; font.family: "Iosevka Nerd Font"
                font.pixelSize: discordBubble.bubbleH * 0.44
                color: islandWindow.green; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: {
                    let t = islandWindow.discordCallSeconds
                    let m = Math.floor(t / 60), s2 = t % 60
                    return (m < 10 ? "0"+m : m) + ":" + (s2 < 10 ? "0"+s2 : s2)
                }
                font.family: "JetBrains Mono"; font.pixelSize: discordBubble.bubbleH * 0.36
                font.weight: Font.Bold; color: islandWindow.green
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                islandWindow.currentPage = "discord"
                islandWindow.expanded    = true
            }
        }
    }

    // =========================================================
    // RECORDING BUBBLE
    // Appears to the RIGHT when recording while another page is active.
    // Low priority — never steals focus from current page.
    // =========================================================
    Item {
        id: recBubble
        z: 10

        property int bubbleH: s(36)
        height: bubbleH
        width:  recBubbleRow.implicitWidth + s(24)

        property bool shouldShow: islandWindow.isRecording
            && islandWindow.currentPage !== "recording"
            && !islandWindow.expanded
            && !islandWindow.activeWindowFullscreen

        x: Math.floor(Screen.width / 2) + islandShape.collapsedW / 2 + s(12) + islandWindow.volRightExtra
        y: s(8) + (islandShape.collapsedH - bubbleH) / 2

        opacity: shouldShow ? 1.0 : 0.0
        visible: opacity > 0.001
        scale:   shouldShow ? 1.0 : 0.5
        transformOrigin: Item.Left

        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutBack  } }

        Rectangle {
            anchors.fill: parent; radius: parent.height / 2
            color: Qt.rgba(islandWindow.base.r, islandWindow.base.g, islandWindow.base.b, 0.94)
            border.width: 1.5
            border.color: Qt.rgba(islandWindow.red.r, islandWindow.red.g, islandWindow.red.b,
                                  islandWindow.recordingDotOpacity * 0.85)
            Behavior on border.color { ColorAnimation { duration: 80 } }
        }

        Row {
            id: recBubbleRow
            anchors.centerIn: parent
            spacing: s(6)

            // Pulsing dot
            Rectangle {
                width: s(10); height: s(10); radius: s(5)
                color: islandWindow.red
                opacity: islandWindow.isRecordingPaused ? 0.38 : islandWindow.recordingDotOpacity
                Behavior on opacity { NumberAnimation { duration: 80 } }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: islandWindow.isRecordingPaused ? "PAUSED" : "REC"
                font.family: "JetBrains Mono"
                font.pixelSize: recBubble.bubbleH * 0.34
                font.weight: Font.Black
                font.letterSpacing: s(1.5)
                color: islandWindow.isRecordingPaused ? islandWindow.subtext0 : islandWindow.red
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                text: {
                    let t = islandWindow.recordingSeconds
                    let m = Math.floor(t / 60), s2 = t % 60
                    return (m < 10 ? "0"+m : m) + ":" + (s2 < 10 ? "0"+s2 : s2)
                }
                font.family: "JetBrains Mono"
                font.pixelSize: recBubble.bubbleH * 0.32
                font.weight: Font.Bold
                color: islandWindow.subtext0
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                islandWindow.currentPage = "recording"
                islandWindow.expanded    = true
            }
        }
    }

    // =========================================================
    // IPC: Incoming notification from Main.qml
    // =========================================================
    Process {
        id: notifIpcWatcher; running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_island_notif$' /tmp/ 2>/dev/null; " +
            "if [ -f /tmp/qs_island_notif ]; then cat /tmp/qs_island_notif; rm -f /tmp/qs_island_notif; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = this.text.trim();
                if (data) {
                    try {
                        let n = JSON.parse(data);
                        let item = {
                            appName: n.appName || "System",
                            title:   n.title   || "",
                            body:    n.body    || "",
                            icon:    n.icon    || ""
                        };

                        // Always persist to history
                        notifHistory.insert(0, item);
                        islandWindow.saveNotifHistory();

                        if (!islandWindow.dndEnabled && !islandWindow.activeWindowFullscreen) {
                            // Normal: show popup card + sound
                            islandWindow.playSound("notification");
                            islandWindow.notifData            = item;
                            islandWindow.wasExpandedBeforeNotif = islandWindow.expanded;
                            islandWindow.notifActive          = true;
                            islandWindow.notifAutoSwitched    = true;
                            islandWindow.currentPage          = "notifs";
                            islandWindow.expanded             = true;
                            notifHideTimer.restart();
                        } else if (!islandWindow.dndEnabled && islandWindow.activeWindowFullscreen) {
                            if (!islandWindow.expanded) islandWindow.notifBadgeVisible = true;
                        } else {
                            // DND: silent badge only
                            if (!islandWindow.expanded) islandWindow.notifBadgeVisible = true;
                        }
                    } catch(e) { console.warn(e) }
                }
                notifIpcWatcher.running = false;
                notifIpcWatcher.running = true;
            }
        }
    }

    // OSD IPC — volume/brightness scripts write "type|value" to /tmp/qs_osd
    Process {
        id: osdIpcWatcher; running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_osd$' /tmp/ 2>/dev/null; " +
            "[ -f /tmp/qs_osd ] && cat /tmp/qs_osd && rm -f /tmp/qs_osd"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = this.text.trim()
                if (data) {
                    let parts = data.split("|")
                    if (parts.length >= 2) {
                        islandWindow.osdType  = parts[0]
                        islandWindow.osdValue = parts[1]
                        islandWindow.osdActive = true
                        osdTimer.restart()
                    }
                }
                osdIpcWatcher.running = false
                osdIpcWatcher.running = true
            }
        }
    }

    // Hyprland layout watcher — listens to socket2 activelayout events
    Process {
        id: layoutWatcher; running: true
        command: ["bash", "-c",
            "sock=\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\"; " +
            "socat - \"UNIX-CONNECT:$sock\" 2>/dev/null | " +
            "grep --line-buffered '^activelayout>>' | " +
            "while IFS= read -r line; do " +
            "  layout=\"${line##*,}\"; " +
            "  case \"$layout\" in " +
            "    *Russian*)     echo 'Russian' ;; " +
            "    *English*|*US*) echo 'English' ;; " +
            "    *Ukrainian*)   echo 'Ukrainian' ;; " +
            "    *German*)      echo 'German' ;; " +
            "    *French*)      echo 'French' ;; " +
            "    *Spanish*)     echo 'Spanish' ;; " +
            "    *Polish*)      echo 'Polish' ;; " +
            "    *Turkish*)     echo 'Turkish' ;; " +
            "    *Arabic*)      echo 'Arabic' ;; " +
            "    *Chinese*)     echo 'Chinese' ;; " +
            "    *Japanese*)    echo 'Japanese' ;; " +
            "    *Korean*)      echo 'Korean' ;; " +
            "    *)             echo \"$layout\" ;; " +
            "  esac; " +
            "done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let code = line.trim()
                if (code.length >= 1) {
                    islandWindow.osdType   = "layout"
                    islandWindow.osdValue  = code
                    islandWindow.osdActive = true
                    osdTimer.restart()
                }
            }
        }
        onExited: { running = true }
    }

    // IPC: External expand/collapse toggle (e.g. keybind)
    Process {
        id: ipcWatcher; running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_island_toggle$' /tmp/ 2>/dev/null; " +
            "if [ -f /tmp/qs_island_toggle ]; then cat /tmp/qs_island_toggle; rm -f /tmp/qs_island_toggle; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let cmd = this.text.trim();
                if (cmd === "toggle")   islandWindow.expanded = !islandWindow.expanded;
                else if (cmd === "expand")   islandWindow.expanded = true;
                else if (cmd === "collapse") islandWindow.expanded = false;
                ipcWatcher.running = false;
                ipcWatcher.running = true;
            }
        }
    }
}
