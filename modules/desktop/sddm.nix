{ pkgs, ... }:

let
  # Custom config: hyprland_kath styling with dynamic wallpaper support.
  # Background points to a shared path updated by sddm-update-wallpaper at runtime.
  nyx-conf = pkgs.writeText "nyx.conf" ''
    [General]
    ScreenWidth=1920
    ScreenHeight=1080
    Font=FiraMono Nerd Font
    FontSize=11
    KeyboardSize=0.4
    RoundCorners=20
    Locale=
    HourFormat=HH:mm
    DateFormat=dddd d
    HeaderText=
    BackgroundPlaceholder=Backgrounds/hyprland_kath.png
    Background=file:///var/cache/sddm-wallpaper/current
    BackgroundSpeed=1.0
    PauseBackground=
    DimBackground=0.0
    CropBackground=true
    BackgroundHorizontalAlignment=center
    BackgroundVerticalAlignment=center
    HeaderTextColor=#b4d8ff
    DateTextColor=#b4d8ff
    TimeTextColor=#b4d8ff
    FormBackgroundColor=#242455
    BackgroundColor=#242455
    DimBackgroundColor=#242455
    LoginFieldBackgroundColor=#111111
    PasswordFieldBackgroundColor=#111111
    LoginFieldTextColor=#b4d8ff
    PasswordFieldTextColor=#b4d8ff
    UserIconColor=#b4d8ff
    PasswordIconColor=#b4d8ff
    PlaceholderTextColor=#bbbbbb
    WarningColor=#b4d8ff
    LoginButtonTextColor=#000055
    LoginButtonBackgroundColor=#b4d8ff
    SystemButtonsIconsColor=#b4d8ff
    SessionButtonTextColor=#b4d8ff
    VirtualKeyboardButtonTextColor=#b4d8ff
    DropdownTextColor=#000055
    DropdownSelectedBackgroundColor=#b4d8ff
    DropdownBackgroundColor=#90b4ff
    HighlightTextColor=#000055
    HighlightBackgroundColor=#b4d8ff
    HighlightBorderColor=transparent
    HoverUserIconColor=#fcfcff
    HoverPasswordIconColor=#fcfcff
    HoverSystemButtonsIconsColor=#fcfcff
    HoverSessionButtonTextColor=#fcfcff
    HoverVirtualKeyboardButtonTextColor=#fcfcff
    PartialBlur=true
    BlurMax=8
    Blur=2.0
    HaveFormBackground=true
    FormPosition=left
    VirtualKeyboardPosition=left
    HideVirtualKeyboard=false
    HideSystemButtons=true
    HideLoginButton=false
    ForceLastUser=true
    PasswordFocus=true
    HideCompletePassword=true
    AllowEmptyPassword=false
    AllowUppercaseLettersInUsernames=false
    BypassSystemButtonsChecks=false
    RightToLeftLayout=false
  '';

  # Standalone SDDM theme: copies sddm-astronaut assets, injects our config.
  nyx-theme = pkgs.stdenvNoCC.mkDerivation {
    name        = "sddm-nyx-theme";
    dontUnpack  = true;
    dontWrapQtApps = true;

    propagatedBuildInputs = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];

    installPhase = ''
      THEME="$out/share/sddm/themes/sddm-nyx-theme"
      SRC="${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme"

      mkdir -p "$THEME"
      cp -r "$SRC"/* "$THEME/"
      chmod -R u+w "$THEME"

      sed -i 's|^Name=.*|Name=sddm-nyx-theme|'       "$THEME/metadata.desktop"
      sed -i 's|^ConfigFile=.*|ConfigFile=Themes/nyx.conf|' "$THEME/metadata.desktop"

      cp ${nyx-conf} "$THEME/Themes/nyx.conf"
    '';
  };
in
{
  services.displayManager.sddm = {
    enable       = true;
    wayland.enable = true;
    theme        = "sddm-nyx-theme";
    extraPackages = with pkgs; [
      nyx-theme
      qt6Packages.qtmultimedia
      qt6Packages.qtsvg
      qt6Packages.qtvirtualkeyboard
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-libav
    ];
  };

  environment.systemPackages = [ nyx-theme ];

  # Shared wallpaper path: world-writable so neburion can update it without sudo.
  # Initialised from hyprland_kath.png on first boot; sddm-update-wallpaper takes over after.
  systemd.tmpfiles.rules = [
    "d /var/cache/sddm-wallpaper 0755 sddm sddm -"
    "C /var/cache/sddm-wallpaper/current 0666 sddm sddm - ${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme/Backgrounds/hyprland_kath.png"
  ];
}
