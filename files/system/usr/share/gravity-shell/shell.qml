//@ pragma ShellId gravity
//@ pragma Env QS_NO_RELOAD_POPUP=1
// Video wallpapers: decode with VA-API (AMD/Intel). Without this Qt may try CUDA first
// and fall back to decoding in software.
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi

// Gravity: a Quickshell desktop for niri inspired by Gravity Rush.
// Wallpaper with a picker, a bar, a system monitor, a session menu, settings, a keybind cheatsheet, notifications, volume/brightness popups and a lock screen. Colours are
// the built-in palette, made from an accent colour or picked from the wallpaper with matugen, light or
// dark (services/Theme.qml).
import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.controls
import qs.modules.keybinds
import qs.modules.lock
import qs.modules.monitor
import qs.modules.notifications
import qs.modules.osd
import qs.modules.quickpanel
import qs.modules.session
import qs.modules.settings
import qs.modules.traymenu
import qs.modules.wallpaper

ShellRoot {
    Wallpaper {}
    Bar {}
    Controls {}
    Keybinds {}
    Lock {}
    Monitor {}
    Notifications {}
    Osd {}
    QuickPanel {}
    Session {}
    Settings {}
    TrayMenu {}
    Picker {}
}
