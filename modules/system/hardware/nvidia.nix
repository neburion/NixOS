{ config, lib, pkgs, ... }:

# Behavior module. Physical facts (bus IDs, external-display-on-dGPU flag,
# open-vs-legacy kernel module) come from the host's environment layer at
# hosts/<host>/hardware/gpu.nix. Import this module only on
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

  # The boot that follows a Windows session can fail to insert nvidia_uvm with
  # ENOMEM: Fast Startup hibernates rather than powers down, so the GPU is still
  # claimed and UVM cannot reserve its memory that early. Vulkan still enumerates
  # the card, so nothing looks broken until vkCreateDevice returns
  # VK_ERROR_INITIALIZATION_FAILED and every Proton title exits a few seconds
  # after launch. A later insert always succeeds, so retry once userspace is up.
  systemd.services.nvidia-uvm-retry = {
    description = "Retry nvidia_uvm when the boot-time insert failed";
    after      = [ "systemd-modules-load.service" ];
    wantedBy   = [ "multi-user.target" ];

    # Skips itself entirely on a healthy boot, so a failure here is a real signal.
    unitConfig.ConditionPathExists = "!/dev/nvidia-uvm";

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      for attempt in 1 2 3 4 5; do
        ${pkgs.kmod}/bin/modprobe nvidia_uvm && exit 0
        sleep 2
      done
      echo "nvidia_uvm still refuses to load; a full power-off should clear it" >&2
      exit 1
    '';
  };
}
