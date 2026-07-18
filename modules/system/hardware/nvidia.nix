{ config, lib, ... }:

# Behavior module. Physical facts (bus IDs, external-display-on-dGPU flag,
# open-vs-legacy kernel module) come from the host's environment layer at
# hosts/<host>/hardware-layout/gpu-layout.nix. Import this module only on
# hosts with an NVIDIA card.

{
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable     = true;
    powerManagement.enable = false;
    open                   = config.gpu.openKernelModule;
    nvidiaSettings         = true;

    prime = {
      offload = {
        enable           = true;
        enableOffloadCmd = true;
      };
      intelBusId  = config.gpu.prime.intelBusId;
      nvidiaBusId = config.gpu.prime.nvidiaBusId;
    };
  };

  # Without this, the driver scales the dGPU down to P8/~210MHz on idle,
  # giving visible "wake-up" lag on the first input after a pause. Only
  # applies when an external monitor is wired to the discrete GPU.
  boot.extraModprobeConfig = lib.mkIf config.gpu.externalMonitorOnDgpu ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';
}
