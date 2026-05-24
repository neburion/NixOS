## Location
The NixOS config lives on the `/home/neburion/NixOS/` location
## Structure
Flake stuff
- flake.nix
- flake.lock (auto generated)
Users/Hosts (module containers)
- hosts/ (each host gets to choose it's configuration.nix modules and a set of users)
- users/ (each user get's to choose it's home manager modules)
Modules
- modules/ (configuration.nix modules)
	- For a list of modules check: [[Modules List]]
- home-modules/ (home manager modules)
	- For a list of modules check: [[Home Module List]]