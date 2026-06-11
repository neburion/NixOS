{ ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable     = true;
    powerManagement.enable = false;
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
