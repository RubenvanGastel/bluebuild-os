-- System-wide Hyprland config for the hyprland images: the Caelestia shell, with Hyprland
-- set up to work like niri on the gravity and niri images. Windows sit in scrolling columns
-- and the keybinds do the same things as in /etc/niri/config.kdl on the gravity images.
-- Lines marked "niri:" say what they copy from niri.
--
-- Hyprland reads this file when ~/.config/hypr/hyprland.lua doesn't exist. To change
-- things, run `ujust hyprland-user-config`: it makes that file, which loads this one
-- first, so you only add your own changes below it (later settings win).
--
-- Hyprland 0.55 and newer use Lua: https://wiki.hypr.land/configuring/

local home = os.getenv("HOME") or ""
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

--------------------------------------------------------------------------------------------
-- Monitors, keyboard, environment
--------------------------------------------------------------------------------------------

-- Every monitor at its preferred mode and an automatic scale, placed side by side.
-- `hyprctl monitors` lists them; add your own hl.monitor() lines in your config.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- niri: the keyboard layout comes from the system settings (localectl, set by the
-- installer), and Compose is on Right Alt unless you set XKB options there yourself.
-- Hyprland doesn't read them itself, so they're taken from the file locale1 writes.
local keyboard = read_file("/etc/X11/xorg.conf.d/00-keyboard.conf") or ""
local function xkb(option)
    return keyboard:match('Option%s+"' .. option .. '"%s+"([^"]*)"') or ""
end
local kb_layout = xkb("XkbLayout")
local kb_options = xkb("XkbOptions")

-- Caelestia saves screenshots and finds wallpapers in XDG_PICTURES_DIR, falling back to
-- ~/Pictures. The folder has a translated name (~/Afbeeldingen), so it's passed on here.
local user_dirs = read_file(config_home .. "/user-dirs.dirs") or ""
local pictures = user_dirs:match('XDG_PICTURES_DIR="([^"]*)"')
if pictures then
    hl.env("XDG_PICTURES_DIR", (pictures:gsub("^%$HOME", home)))
end

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
-- Qt apps take Caelestia's colours (it writes ~/.config/qtengine)
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

--------------------------------------------------------------------------------------------
-- Look and layout
--------------------------------------------------------------------------------------------

-- Caelestia writes its colour scheme (from the wallpaper) to ~/.config/hypr/scheme/current.lua.
-- Hyprland reloads the config when a file it loaded with require() changes, so the focus ring
-- follows the wallpaper, like the Gravity shell does for niri. It only watches files that
-- existed when it loaded the config, so an empty scheme is put there for Caelestia's first
-- start; until then, Gravity's gold is used.
local function caelestia_scheme()
    local dir = config_home .. "/hypr/scheme"
    if not read_file(dir .. "/current.lua") then
        os.execute("mkdir -p '" .. dir:gsub("'", "'\\''") .. "'")
        local f = io.open(dir .. "/current.lua", "w")
        if not f then return {} end
        f:write("return {}\n")
        f:close()
    end
    package.path = config_home .. "/hypr/?.lua;" .. package.path
    local ok, scheme = pcall(require, "scheme.current")
    return (ok and type(scheme) == "table") and scheme or {}
end
local scheme = caelestia_scheme()

