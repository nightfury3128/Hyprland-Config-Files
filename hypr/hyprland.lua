-- Hyprland 0.56.1 Lua configuration
-- Migrated 1:1 from hyprland.conf. Source of truth was hyprland.conf as of
-- the migration date. Do not treat this file as the default example; it
-- represents the user's actual desktop configuration.

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Battery/internal-panel test: expose only the Intel GPU to Hyprland
hl.env("AQ_DRM_DEVICES", "/dev/dri/card2:/dev/dri/card1")

hl.env("XCURSOR_SIZE",   "24")
hl.env("HYPRCURSOR_SIZE", "24")


------------------
---- MONITORS ----
------------------

-- MAIA TURQUOISE THEME - METEHAN
hl.monitor({ output = "eDP-1",     mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "DP-3",      mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "HDMI-A-1",  mode = "preferred", position = "auto", scale = 1 })
-- Fallback for any monitor not listed above
hl.monitor({ output = "",          mode = "preferred", position = "auto", scale = 1 })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = os.getenv("HOME") .. "/.config/hypr/scripts/qs_manager.sh toggle launcher"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd(terminal)
    hl.exec_cmd("swww-daemon")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/power-monitor.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/geo_timezone.sh")
    hl.exec_cmd("swaybg -i " .. os.getenv("HOME") .. "/dotfiles/wallpapers/LockScreen.jpg")
    hl.exec_cmd("sh -c 'pkill -x dunst; pkill -x mako; pkill -x swaync'")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("/home/nipun/librepods/linux/build/librepods --hide")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/qs_manager.sh")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            -- Foggy forest: rust accent -> muted teal, fading into fog
            active_border   = { colors = { "rgba(c96a4ae6)", "rgba(7a8a82cc)" }, angle = 45 },
            inactive_border = "rgba(1e211f99)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 0.92,
        inactive_opacity = 0.82,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee070808,
        },

        blur = {
            enabled = true,
            size    = 6,
            passes  = 1,
            xray    = false,
        },
    },

    animations = {
        enabled = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

-- Bezier curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Temel
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/lock.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("sh -c 'pkill -f \"quickshell\" ; sleep 0.3 && ~/.config/hypr/scripts/qs_manager.sh'"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("kitty --class wallpaper-picker " .. os.getenv("HOME") .. "/.config/hypr/wallpaper.sh"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/game-launcher/toggle.sh"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("sh -c 'kill -9 $(hyprctl activewindow -j | jq -r .pid)'"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/power-toggle.sh"))

-- Launcher
hl.bind(mainMod .. " + R",     hl.dsp.exec_cmd(menu))
hl.bind("SUPER + SPACE",       hl.dsp.exec_cmd(menu))

-- App launchers
hl.bind("SUPER + Z", hl.dsp.exec_cmd("sh -c 'command -v zen-browser >/dev/null 2>&1 && exec zen-browser || command -v zen >/dev/null 2>&1 && exec zen || xdg-open https://www.google.com'"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("spotify"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("cursor"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("discord"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("xdg-open https://uc.instructure.com/"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("xdg-open https://outlook.com/"))

-- Workspace TAB gecis
hl.bind(mainMod .. " + TAB",           hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB",   hl.dsp.focus({ workspace = "e-1" }))

-- Pencereyi workspace'e tasi + o workspace'e gec
hl.bind(mainMod .. " + CTRL + TAB",         hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + TAB", hl.dsp.window.move({ workspace = "e-1" }))

-- Yeni bos workspace ac ve gec
hl.bind(mainMod .. " + CTRL + N", hl.dsp.window.move({ workspace = "emptynm" }))

-- Ekran goruntusu
hl.bind("Print",                   hl.dsp.exec_cmd("sh -c 'grim ~/Pictures/$(date +%Y-%m-%d-%H%M%S_screenshot.png)'"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" ~/Pictures/$(date +%Y-%m-%d-%H%M%S_screenshot.png)'"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | wl-copy'"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | wl-copy'"))

-- Odak
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspace gecis + pencereyi workspace'e tasi
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- Mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Ses & Parlaklik (bindel = locked + repeating)
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),                     { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),                          { locked = true, repeating = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),                         { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",       hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),                       { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd_brightness.sh up"),    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd_brightness.sh down"),  { locked = true, repeating = true })

-- Medya (bindl = locked)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name    = "firefox-opacity",
    match   = { class = "firefox" },
    opacity = "0.92 override 0.85 override",
})

-- Blur katmanlari
hl.layer_rule({ name = "blur-rofi",              match = { namespace = "rofi" },       blur = true })
hl.layer_rule({ name = "ignore-alpha-rofi",      match = { namespace = "rofi" },       ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-quickshell",        match = { namespace = "quickshell" }, blur = true })
hl.layer_rule({ name = "ignore-alpha-quickshell",match = { namespace = "quickshell" }, ignore_alpha = 0.15 })

hl.device({
    name = "sony-interactive-entertainment-dualsense-wireless-controller-touchpad",
    enabled = false,
})

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
-- Default workspaces: laptop, middle 1080p, right 4K
hl.workspace_rule({
    workspace = "1",
    monitor = "desc:BOE 0x0C06",
    default = true,
})

hl.workspace_rule({
    workspace = "2",
    monitor = "desc:AOC 27G2G3 0x0000038D",
    default = true,
})

hl.workspace_rule({
    workspace = "3",
    monitor = "desc:Samsung Electric Company SAMSUNG",
    default = true,
})
