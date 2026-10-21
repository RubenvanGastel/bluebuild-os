# bluebuild-os

[![bluebuild](https://github.com/RubenvanGastel/bluebuild-os/actions/workflows/build.yml/badge.svg)](https://github.com/RubenvanGastel/bluebuild-os/actions/workflows/build.yml)

My personal Fedora Atomic desktops: GNOME, niri with my Gravity shell, or niri with Dux Shell, built with [BlueBuild](https://blue-build.org) on top of [Universal Blue](https://universal-blue.org). The images are rebuilt every day at 06:00 UTC.

| Image | For | Base |
| --- | --- | --- |
| `ghcr.io/rubenvangastel/gnome` | GNOME, Intel / AMD graphics | `silverblue-main` |
| `ghcr.io/rubenvangastel/gnome-nvidia` | GNOME, NVIDIA graphics | `silverblue-nvidia` |
| `ghcr.io/rubenvangastel/gravity` | niri + Gravity shell, Intel / AMD graphics | `base-main` |
| `ghcr.io/rubenvangastel/gravity-nvidia` | niri + Gravity shell, NVIDIA graphics | `base-nvidia` |
| `ghcr.io/rubenvangastel/niri` | niri + Dux Shell, Intel / AMD graphics | `base-main` |
| `ghcr.io/rubenvangastel/niri-nvidia` | niri + Dux Shell, NVIDIA graphics | `base-nvidia` |

The gravity and niri images have no GNOME. Each recipe is put together from module lists in [`recipes/`](recipes/):

| Module list | Used by |
| --- | --- |
| [`shared-modules.yml`](recipes/shared-modules.yml) | all images: terminal, zsh, flatpaks, Plymouth |
| [`gnome-modules.yml`](recipes/gnome-modules.yml) | gnome, gnome-nvidia |
| [`niri-base-modules.yml`](recipes/niri-base-modules.yml) | gravity and niri images: niri, the greetd login screen, desktop basics |
| [`gravity-modules.yml`](recipes/gravity-modules.yml) | gravity, gravity-nvidia |
| [`dux-modules.yml`](recipes/dux-modules.yml) | niri, niri-nvidia |

## What's inside

### Desktops

- **GNOME** with the [MoreWaita](https://github.com/somepaulo/MoreWaita) icon theme and the [Hot Edge](https://extensions.gnome.org/extension/4222/hot-edge/), [AppIndicator](https://extensions.gnome.org/extension/615/appindicator-support/) and [Alphabetical App Grid](https://extensions.gnome.org/extension/4269/alphabetical-app-grid/) extensions turned on.
- **Gravity shell** (gravity images): [niri](https://github.com/niri-wm/niri), a scrollable-tiling Wayland compositor, with my own [Quickshell](https://quickshell.org) desktop inspired by Gravity Rush: an animated wallpaper, a bar, notifications and a lock screen ([details](files/gravity/usr/share/gravity-shell/README.md)). `fuzzel` is the app launcher. Coming from the niri image? Run `ujust gravity-niri-config` to move the Dux `~/.config/niri` aside (keeping a backup) so niri uses the Gravity config in `/etc/niri`.
- **Dux Shell** (niri images), formerly [DankMaterialShell](https://duxlabs.dev): niri with the Dux Shell bar, launcher (Mod+Space), notifications, lock screen and settings (Mod+Comma). On your first login `/etc/niri` is copied to `~/.config/niri`, because Dux Shell keeps its colours and keybinds in `~/.config/niri/dms/`. Run `ujust dux-greeter-sync` once to give the login screen your theme and wallpaper. Already have your own `~/.config/niri`, e.g. from the gravity image? `ujust dux-niri-config` swaps it for the Dux one (keeping a backup).
- The gravity and niri images log in with **Dux Greeter** (greetd).
- A **Miku Plymouth** boot animation.

### Apps

| | RPM (part of the image) | Flatpak (installed on first boot) |
| --- | --- | --- |
| Browser & chat | | Zen Browser, Vesktop |
| Gaming | | Steam |
| System | | Resources, Flatseal, Gear Lever, DistroShelf, Bazaar, Refine (GNOME) |
| Terminal | Ghostty, zsh, eza, fastfetch | |

Dev tools are installed per user, so they update themselves without an image rebuild:

- `ujust install-claude-code`: Claude Code in `~/.local/bin` (auto-updates)
- `ujust install-antigravity`: Antigravity IDE in `~/.local/opt` (run again to update)

Resources replaces the System Monitor, htop and nvtop that come with the base images.

### Defaults

- On GNOME, the Compose key is **Right Alt**. For example, press Right Alt, then `'` and `e` to type é.
- **Ghostty** uses the [cursor warp and ripple shaders](https://github.com/sahaj-b/ghostty-cursor-shaders). New users get a `~/.config/ghostty/config.ghostty` that includes `/etc/ghostty/config`; existing users can copy it from `/etc/skel/.config/ghostty/config.ghostty`.
- **zsh** is everyone's login shell, set up like fish: suggestions from your history (Right arrow accepts), syntax highlighting, a Tab completion menu, history shared between terminals and a prompt with the folder and git branch. Every new user gets it. The defaults are in `/etc/zshrc.d`, and your own `~/.zshrc` overrides them.
- `ls`, `ll`, `la` and `lt` run **eza** with icons, using Nerd Font symbols.
- Each user can change any of these. The defaults live in [`files/gschema-overrides/`](files/gschema-overrides/).

## Installing

Start from any Fedora Atomic install, for example Fedora Silverblue, and rebase twice:

```bash
IMAGE=gnome             # or gnome-nvidia, gravity, gravity-nvidia, niri, niri-nvidia

# 1. Unsigned first, to get the signing policy
rpm-ostree rebase ostree-unverified-registry:ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot

# 2. Then switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot
```

Switching between these images takes both steps as well: the signing policy is set up per image name. The old `gnome-os` / `gnome-os-nvidia` images no longer get updates; their GNOME is now `gnome`, their niri session `gravity`.

> [!NOTE]
> **NVIDIA with Secure Boot:** enroll the Universal Blue key once with `ujust enroll-secure-boot-key`. The password is `universalblue`.

## Repository layout

```text
recipes/
  recipe-*.yml          one recipe per image
  *-modules.yml         module lists the recipes are put together from (see above)
files/
  gschema-overrides/    default GNOME settings
  scripts/              build scripts (Plymouth theme, zsh, greetd, Dux and Gravity setup)
  shared/               copied into every image root (/)
  niri-base/            copied into the gravity and niri images (greetd config)
  gravity/              copied into the gravity images (Gravity shell, its niri config, ujust recipes)
  dux/                  copied into the niri images (Dux Shell niri config, ujust recipes)
```

<details>
<summary><strong>Setting up a fork from scratch</strong></summary>

1. Push the repository to a **public** GitHub repo.
2. Generate a signing key pair. Press Enter twice for an empty password.
   ```bash
   nix shell nixpkgs#cosign -c cosign generate-key-pair
   # without Nix:
   # podman run --rm -it -v "$PWD:/w:Z" -w /w ghcr.io/sigstore/cosign/cosign generate-key-pair
   ```
3. Add the contents of `cosign.key` as a repository secret named `SIGNING_SECRET` (Settings → Secrets and variables → Actions). **Never commit `cosign.key`.**
4. Commit `cosign.pub`, push, and wait for the Actions build to finish.
5. In GitHub → Packages, make all six packages **public**.

</details>