hl.config({
    general = {
        -- niri: windows in columns on a strip that scrolls sideways
        layout = "scrolling",
        -- niri: gaps 14 (Hyprland puts gaps_in on both sides of a window, so half of it)
        gaps_in = 7,
        gaps_out = 14,
        -- niri: a 4 px focus ring on the focused window only
        border_size = 4,
        col = {
            active_border = "rgb(" .. (scheme.primary or "f4c66d") .. ")",
            inactive_border = "rgba(00000000)",
        },
    },

    scrolling = {
        -- niri: default-column-width 0.5, also when it's the only window
        column_width = 0.5,
        fullscreen_on_one_column = false,
        -- niri: center-focused-column "never", just scroll the focused column into view
        focus_fit_method = 1,
        -- niri: preset-column-widths 1/3, 1/2, 2/3
        explicit_column_widths = "0.33333, 0.5, 0.66667",
        -- niri: focusing or moving past the first or last column does nothing
        wrap_focus = false,
        wrap_swapcol = false,
    },

    decoration = {
        -- niri (Gravity): rounded windows with a soft shadow
        rounding = 14,
        rounding_power = 2,
        shadow = {
            enabled = true,
            range = 30,
            render_power = 2,
            offset = "0 5",
            color = 0x77000000,
        },
    },

    input = {
        kb_layout = kb_layout ~= "" and kb_layout or "us",
        kb_variant = xkb("XkbVariant"),
        kb_model = xkb("XkbModel"),
        kb_options = kb_options ~= "" and kb_options or "compose:ralt",
        numlock_by_default = true,
        -- niri: clicking focuses a window, hovering only sends it the pointer (scrolling works
        -- in the window under the cursor without focusing it)
        follow_mouse = 2,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            -- niri (Gravity): two fingers for a right click, three for a middle click
            clickfinger_behavior = true,
            -- niri: typing doesn't disable the touchpad
            disable_while_typing = false,
        },
    },

    binds = {
        -- niri: cooldown-ms=150 on the Mod+mouse wheel binds
        scroll_event_delay = 150,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(" .. (scheme.surfaceContainer or "0d0920") .. ")",
        -- niri: apps that ask to be focused (a link opened from another app) get focus
        focus_on_activate = true,
        -- niri: any key or mouse movement turns the monitors back on
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
        animate_manual_resizes = false,
        -- Caelestia's lock screen: shows the blurred desktop and can be restarted if it crashes
        session_lock_xray = true,
        allow_session_lock_restore = true,
    },

    -- The image updates every day: no news or donation pop-ups after each update
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

-- niri: the same springs as the Gravity / Dux Shell niri config. Hyprland's damping is the
-- absolute value: niri's damping-ratio × 2 × √stiffness.
hl.curve("niriOpen", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })        -- ease-out-expo
hl.curve("niriClose", { type = "bezier", points = { { 0.25, 0.46 }, { 0.45, 0.94 } } }) -- ease-out-quad
hl.curve("niriMove", { type = "spring", mass = 1, stiffness = 323, damping = 26.96 })    -- window-movement
hl.curve("niriView", { type = "spring", mass = 1, stiffness = 423, damping = 34.96 })    -- horizontal-view-movement
hl.curve("niriWorkspace", { type = "spring", mass = 1, stiffness = 523, damping = 36.59 }) -- workspace-switch

hl.animation({ leaf = "windows", enabled = true, speed = 4, spring = "niriView" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "niriMove" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, bezier = "niriOpen", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "niriClose", style = "popin 80%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "niriClose" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "niriClose" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "niriOpen", style = "fade" })
-- niri: workspaces are stacked vertically
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, spring = "niriWorkspace", style = "slidevert" })

-- Touchpad, niri: three fingers sideways scroll the columns, up and down switch workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

--------------------------------------------------------------------------------------------
-- Window and layer rules
--------------------------------------------------------------------------------------------

-- niri: Zen Browser's picture-in-picture player floats
hl.window_rule({
    name = "zen-picture-in-picture",
    match = { class = "^zen$", title = "^Picture-in-Picture$" },
    float = true,
})

-- From Caelestia's own Hyprland config: animations that suit its windows and pickers
hl.layer_rule({ match = { namespace = "hyprpicker" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "selection" }, animation = "fade" }) -- slurp (Print)
hl.layer_rule({ match = { namespace = "launcher" }, animation = "popin 80%", blur = true }) -- fuzzel
hl.layer_rule({ match = { namespace = "caelestia-(border-exclusion|area-picker)" }, no_anim = true })
hl.layer_rule({ match = { namespace = "caelestia-(drawers|background)" }, animation = "fade" })

--------------------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    -- Caelestia: bar, launcher, notifications, lock screen, settings. Accounts get the
    -- image's shell settings first (Ghostty, Nautilus, ...; /usr/libexec/caelestia-user-config).
    hl.exec_cmd("/usr/libexec/caelestia-user-config; caelestia shell -d")
    -- Clipboard history for Caelestia's clipboard menu (Mod+V)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

--------------------------------------------------------------------------------------------
-- niri actions the scrolling layout doesn't have as such
--------------------------------------------------------------------------------------------

-- Global, so your own config can bind other keys to these, e.g.
--   hl.bind("SUPER + L", function() niri.focus_column("right") end)
niri = {}

local function dispatch(action)
    hl.dispatch(action)
end

