# Git

`home-modules/cli/git.nix`.

## Git

- `user.name = "neburion"`, `user.email = "neburion@proton.me"`
- `init.defaultBranch = "master"` (note: not "main")
- `pull.rebase = false` — default merge on pull

Identity is hardcoded — every user imports the same config. If nululy starts authoring commits as themselves, this needs to move per-user (in `users/<name>/`).

## gh

GitHub CLI with `git_protocol = "ssh"` and `editor = "nvim"`.

## See also

- [[Home modules/CLI/Fish]] for `mkrepo` / `rmrepo` aliases that use `gh`
