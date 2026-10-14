//@ pragma ShellId gravity
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Gravity: a Quickshell desktop for niri inspired by Gravity Rush.
// Floating debris wallpaper, a levitating bar, notifications and a seamless lock screen.
import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.lock
import qs.modules.notifications

ShellRoot {
    Wallpaper {}
    Bar {}
    Lock {}
    Notifications {}
}
