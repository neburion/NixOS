# Desktop — Fonts

`modules/desktop/fonts.nix`.

```nix
fonts.packages = [ pkgs.nerd-fonts.fira-mono ];
```

Single concern, flat file. Adding more font families: append to the list. Adding a subdir is only justified if you need to opt-in/out specific font sets per host.

`FiraMono Nerd Font` is the everywhere-font: waybar, ghostty, mako, gtk, sddm config all reference it.
