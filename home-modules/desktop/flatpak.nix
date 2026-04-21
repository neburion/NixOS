{ ... }:

{
  services.flatpak = {
   enable = true;
   remotes = [{
     name = "flathub";
     location = "https://flathub.org/repo/flathub.flatpakrepo";
   }];
  };
}
