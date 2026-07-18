{ lib, ... }:

{
  options.gpu = {
    prime.intelBusId  = lib.mkOption {
      type = lib.types.str;
      description = "PCI bus ID of the integrated Intel GPU (e.g. PCI:0:2:0).";
    };
    prime.nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      description = "PCI bus ID of the discrete NVIDIA GPU (e.g. PCI:1:0:0).";
    };
    openKernelModule = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use NVIDIA's open kernel module. Turing (RTX 20xx) and newer only —
        flip false for Pascal or older.
      '';
    };
    externalMonitorOnDgpu = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        True when a physical external display is wired to the discrete GPU.
        Disables fine-grained runtime PM (NVreg_DynamicPowerManagement=0x00)
        to avoid the wake-up lag on first input after idle.
      '';
    };
  };

  config.gpu = {
    prime.intelBusId  = "PCI:0:2:0";
    prime.nvidiaBusId = "PCI:1:0:0";
    openKernelModule  = true;
    externalMonitorOnDgpu = true;
  };
}
