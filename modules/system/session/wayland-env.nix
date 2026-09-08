{ ... }:

{
  environment.sessionVariables = {
    NIXOS_OZONE_WL     = "1";  # electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1";

    # NOT set here: AQ_DRM_DEVICES. See below before adding it back.
    #
    # This laptop's outputs are split across both GPUs — HDMI-A-1, the 4K
    # panel, hangs off the NVIDIA card at 01:00.0, while DP-1 and the built-in
    # eDP-1 are on the Intel iGPU at 00:02.0. aquamarine picks Intel as primary,
    # so every 4K frame is composited on the iGPU and then copied over PCIe to
    # the NVIDIA card purely to be scanned out, in a linear (untileable) buffer:
    #
    #   drm: gpu /dev/dri/card1 becomes primary drm
    #   GBM: Buffer is marked as multigpu, forcing linear
    #
    # Measured idle, no game and no video: 2.1-4.4 GB/s inbound to the dGPU,
    # against 33 MB per 3840x2160 frame — roughly 66-130 fps of copy bandwidth
    # feeding a 144 Hz panel. Worth fixing. It is the reason the desktop got
    # less smooth when the mode went native.
    #
    # The obvious fix is AQ_DRM_DEVICES naming the NVIDIA card first. The trap,
    # which cost generation 431 and two failed logins on 2026-09-08, is that
    # the variable is COLON-separated and PCI addresses contain colons, so the
    # stable /dev/dri/by-path/ names cannot be used:
    #
    #   AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/...
    #   ERR drm: Failed to canonicalize path /dev/dri/by-path/pci-0000
    #   ERR drm: Failed to canonicalize path 01
    #   ERR drm: Found no gpus to use, cannot continue
    #   CRIT Cannot open backend: no allocator available
    #
    # Hyprland then aborts in CCompositor::initServer and SDDM takes you back
    # to the greeter. Bare cardN names parse fine, but DRM card numbering is
    # not stable across boots and getting it backwards silently restores the
    # slow path. aquamarine canonicalizes each entry, so the way in is a udev
    # rule creating colon-free stable symlinks matched on PCI address.
  };
}
