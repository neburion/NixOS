# Art

`home-modules/desktop/art/default.nix`.

```nix
home.packages = [ aseprite blender ];
```

Pre-existing subdir from before the reorg. Single default.nix with two packages. Kept as a subdir (not flattened) because:
1. Existing pattern the user kept
2. Subdir leaves room for art-specific config in the future (palettes, brushes, etc.)
