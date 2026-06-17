{ ... }:

{
  # Root has no password; sudo from wheel handles privilege escalation.
  users.users.root.hashedPassword = "!";
}
