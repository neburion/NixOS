{ lib, themes, ... }:

let
  # Lua snippet per nvimTheme name. Each must call any required setup() and
  # then `vim.cmd.colorscheme(...)`. Re-sourceable: works as both first-load
  # and live-switch.
  mkSnippet = name: ''
    -- ${name}
    ${ {
      catppuccin = ''
        require('catppuccin').setup { flavour = "mocha", term_colors = true }
        vim.cmd.colorscheme("catppuccin")
      '';
      gruvbox = ''
        require('gruvbox').setup { terminal_colors = true, contrast = "" }
        vim.o.background = "dark"
        vim.cmd.colorscheme("gruvbox")
      '';
      nord = ''
        require('nord').setup { transparent = false, search = "vscode" }
        vim.cmd.colorscheme("nord")
      '';
      everforest = ''
        vim.g.everforest_background = "medium"
        vim.g.everforest_transparent_background = 0
        vim.o.background = "dark"
        vim.cmd.colorscheme("everforest")
      '';
      default = ''
        vim.o.background = "dark"
        vim.cmd.colorscheme("default")
      '';
    }.${name} }
  '';

  # Map palette name → lua snippet, using each palette's `nvimTheme` field.
  themeSnippets = lib.mapAttrs (_: t: mkSnippet t.nvimTheme) themes;
in
{
  # Install all colorscheme plugins (nvf's npins-pinned versions). They sit
  # in the runtime path; the active.lua snippet picks which to load.
  programs.nvf.settings.vim = {
    theme.enable = false;

    startPlugins = [ "catppuccin" "gruvbox" "nord" "everforest" ];

    luaConfigPost = ''
      -- Theme switcher integration
      do
        local active = vim.fn.expand("~/.config/nvf/themes/active.lua")

        local function load_theme()
          if vim.fn.filereadable(active) == 1 then
            pcall(vim.cmd, "luafile " .. vim.fn.fnameescape(active))
          end
        end

        vim.api.nvim_create_user_command("ThemeReload", load_theme, {})

        -- Register a per-PID server socket so the switcher can reach this
        -- instance. Stored in a well-known dir for easy globbing.
        local runtime = vim.env.XDG_RUNTIME_DIR or "/tmp"
        local sock_dir = runtime .. "/nvim-theme"
        vim.fn.mkdir(sock_dir, "p")
        local sock = string.format("%s/%d.sock", sock_dir, vim.fn.getpid())
        pcall(vim.fn.serverstart, sock)
        vim.api.nvim_create_autocmd("VimLeavePre", {
          callback = function() pcall(os.remove, sock) end,
        })

        load_theme()
      end
    '';
  };

  # Per-theme lua snippets, plus initial symlink to dark on first activation.
  xdg.configFile = lib.mapAttrs' (name: snippet:
    lib.nameValuePair "nvf/themes/${name}.lua" { text = snippet; }
  ) themeSnippets;

  home.activation.initNvimTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ACTIVE="$HOME/.config/nvf/themes/active.lua"
    if [ ! -e "$ACTIVE" ]; then
      mkdir -p "$(dirname "$ACTIVE")"
      ln -sf "$HOME/.config/nvf/themes/dark.lua" "$ACTIVE"
    fi
  '';
}
