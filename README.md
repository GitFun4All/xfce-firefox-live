# Xfce Firefox Live (Alpine)

A small Alpine Linux diskless ISO that boots to Xfce, automatically logs in as
`kiosk`, and opens Firefox in a **normal browser window** (not kiosk mode). The
default start page is `about:blank`; the address bar and browser controls remain
available. The live overlay is temporary, so changes disappear on reboot.

## Included

- Alpine Linux 3.24 (x86_64) with the slim `virt` kernel profile.
- No general-purpose firmware bundle; this image is aimed at virtual machines.
- Minimal Xorg and Xfce session, panel, window manager, settings, app finder, and
  `xfce4-terminal`.
- Firefox ESR with the normal toolbar/address bar, launched automatically.
- NetworkManager with its tray applet, connection editor, `nmcli`, and `nmtui`;
  eudev device management, and DHCP for a wired Hyper-V adapter.
- Basic network tools (`ip`, `ping`, `curl`, and `dig`).
- The QEMU guest agent and its OpenRC service only; **no QEMU emulator or image
  utilities** are installed. The agent starts only when its virtio-serial channel
  exists, so it remains idle under Hyper-V.

The Firefox URL is set in `alpine/rootfs/etc/xfce-kiosk/url`. Change it to an
`http://` or `https://` URL (or `about:blank`) before building. The browser
launcher can also be edited in Firefox at runtime.

## Build

Build using Podman or Docker:

```sh
./build-container.sh
```

The wrapper uses the Alpine 3.24 builder, forwards proxy variables, and does not
need a privileged container. To build directly on an Alpine 3.24 x86_64 host,
install the packages listed in `Containerfile`, then run `sudo ./build.sh`.

The output is `xfce-firefox-alpine-v3.24-x86_64.iso`. A clean rebuild (removing
the generated mkimage cache) is available with:

```sh
CLEAN_LIVE_BUILD=1 ./build-container.sh
```

The clean build downloads packages again. Build branch, package set, and runtime
configuration are in `alpine/`; `build.sh` uses Alpine's `mkimage` scripts from
an archive of the matching `3.24-stable` aports branch. This subdirectory holds
the source recipe only; generated ISOs and caches are ignored by Git.
The current ISO is about 319 MiB; package updates can change its size.

## GitHub releases

Manual workflow runs build a downloadable artifact. To build and publish a
release, push a tag matching `xfce-firefox-alpine-*`, for example:

```sh
git tag xfce-firefox-alpine-2026-11-05
git push origin xfce-firefox-alpine-2026-11-05
```

The workflow attaches the ISO and a SHA-256 checksum file to the release.

## Hyper-V preview

Copy the ISO and `preview-hyperv.ps1` to Windows. In elevated PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\preview-hyperv.ps1 -IsoPath "$env:USERPROFILE\Downloads\xfce-firefox-alpine-v3.24-x86_64.iso"
```

The helper creates a Generation 2 VM with 4 GiB memory, two vCPUs, no virtual
disk, and the `Default Switch`. If needed, pass `-SwitchName "Your switch name"`.

The graphical session automatically logs in as `kiosk` (password `live` for a
text console). Firefox starts at `about:blank` with normal browser controls; use
`xfce4-terminal` from the Xfce application menu, or `nmtui` in the terminal, to
manage or troubleshoot networking.

This is a live image, not an installer. Its writable state and Firefox profile
are lost after reboot; rebuild the ISO to apply permanent image changes and
package updates.
