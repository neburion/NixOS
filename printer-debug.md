# Canon MF3010 Printing Debug Notes

## Hardware
- Canon MF3010 (2012 laser printer) connected via USB
- `/dev/usb/lp0` — char device, `crw-rw---- 1 root lp` (usblp kernel module bound)
- NixOS 26.05, CUPS 2.4.19

## Current NixOS Config
- `modules/system/printing.nix` — CUPS + web print server on port 8080
- `modules/system/canon-cups-ufr2/package.nix` — local override of canon-cups-ufr2 **v6.00**
  (nixpkgs ships v6.20, downgraded because of suspected incompatibility with MF3010)
- `boot.kernelModules = [ "usblp" ]` — loads usblp at boot so `/dev/usb/lp0` appears
- `systemd.tmpfiles.rules` — creates `/usr/share/{cnpkbidir,caepcm,ufr2filterr}` symlinks
- Printer URI: `cnusbufr2:/dev/usb/lp0`

## What Works
- USB device opens fine: backend `cnusbufr2` successfully opens `/dev/usb/lp0` (fd 6)
- Raw bytes reach the printer: `lp -o raw` sends data through cleanly, job completes
- Filter chain processes: ghostscript → pdftopdf → ghostscript → rastertoufr2 all exit cleanly
- 540 bytes of UFR2 data IS written to `/dev/usb/lp0` per job (header/init sequence)
- All libraries load correctly: confirmed via `ldd .cnrsdrvufr2-wrapped` — libstdc++, libjpeg, libgcrypt all resolve

## Root Cause (CONFIRMED by direct test)
`cnrsdrvufr2` **segfaults** (SIGSEGV / exit 139). This is why only the 540-byte UFR2 job
header reaches the printer — `cnrsdrvufr2` crashes before writing any raster data to
`cnpkmoduleufr2r`.

```
$ /nix/store/k0b767igcd5bxwcarpji6j5kiwijq20p-canon-cups-ufr2-6.00/bin/cnrsdrvufr2
Segmentation fault (core dumped)
exit code: 139
```

## Most Likely Cause of Segfault
The binary reads model-specific `.res` resource files from `/usr/share/cngplp2/`.
The nix store has these at `$out/share/cngplp2/` (885 files including `CNM3010ZK.res`,
`CNM3010ZS.res`). The symlink `/usr/share/cngplp2` was **created manually** once but is
NOT in `systemd.tmpfiles.rules`, so it disappears after rebuild/reboot. Without it, the
binary likely dereferences a null pointer from a failed file lookup → segfault.

## The Fix to Apply Next
Add to `systemd.tmpfiles.rules` in `modules/system/printing.nix`:
```nix
"L+ /usr/share/cngplp2 - - - - ${pkgs.canon-cups-ufr2}/share/cngplp2"
```

Also possibly needed — create the options file the binary checks for:
```nix
environment.etc."cngplp2/options/options.conf".text = "";
```

Then rebuild and test: `lp -d MF3010 /tmp/test.pdf`

## Confirmed NOT the Cause
- `libstdc++.so.6` missing — PR #397705 fixed lib64→lib rpath; our package.nix already uses `/lib`
- `libxml2` ABI mismatch — PR #475147 fixed; our package uses `libxml2_13`
- `dontPatchELF` missing — already set; libjpeg/libgcrypt dlopen works
- Missing `/usr/share/{cnpkbidir,caepcm,ufr2filterr}` — all present via tmpfiles

## nixpkgs Issues Researched
- #310013: blank pages / segfault — fixed by dontPatchELF + libjpeg/libgcrypt (applied)
- #396654: libstdc++ not found — fixed by lib64→lib patchelf rpath (applied)
- #397705 (PR): the lib64→lib fix
- #440634: libxml2_13 fix (applied)
- #475147 (PR): the libxml2_13 fix
- #381315 (PR): RPM spec rework (introduced lib64 regression)

Also: Voldemaar84 on Ubuntu 24.04 with v6.10 also gets cnrsdrvufr2 segfault — suggests
this is a recurring issue across distros/versions when resource files are missing or
patchelf strips needed paths.
