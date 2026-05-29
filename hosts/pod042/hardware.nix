{ ... }:

{
  imports = [
    ../../modules/hardware/bluetooth.nix
    ../../modules/hardware/graphics.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/power-profiles.nix
    ../../modules/hardware/touchpad.nix
  ];

  # Hybrid Intel + NVIDIA — bus IDs specific to this machine.
  hardware.nvidia.prime = {
    offload = {
      enable           = true;
      enableOffloadCmd = true;
    };
    intelBusId  = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
}
