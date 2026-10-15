//@ pragma ShellId gravity
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Gravity: a Quickshell desktop for niri inspired by Gravity Rush.
// Wallpaper with a picker, a levitating bar, notifications and a lock screen. Colours are
// the built-in palette or picked from the wallpaper with matugen (services/Theme.qml).
import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.lock
import qs.modules.notifications
import qs.modules.wallpaper

ShellRoot {
    Wallpaper {}
    Bar {}
    Lock {}
    Notifications {}
    Picker {}
}
