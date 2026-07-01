# THIS WILL ONLY WORK FOR POD042 DO NOT USE IN AN OTHER HOST
{ ... }:

{
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable     = true;
    powerManagement.enable = false;
    # Open kernel module — Turing (RTX 20xx) and newer only. Flip to false
    # if this config ever lands on a Pascal-or-older card.
    open                   = true;
    nvidiaSettings         = true;
  };
  
  hardware.nvidia.prime = {
    offload = {
      enable           = true;
      enableOffloadCmd = true;
    };
    intelBusId  = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  # External monitor (HDMI) is on the dGPU; without this the driver scales the
  # dGPU down to P8/~210MHz on idle, giving visible "wake-up" lag on the first
  # input after a pause. 0x00 disables fine-grained runtime PM entirely.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';
}
