{
  imports = [
    ../../users/neburion
    ../../users/nululy
  ];

  # Fully declarative user management: hashedPassword is enforced on every
  # rebuild (with mutableUsers=true it would only seed new users).
  # Trade-off: imperative `passwd` no longer sticks across rebuilds.
  users.mutableUsers = false;

  # Root has no password; sudo from wheel handles privilege escalation.
  users.users.root.hashedPassword = "!";
}
