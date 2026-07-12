{ lib, ... }:

{
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
}
