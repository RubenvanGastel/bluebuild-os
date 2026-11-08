#!/usr/bin/bash
# Turns one of this repo's images into a live installer image (see ../Containerfile).
# Based on Titanoboa's Bazzite example:
# https://github.com/ublue-os/titanoboa/tree/main/examples/bazzite
set -exo pipefail

: "${IMAGE:?IMAGE must be set, e.g. gravity}"
IMAGE_REF="ghcr.io/rubenvangastel/${IMAGE}:latest"
ISO_LABEL="${IMAGE}-live"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# /root is a symlink to /var/roothome, which doesn't exist in a container build
mkdir -p "$(realpath /root)"
# bwrap (used by flatpak) writes to /proc/sys/user/max_user_namespaces
mount -o remount,rw /proc/sys
# bootc images ship an empty /var, but flatpak (ostree) needs /var/tmp for temp files
mkdir -p /var/tmp /tmp /var/lib/flatpak
chmod 1777 /var/tmp /tmp

### Flatpaks ###################################################################
# Install the image's own default-flatpaks list (from the recipes) into /var/lib/flatpak.
# The installer copies this into the new system, see install-flatpaks below.
# A configuration without a repo (like the GNOME-only one) uses Flathub.
flatpaks() {
    /usr/libexec/bluebuild/nu/nu -c '
        open /usr/share/bluebuild/default-flatpaks/configuration.yaml
        | where scope == system
        | each {|c|
            let name = ($c.repo?.name? | default flathub)
            let url = ($c.repo?.url? | default https://dl.flathub.org/repo/flathub.flatpakrepo)
            $c.install? | default [] | each {|app| $"($name) ($url) ($app)" }
        }
        | flatten | str join (char nl)'
    echo
}
flatpaks | while read -r remote url app; do
    [[ -n $app ]] || continue
    flatpak remote-add --system --if-not-exists "$remote" "$url"
    flatpak install --system --noninteractive "$remote" "$app"
done

### Live boot ##################################################################
dnf install -y dracut-live livesys-scripts
kernel="$(ls /usr/lib/modules)"
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# livesys creates "liveuser" and logs it in: GNOME through GDM, niri through greetd
if [[ -f /usr/share/wayland-sessions/gnome.desktop ]]; then
    session=gnome
else
    session=niri
    install -m 0644 "$SRC/livesys-niri" /usr/libexec/livesys/sessions.d/livesys-niri
fi
sed -i "s/^livesys_session=.*/livesys_session=${session}/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# / of a live system is an overlay in /run, too small for ostree's temp files in /var/tmp
mkdir -p /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# No updates or first-boot Flatpak installs in the live session
for unit in system-flatpak-setup.timer flatpak-system-update.timer \
    rpm-ostreed-automatic.timer uupd.timer bootloader-update.service; do
    systemctl disable "$unit" || :
done
for unit in user-flatpak-setup.timer flatpak-user-update.timer; do
    systemctl --global disable "$unit" || :
done

### Installer (Anaconda) #######################################################
dnf install -y anaconda-live anaconda-webui firefox libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state # needed by the Anaconda web UI

mkdir -p /etc/anaconda/conf.d
cat >/etc/anaconda/conf.d/90-bluebuild.conf <<'EOF'
[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[Localization]
use_geolocation = False
EOF

# Create Account page. GNOME has gnome-initial-setup create the user on first boot, so
# the installer skips it there (like Fedora Workstation and Silverblue). Without it
# (gravity, niri) the installer must create the user, so the page is always shown.
# The web UI never shows its Network page on live media: you connect in the live
# session instead (GNOME's or the shell's Wi-Fi menu, or nmtui in a terminal).
if [[ -x /usr/libexec/gnome-initial-setup ]]; then
    hidden_pages=anaconda-screen-accounts
else
    hidden_pages=
fi
cat >>/etc/anaconda/conf.d/90-bluebuild.conf <<EOF

[User Interface]
hidden_spokes =
hidden_webui_pages = ${hidden_pages}
EOF

# What the installer does: install the image from the registry, then switch it to the
# signed image (no second rebase needed) and copy in the Flatpaks.
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=${IMAGE_REF} --transport=registry --no-signature-verification

# Updates come from the signed image; the image ships the signing policy for it
%post --erroronfail --log=/tmp/bluebuild-signed-image.log
sed -i 's|container-image-reference=.*|container-image-reference=ostree-image-signed:docker://${IMAGE_REF}|' /ostree/deploy/default/deploy/*.origin
%end

# Copy the Flatpaks from the live system into /var of the new system
%post --erroronfail --nochroot --log=/tmp/bluebuild-install-flatpaks.log
set -x
target="\$(echo /mnt/sysimage/ostree/deploy/default/deploy/*.0/var/lib)"
mkdir -p "\$target"
rsync -aAXUHK --filter='-x security.selinux' /var/lib/flatpak "\$target"
%end
EOF

# NVIDIA images: queue the Universal Blue key for Secure Boot (password: universalblue)
if [[ $IMAGE == *-nvidia ]]; then
    cat >>/usr/share/anaconda/interactive-defaults.ks <<'EOF'

%post --nochroot --log=/tmp/bluebuild-secureboot-key.log
key=/etc/pki/akmods/certs/akmods-ublue.der
if [ -d /sys/firmware/efi ] && [ -f "$key" ]; then
    mokutil --timeout -1 || :
    printf 'universalblue\nuniversalblue\n' | mokutil --import "$key" || :
fi
%end
EOF
fi

### ISO layout (Titanoboa) #####################################################
dnf install -y grub2-efi-x64-cdboot
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

mkdir -p /usr/lib/bootc-image-builder
cat >/usr/lib/bootc-image-builder/iso.yaml <<EOF
label: "${ISO_LABEL}"
grub2:
  timeout: 10
  entries:
    - name: "Install ${IMAGE}"
      linux: "/images/pxeboot/vmlinuz quiet rhgb root=live:CDLABEL=${ISO_LABEL} enforcing=0 rd.live.image"
      initrd: "/images/pxeboot/initrd.img"
    - name: "Install ${IMAGE} (basic graphics)"
      linux: "/images/pxeboot/vmlinuz quiet rhgb root=live:CDLABEL=${ISO_LABEL} enforcing=0 rd.live.image nomodeset"
      initrd: "/images/pxeboot/initrd.img"
EOF

rm -f /etc/localtime
systemd-firstboot --timezone UTC
dnf clean all
