# gnome-os

[![bluebuild](https://github.com/RubenvanGastel/bluebuild-os/actions/workflows/build.yml/badge.svg)](https://github.com/RubenvanGastel/bluebuild-os/actions/workflows/build.yml)

My personal Fedora Atomic desktop: GNOME and niri, built with [BlueBuild](https://blue-build.org) on top of [Universal Blue](https://universal-blue.org). The images are rebuilt every day at 06:00 UTC.

| Image | For | Base |
| --- | --- | --- |
| `ghcr.io/rubenvangastel/gnome-os` | Intel / AMD graphics | `silverblue-main` |
| `ghcr.io/rubenvangastel/gnome-os-nvidia` | NVIDIA graphics | `silverblue-nvidia` |

Both images use the same module list, [`recipes/common-modules.yml`](recipes/common-modules.yml). Editing that file changes both.

## What's inside

### Desktops

- **GNOME** with the [MoreWaita](https://github.com/somepaulo/MoreWaita) icon theme and the [Hot Edge](https://extensions.gnome.org/extension/4222/hot-edge/) extension turned on.
- **niri**, a scrollable-tiling Wayland compositor, which you can choose at login. It runs the **Gravity shell**, a custom [Quickshell](https://quickshell.org) desktop inspired by Gravity Rush, with an animated wallpaper, a bar, notifications and a lock screen ([details](files/system/usr/share/gravity-shell/README.md)). `fuzzel` is the app launcher.
- A **Miku Plymouth** boot animation.

### Apps

| | RPM (part of the image) | Flatpak (installed on first boot) |
| --- | --- | --- |
| Browser & chat | | Zen Browser, Vesktop |
| Gaming | | Steam |
| System | GNOME Tweaks | Resources, Flatseal, Gear Lever, DistroShelf |
| Terminal | eza, fastfetch, zsh (+ autosuggestions, syntax highlighting) | |

Dev tools are installed per user, so they update themselves without an image rebuild:

- `ujust install-claude-code`: Claude Code in `~/.local/bin` (auto-updates)
- `ujust install-antigravity`: Antigravity IDE in `~/.local/opt` (run again to update)

Resources replaces the System Monitor, htop and nvtop that come with the base image.

### Defaults

- The Compose key is **Right Alt**. For example, press Right Alt, then `'` and `e` to type é.
- `ls`, `ll`, `la` and `lt` run **eza** with icons, using Nerd Font symbols.
- Each user can change any of these. The defaults live in [`files/gschema-overrides/`](files/gschema-overrides/).

## Installing

Start from any Fedora Atomic install, for example Fedora Silverblue, and rebase twice:

```bash
IMAGE=gnome-os          # or gnome-os-nvidia

# 1. Unsigned first, to get the signing policy
rpm-ostree rebase ostree-unverified-registry:ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot

# 2. Then switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot
```

> [!NOTE]
> **NVIDIA with Secure Boot:** enroll the Universal Blue key once with `ujust enroll-secure-boot-key`. The password is `universalblue`.

## Repository layout

```text
recipes/
  recipe.yml            Intel / AMD image
  recipe-nvidia.yml     NVIDIA image
  common-modules.yml    everything both images share
files/
  dnf/                  extra RPM repositories
  gschema-overrides/    default GNOME settings
  scripts/              build scripts (Plymouth theme)
  system/               copied as-is into the image root (/)
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
5. In GitHub → Packages, make both packages **public**.

</details>
