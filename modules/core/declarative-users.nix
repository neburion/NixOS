{ ... }:

{
  # hashedPassword is enforced on every rebuild
  # (with mutableUsers=true it would only seed new users).
  # Trade-off: imperative `passwd` no longer sticks across rebuilds.
  users.mutableUsers = false;
}
