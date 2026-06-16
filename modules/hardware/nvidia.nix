{ ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable     = true;
    powerManagement.enable = false;
    # Open kernel module — Turing (RTX 20xx) and newer only. Flip to false
    # if this config ever lands on a Pascal-or-older card.
    open                   = true;
    nvidiaSettings         = true;
  };

  # External monitor (HDMI) is on the dGPU; without this the driver scales the
  # dGPU down to P8/~210MHz on idle, giving visible "wake-up" lag on the first
  # input after a pause. 0x00 disables fine-grained runtime PM entirely.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';
}
