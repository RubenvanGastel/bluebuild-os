# bluebuild-os

My custom GNOME images, built with [BlueBuild](https://blue-build.org) on top of [Universal Blue](https://universal-blue.org).

| Image | For | Base |
|---|---|---|
| `ghcr.io/rubenvangastel/gnome-os` | Intel / AMD laptops | `silverblue-main` |
| `ghcr.io/rubenvangastel/gnome-os-nvidia` | NVIDIA laptops | `silverblue-nvidia` |

Both share [`recipes/common-modules.yml`](recipes/common-modules.yml).

**Included:** GNOME, Antigravity (RPM), Steam, Zen Browser, Vesktop, Extension Manager, Flatseal (Flatpaks).
**Claude Code:** run `ujust install-claude-code` once per user.

## One-time setup

1. Push this folder to a new **public** GitHub repo.
2. Generate signing keys (in the repo folder):
   ```bash
   nix shell nixpkgs#cosign -c cosign generate-key-pair
   # press Enter twice for an empty password
   # (non-Nix: podman run --rm -it -v "$PWD:/w:Z" -w /w ghcr.io/sigstore/cosign/cosign generate-key-pair)
   ```
3. Add `cosign.key` contents as a GitHub repo secret named `SIGNING_SECRET`
   (Settings → Secrets and variables → Actions). **Never commit `cosign.key`.**
4. Commit `cosign.pub`, push, and wait for the Actions build to finish.
5. In GitHub → Packages, make both packages **public**.

## Installing on a laptop

Start from any Fedora Atomic install (e.g. Fedora Silverblue), then:

```bash
# NVIDIA laptop -> use gnome-os-nvidia ; others -> gnome-os
IMAGE=gnome-os-nvidia

# 1st rebase: unsigned (to get the signing policy)
rpm-ostree rebase ostree-unverified-registry:ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot

# 2nd rebase: signed
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/rubenvangastel/$IMAGE:latest
systemctl reboot
```

On the NVIDIA image with Secure Boot on, enroll the Universal Blue key once:
`ujust enroll-secure-boot-key` (password: `universalblue`).
