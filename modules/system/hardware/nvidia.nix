{ config, lib, pkgs, ... }:

# Behavior module. Physical facts (bus IDs, external-display-on-dGPU flag,
# open-vs-legacy kernel module) come from the host's environment layer at
# hosts/<host>/hardware/gpu.nix. Import this module only on
# hosts with an NVIDIA card.

let
  # NVIDIA writes bus IDs as "PCI:1:0:0"; udev and sysfs want "0000:01:00.0".
  toPciAddr = id:
    let
      parts = lib.splitString ":" (lib.removePrefix "PCI:" id);
      pad   = lib.fixedWidthString 2 "0";
    in
    "0000:${pad (lib.elemAt parts 0)}:${pad (lib.elemAt parts 1)}.${lib.elemAt parts 2}";

  # Graphics-clock floor held while the performance profile is selected, MHz.
  # Supported clocks on this card start at 210 and step by 15; 810 is on-grid.
  gpuClockFloor = 810;

  nvidiaAddr = toPciAddr config.gpu.prime.nvidiaBusId;
  intelAddr  = toPciAddr config.gpu.prime.intelBusId;
in
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

  # Keeps the card out of runtime suspend (D3cold), which otherwise costs a
  # wake-up stall on the first input after idle. Only applies when an external
  # monitor is wired to the discrete GPU.
  #
  # This does NOT stop P-state scaling, despite what this comment used to
  # claim. Verified 2026-09-08: with DynamicPowerManagement reading 0 the card
  # still parks at P8/210MHz, with "Idle" as its only active clock event
  # reason. Suspend and clock scaling are separate mechanisms -- the clock
  # floor below is what addresses the second one.
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

  # Composite on the GPU the external display is physically attached to.
  #
  # When a monitor hangs off the dGPU but aquamarine picks the iGPU as its
  # primary renderer, every frame for that output is composited on the iGPU
  # and then copied over PCIe to the dGPU purely to be scanned out, in a
  # linear (untileable) buffer:
  #
  #   drm: gpu /dev/dri/card1 becomes primary drm
  #   GBM: Buffer is marked as multigpu, forcing linear
  #
  # Measured on pod042 at 3840x2160, idle, no game and no video: 2.1-4.4 GB/s
  # inbound to the dGPU against 33 MB per frame, feeding a 144 Hz panel.
  #
  # AQ_DRM_DEVICES reorders that, but it is COLON-separated
  # (CVarList(env, 0, ':', true) in aquamarine's DRM.cpp), so PCI addresses
  # cannot appear in it and /dev/dri/by-path/ names are unusable -- they get
  # shredded mid-address and aquamarine exits with "Found no gpus to use".
  # Bare cardN parses but DRM numbering is not stable across boots. aquamarine
  # canonicalizes each entry with std::filesystem::canonical before matching,
  # so colon-free udev symlinks are both parseable and stable, and that is
  # what these rules provide.
  services.udev.extraRules = lib.mkIf config.gpu.externalMonitorOnDgpu ''
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="${nvidiaAddr}", DRIVERS=="nvidia", SYMLINK+="dri/gpu-nvidia"
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="${intelAddr}", DRIVERS=="i915", SYMLINK+="dri/gpu-intel"
  '';

  # Guarded on purpose rather than set through environment.sessionVariables.
  # If udev has not produced both symlinks, the variable is never exported and
  # aquamarine falls back to its own device ordering -- the slower path, but a
  # working desktop. Setting it unconditionally is what cost generation 431:
  # a bad value does not degrade, it aborts the compositor in initServer and
  # drops the session back to the greeter.
  environment.extraInit = lib.mkIf config.gpu.externalMonitorOnDgpu ''
    if [ -e /dev/dri/gpu-nvidia ] && [ -e /dev/dri/gpu-intel ]; then
      export AQ_DRM_DEVICES=/dev/dri/gpu-nvidia:/dev/dri/gpu-intel
    fi
  '';


  # Hold a graphics-clock floor while the performance profile is selected.
  #
  # The dGPU idles at P8/210MHz against a 3105MHz ceiling. That was tolerable
  # while the iGPU composited the desktop, but this host now renders on the
  # dGPU (see AQ_DRM_DEVICES above), so the P8->P0 ramp on the first input
  # after a pause is felt directly as a hitch.
  #
  # A floor rather than OverrideMaxPerf=0x1: pinning maximum performance holds
  # high clocks on a Max-Q chassis permanently, meaning constant heat and fan
  # noise, and it can provoke thermal throttling under real load. 810MHz is
  # roughly 4x the idle clock and leaves the whole boost range available.
  # PowerMizer* registry keys are not an option -- they stopped working after
  # driver 530 and this host runs 595.
  #
  # Scoped to the performance profile on purpose, so balanced and power-saver
  # behave exactly as before. Event-driven off the profile daemon's own
  # PropertiesChanged signal rather than polled; the signal is only a trigger,
  # and the profile is re-read authoritatively on each one.
  #
  # Known gap: clocks are asserted at boot and on profile change, but not after
  # resume from suspend. If the hitch comes back specifically after a lid
  # cycle, that is why.
  systemd.services.nvidia-clock-floor =
    lib.mkIf (config.gpu.externalMonitorOnDgpu && config.services.power-profiles-daemon.enable) {
      description = "Hold an NVIDIA graphics-clock floor in the performance power profile";
      after       = [ "power-profiles-daemon.service" ];
      wants       = [ "power-profiles-daemon.service" ];
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        Type       = "simple";
        Restart    = "always";
        RestartSec = 5;
      };

      script = let
        smi    = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
        busctl = "${pkgs.systemd}/bin/busctl";
        gdbus  = "${pkgs.glib}/bin/gdbus";
      in ''
        max=$(${smi} --query-gpu=clocks.max.gr --format=csv,noheader,nounits | head -1 | tr -d " ")

        profile() {
          ${busctl} --system get-property net.hadess.PowerProfiles \
            /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile \
            2>/dev/null | cut -d'"' -f2
        }

        apply() {
          if [ "$(profile)" = "performance" ]; then
            ${smi} -lgc ${toString gpuClockFloor},"$max" >/dev/null 2>&1 || true
          else
            ${smi} -rgc >/dev/null 2>&1 || true
          fi
        }

        # Persistence mode stops the clock limits being dropped when the driver
        # has no clients; nvidia-smi warns about exactly this.
        ${smi} -pm 1 >/dev/null 2>&1 || true

        apply
        ${gdbus} monitor --system --dest net.hadess.PowerProfiles \
          --object-path /net/hadess/PowerProfiles | while read -r _; do
            apply
          done
      '';
    };

}
