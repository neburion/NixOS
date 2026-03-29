{ ... }:

{
  virtualisation.waydroid.enable = true;

  system.activationScripts.waydroid-gpu-fix = ''
    mkdir -p /var/lib/waydroid
    echo "ro.hardware.gralloc=default" > /var/lib/waydroid/waydroid_base.prop
    echo "ro.hardware.egl=swiftshader" >> /var/lib/waydroid/waydroid_base.prop
  '';
}