local function layout(message)
    hl.dispatch(hl.dsp.layout(message))
end

-- The focused window and its column, when it's tiled
local function tiled_window()
    local w = hl.get_active_window()
    if w and not w.floating and type(w.layout) == "table" and w.layout.column then
        return w, w.layout.column
    end
    return nil
end

-- Number of columns on the focused window's workspace
local function column_count(w)
    local last = -1
    for _, other in ipairs(hl.get_windows()) do
        if other.workspace and w.workspace and other.workspace.id == w.workspace.id
            and not other.floating and type(other.layout) == "table" and other.layout.column then
            last = math.max(last, other.layout.column.index)
        end
    end
    return last + 1
end

-- niri: focus-column-left/right; floating windows move focus by direction
function niri.focus_column(dir)
    if tiled_window() then
        layout("focus " .. dir:sub(1, 1))
    else
        dispatch(hl.dsp.focus({ direction = dir }))
    end
end

-- niri: focus-window-up/down stays inside the column (the layout's own focus wraps around)
function niri.focus_window(dir)
    local w, column = tiled_window()
    if not w then
        dispatch(hl.dsp.focus({ direction = dir }))
        return
    end
    local row = w.layout.index_in_column
    if (dir == "up" and row > 0) or (dir == "down" and row < #column.windows - 1) then
        layout("focus " .. dir:sub(1, 1))
    end
end

-- niri: move-window-up/down, only inside the column
function niri.move_window(dir)
    local w, column = tiled_window()
    if not w then
        dispatch(hl.dsp.window.move({ direction = dir }))
        return
    end
    local row = w.layout.index_in_column
    if (dir == "up" and row > 0) or (dir == "down" and row < #column.windows - 1) then
        dispatch(hl.dsp.window.move({ direction = dir }))
    end
end

-- niri: focus-column-first/last
function niri.focus_column_end(last)
    local w, column = tiled_window()
    if not w then return end
    local steps = last and (column_count(w) - 1 - column.index) or column.index
    for _ = 1, steps do
        layout(last and "focus r" or "focus l")
    end
end

-- niri: move-column-to-first/last
function niri.move_column_end(last)
    local w, column = tiled_window()
    if not w then return end
    local steps = last and (column_count(w) - 1 - column.index) or column.index
    for _ = 1, steps do
        layout(last and "swapcol r" or "swapcol l")
    end
end

-- niri: maximize-column, the column fills the screen width; again for its old width
local width_before_maximize = {}
function niri.maximize_column()
    local w, column = tiled_window()
    if not w then return end
    if column.width < 0.999 then
        for _, cw in ipairs(column.windows) do
            width_before_maximize[cw.address] = column.width
        end
        layout("colresize 1.0")
    else
        local width = width_before_maximize[w.address] or 0.5
        for _, cw in ipairs(column.windows) do
            width_before_maximize[cw.address] = nil
        end
        layout("colresize " .. width)
    end
end

-- niri: set-window-height ±10% (of the screen height), for windows sharing a column
function niri.window_height(percent)
    local w, column = tiled_window()
    if w and #column.windows < 2 then return end
    local m = hl.get_active_monitor()
    if not m then return end
    local px = math.floor(m.height / m.scale * percent / 100 + 0.5)
    dispatch(hl.dsp.window.resize({ x = 0, y = px, relative = true }))
end

-- niri: center-visible-columns, scroll so the columns that are fully on screen are centred
-- in the space next to the shell's bar and frame
function niri.center_visible_columns()
    local w = tiled_window()
    local m = hl.get_active_monitor()
    if not w or not m then return end
    local reserved = type(m.reserved) == "table" and m.reserved or {}
    local left = m.x + (reserved.left or 0)
    local width = m.width / m.scale - (reserved.left or 0) - (reserved.right or 0)
    local lo, hi
    for _, other in ipairs(hl.get_windows()) do
        if other.workspace and other.workspace.id == w.workspace.id and not other.floating then
            local x1, x2 = other.at.x, other.at.x + other.size.x
            if x1 >= left - 1 and x2 <= left + width + 1 then
                lo = math.min(lo or x1, x1)
                hi = math.max(hi or x2, x2)
            end
        end
    end
    if not lo then return end
    local shift = math.floor(left + width / 2 - (lo + hi) / 2 + 0.5)
    if shift ~= 0 then
        layout(string.format("move %+d", shift))
    end
end

-- niri: toggle-overview. Hyprland has no overview, so this fits every column of the
-- workspace on screen; again puts each column back at its own width.
local overview = {}
function niri.toggle_overview()
    local w = tiled_window()
    if not w then return end
    local ws = w.workspace.id
    local saved = overview[ws]
    if saved then
        overview[ws] = nil
        for address, width in pairs(saved.widths) do
            dispatch(hl.dsp.focus({ window = "address:" .. address }))
            layout("colresize " .. width)
        end
        dispatch(hl.dsp.focus({ window = "address:" .. saved.focus }))
        return
    end
    saved = { focus = w.address, widths = {} }
    local seen = {}
    for _, other in ipairs(hl.get_windows()) do
        if other.workspace and other.workspace.id == ws and not other.floating
            and type(other.layout) == "table" and other.layout.column then
            local column = other.layout.column
            if not seen[column.index] then
                seen[column.index] = true
                saved.widths[other.address] = column.width
            end
        end
    end
    overview[ws] = saved
    layout("fit all")
end

-- niri: workspaces are a vertical list per monitor with one empty workspace below the
-- last one. Down goes to the next workspace with windows on this monitor, or from the
-- last one to an empty one; up goes to the previous one with windows.
local function workspace_below_or_above(down)
    local current = hl.get_active_workspace()
    local monitor = hl.get_active_monitor()
    if not current or not monitor then return nil end
    local target
    local used = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id and ws.id > 0 and not ws.special then
            used[ws.id] = true
            local here = ws.monitor and ws.monitor.id == monitor.id
            if here and ws.windows > 0 and ws.id ~= current.id then
                if down and ws.id > current.id and (not target or ws.id < target) then
                    target = ws.id
                elseif not down and ws.id < current.id and (not target or ws.id > target) then
                    target = ws.id
                end
            end
        end
    end
    if target or not down or current.windows == 0 then
        return target
    end
    target = current.id + 1
    while used[target] do
        target = target + 1
    end
    return target
end

-- niri: focus-workspace-down/up
function niri.focus_workspace(down)
    local target = workspace_below_or_above(down)
    if target then
        dispatch(hl.dsp.focus({ workspace = target }))
    end
end

-- niri: move-column-to-workspace, and focus goes with it. Hyprland moves windows, so each
-- window of the column is moved and the column is put back together on the other side.
function niri.move_column_to_workspace(target)
    local w, column = tiled_window()
    if not w then
        if hl.get_active_window() then
            dispatch(hl.dsp.window.move({ workspace = target, follow = true }))
        end
        return
    end
    local current = hl.get_active_workspace()
    if current and current.id == target then return end
    local addresses = {}
    for _, cw in ipairs(column.windows) do
        addresses[#addresses + 1] = cw.address
    end
    for _, address in ipairs(addresses) do
        dispatch(hl.dsp.window.move({ window = "address:" .. address, workspace = target, follow = false }))
    end
    -- They arrive as columns side by side; "consume" pulls the next column's window into
    -- the focused column
    dispatch(hl.dsp.focus({ workspace = target }))
    dispatch(hl.dsp.focus({ window = "address:" .. addresses[1] }))
    for _ = 2, #addresses do
        layout("consume")
    end
    dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    layout("colresize " .. column.width)
end

-- niri: move-column-to-workspace-down/up
function niri.move_to_workspace(down)
    if not hl.get_active_window() then return end
    local target = workspace_below_or_above(down)
    if target then
        niri.move_column_to_workspace(target)
    end
end

-- niri: toggle-keyboard-shortcuts-inhibit, for apps that take all keys (VMs, remote desktop)
local inhibit_blocked = {}
function niri.toggle_shortcuts_inhibit()
    local w = hl.get_active_window()
    if not w then return end
    inhibit_blocked[w.address] = not inhibit_blocked[w.address]
    dispatch(hl.dsp.window.set_prop({
        prop = "no_shortcuts_inhibit",
        value = inhibit_blocked[w.address] and "1" or "0",
    }))
end

-- niri: power-off-monitors. Hyprland asks not to call dpms straight from a keybind.
function niri.power_off_monitors()
    hl.timer(function()
        dispatch(hl.dsp.dpms({ action = "disable" }))
    end, { timeout = 500, type = "oneshot" })
end

--------------------------------------------------------------------------------------------
-- Keybinds, the same as the gravity images' niri config (Mod is Super).
-- Mod+F1 lists them; shell actions go to Caelestia as global shortcuts.
--------------------------------------------------------------------------------------------

local cheatsheet = {}

-- Binds `keys`; a description puts it on the Mod+F1 list
local function bind(keys, action, description, flags)
    flags = flags or {}
    if description then
        flags.description = description
        cheatsheet[#cheatsheet + 1] = string.format("%-30s %s", keys, description)
    end
    hl.bind(keys, action, flags)
end

local function spawn(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function shell(shortcut)
    return hl.dsp.global("caelestia:" .. shortcut)
end

local locked = { locked = true }
local locked_repeating = { locked = true, repeating = true }

-- Core applications
bind("SUPER + Return", spawn("ghostty"), "Terminal")
bind("SUPER + E", spawn("nautilus"), "File Manager")
bind("SUPER + B", spawn("flatpak run app.zen_browser.zen"), "Browser")

-- Shell & widgets
bind("SUPER + space", shell("launcher"), "Launcher")
bind("SUPER + M", shell("dashboard"), "System Monitor (dashboard)")
bind("SUPER + SHIFT + Q", shell("session"), "Session Menu")
bind("SUPER + F1", spawn("pkill -x fuzzel || /usr/libexec/hyprland-keybinds"), "Keybind Cheatsheet")
bind("SUPER + comma", shell("nexus"), "Settings")
-- Caelestia extras (not in the niri config)
bind("SUPER + V", spawn("pkill -x fuzzel || caelestia clipboard"), "Clipboard History")
bind("SUPER + N", shell("sidebar"), "Notifications")
bind("SUPER + period", spawn("pkill -x fuzzel || caelestia emoji -p"), "Emoji Picker")

-- System & session
bind("SUPER + ALT + L", shell("lock"), "Lock Screen")
bind("Print", spawn("/usr/libexec/hyprland-screenshot"), "Screenshot")
bind("CTRL + ALT + Delete", spawn("/usr/libexec/hyprland-quit"), "Quit Hyprland")
bind("SUPER + SHIFT + P", niri.power_off_monitors, "Power Off Monitors")
-- Lets you get out of apps that inhibit shortcuts (remote desktop, VMs, ...)
bind("SUPER + Escape", niri.toggle_shortcuts_inhibit, "Toggle Shortcuts Inhibit", { dont_inhibit = true })

-- Media & brightness (Caelestia shows the volume and brightness)
bind("XF86AudioRaiseVolume", spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume Up", locked_repeating)
bind("XF86AudioLowerVolume", spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume Down", locked_repeating)
bind("XF86AudioMute", spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute", locked)
bind("XF86AudioMicMute", spawn("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mic Mute", locked)
bind("XF86MonBrightnessUp", shell("brightnessUp"), "Brightness Up", locked_repeating)
bind("XF86MonBrightnessDown", shell("brightnessDown"), "Brightness Down", locked_repeating)
bind("SUPER + P", spawn("/usr/libexec/hyprland-power-profile"), "Power Profile", locked)
bind("XF86AudioPlay", shell("mediaToggle"), nil, locked)
bind("XF86AudioPause", shell("mediaToggle"), nil, locked)
bind("XF86AudioStop", shell("mediaStop"), nil, locked)
bind("XF86AudioPrev", shell("mediaPrev"), nil, locked)
bind("XF86AudioNext", shell("mediaNext"), nil, locked)

-- Window focus
bind("SUPER + Left", function() niri.focus_column("left") end, "Focus Column Left")
bind("SUPER + Right", function() niri.focus_column("right") end, "Focus Column Right")
bind("SUPER + Up", function() niri.focus_window("up") end, "Focus Window Up")
bind("SUPER + Down", function() niri.focus_window("down") end, "Focus Window Down")
bind("SUPER + Home", function() niri.focus_column_end(false) end, "Focus First Column")
bind("SUPER + End", function() niri.focus_column_end(true) end, "Focus Last Column")
bind("SUPER + mouse_right", function() niri.focus_column("right") end)
bind("SUPER + mouse_left", function() niri.focus_column("left") end)
bind("SUPER + Tab", niri.toggle_overview, "Window Overview (fit all columns)")
-- niri's window switcher (recent windows)
bind("ALT + Tab", function()
    dispatch(hl.dsp.window.cycle_next())
    dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, "Next Window")
bind("ALT + SHIFT + Tab", function()
    dispatch(hl.dsp.window.cycle_next({ next = false }))
    dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, "Previous Window")

-- Window movement
bind("SUPER + Q", hl.dsp.window.close(), "Close Window")
bind("SUPER + SHIFT + Left", hl.dsp.layout("swapcol l"), "Move Column Left")
bind("SUPER + SHIFT + Right", hl.dsp.layout("swapcol r"), "Move Column Right")
bind("SUPER + SHIFT + Down", function() niri.move_window("down") end, "Move Window Down")
bind("SUPER + SHIFT + Up", function() niri.move_window("up") end, "Move Window Up")
bind("SUPER + CTRL + Home", function() niri.move_column_end(false) end, "Move Column to First")
bind("SUPER + CTRL + End", function() niri.move_column_end(true) end, "Move Column to Last")
bind("SUPER + CTRL + mouse_right", hl.dsp.layout("swapcol r"))
bind("SUPER + CTRL + mouse_left", hl.dsp.layout("swapcol l"))
-- niri: Mod + left drag moves a window, Mod + right drag resizes it
bind("SUPER + mouse:272", hl.dsp.window.drag(), nil, { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), nil, { mouse = true })

-- Window resizing
bind("SUPER + minus", hl.dsp.layout("colresize -0.1"), "Column Width -10%")
bind("SUPER + equal", hl.dsp.layout("colresize +0.1"), "Column Width +10%")
bind("SUPER + SHIFT + minus", function() niri.window_height(-10) end, "Window Height -10%")
bind("SUPER + SHIFT + equal", function() niri.window_height(10) end, "Window Height +10%")

-- Window state & layout
bind("SUPER + C", hl.dsp.layout("center"), "Center Column")
bind("SUPER + CTRL + C", niri.center_visible_columns, "Center Visible Columns")
bind("SUPER + SHIFT + T", hl.dsp.window.float(), "Toggle Floating")
bind("SUPER + F", niri.maximize_column, "Maximize Column")
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
-- niri: toggle-column-tabbed-display. Hyprland's tabs are a group: new windows opened
-- while it's focused join it.
bind("SUPER + W", hl.dsp.group.toggle(), "Toggle Tabbed")
bind("SUPER + bracketleft", hl.dsp.layout("consume_or_expel prev"), "Consume or Expel Window Left")
bind("SUPER + bracketright", hl.dsp.layout("consume_or_expel next"), "Consume or Expel Window Right")

-- Monitor management
bind("SUPER + SHIFT + CTRL + Left", hl.dsp.window.move({ monitor = "l", follow = true }), "Move Column to Monitor Left")
bind("SUPER + SHIFT + CTRL + Right", hl.dsp.window.move({ monitor = "r", follow = true }), "Move Column to Monitor Right")
bind("SUPER + SHIFT + CTRL + Up", hl.dsp.window.move({ monitor = "u", follow = true }), "Move Column to Monitor Up")
bind("SUPER + SHIFT + CTRL + Down", hl.dsp.window.move({ monitor = "d", follow = true }), "Move Column to Monitor Down")

-- Workspace navigation
bind("SUPER + mouse_down", function() niri.focus_workspace(true) end, "Workspace Down (wheel)")
bind("SUPER + mouse_up", function() niri.focus_workspace(false) end, "Workspace Up (wheel)")
bind("SUPER + CTRL + mouse_down", function() niri.move_to_workspace(true) end, "Move Column to Workspace Down (wheel)")
bind("SUPER + CTRL + mouse_up", function() niri.move_to_workspace(false) end, "Move Column to Workspace Up (wheel)")
for i = 1, 9 do
    bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }), i == 1 and "Focus Workspace 1-9" or nil)
    bind("SUPER + SHIFT + " .. i, function() niri.move_column_to_workspace(i) end,
        i == 1 and "Move Column to Workspace 1-9" or nil)
end

-- The Mod+F1 list, read by /usr/libexec/hyprland-keybinds
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if runtime_dir then
    local f = io.open(runtime_dir .. "/hypr-keybinds.txt", "w")
    if f then
        f:write(table.concat(cheatsheet, "\n"), "\n")
        f:close()
    end
end
