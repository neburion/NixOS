# Hardware

`modules/hardware/` — **no `default.nix`**. Each host imports the modules it needs in `hosts/<host>/hardware.nix`.

## Files

| File | What it enables | Per-host data needed |
|---|---|---|
| `bluetooth.nix` | `hardware.bluetooth` + `services.blueman` | — |
| `graphics.nix` | `hardware.graphics.enable` (replaces deprecated `hardware.opengl`) | — |
| `nvidia.nix` | `services.xserver.videoDrivers = [ "nvidia" ]`; `hardware.nvidia` with `modesetting`, `open`, `nvidiaSettings`. **Does NOT enable PRIME.** | If the host has hybrid GPUs: set `hardware.nvidia.prime.{offload,intelBusId,nvidiaBusId}` in the host's `hardware.nix`. |
| `power-profiles.nix` | `services.power-profiles-daemon.enable` | — |
| `touchpad.nix` | `services.libinput.enable` | — |

## Pattern: extending a hardware module per-host

`modules/hardware/nvidia.nix` ships generic NVIDIA settings. Host-specific bits (PRIME enable + bus IDs) layer on top:

```nix
# hosts/pod042/hardware.nix
{ ... }:
{
  imports = [
    ../../modules/hardware/nvidia.nix
    # other hardware…
  ];

  hardware.nvidia.prime = {
    offload = { enable = true; enableOffloadCmd = true; };
    intelBusId  = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
}
```

This lets the module stay portable. A different host with non-hybrid NVIDIA imports the same `nvidia.nix` and just doesn't set PRIME.

## See also

- [[Hosts/pod042]] — example consumer
- [[Modules/Audio]] — PipeWire (audio hardware setup)
