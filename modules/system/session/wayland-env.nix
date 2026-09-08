{ ... }:

{
  environment.sessionVariables = {
    NIXOS_OZONE_WL     = "1";  # electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1";

    # Render on the dGPU, because that is where the 4K panel is plugged in.
    #
    # This laptop's outputs are split across both GPUs: HDMI-A-1 hangs off the
    # NVIDIA card at 01:00.0, while DP-1 and the built-in eDP-1 are on the
    # Intel iGPU at 00:02.0. Left alone, aquamarine picks the Intel card as
    # primary and every finished frame for the 4K monitor is copied over PCIe
    # to the NVIDIA card just to be scanned out — and marked multigpu, so the
    # buffer cannot even be tiled:
    #
    #   drm: gpu /dev/dri/card1 becomes primary drm
    #   GBM: Buffer is marked as multigpu, forcing linear
    #
    # Measured on an idle desktop, that copy ran at 2.1-4.4 GB/s inbound to
    # the dGPU. A 3840x2160 frame is 33 MB, so the path was delivering
    # something like 66-130 fps against a 144 Hz panel. Naming the NVIDIA card
    # first makes it primary: the 4K output now renders and scans out on the
    # same chip and the copy disappears. DP-1 becomes the copied output
    # instead, at 8 MB a frame and 60 Hz.
    #
    # by-path rather than card0/card1 on purpose — DRM card numbering is not
    # stable across boots, and on this machine the NVIDIA card currently takes
    # card0, which is the reverse of the usual ordering. Getting this backwards
    # silently restores the slow path rather than failing.
    #
    # This keeps the dGPU powered for the whole session, which costs battery
    # when running on the built-in panel alone. Deliberate: smoothness while
    # docked was worth more.
    AQ_DRM_DEVICES =
      "/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:02.0-card";
  };
}
