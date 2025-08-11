{ pkgs, ... }:

{
#  imports = [
#    nixneovim.nixosModules.default
#  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    diagnostic.settings = {
      virtual_text = true;
    };

    extraPackages = with pkgs; [
      yarn
      nodejs
      python3
    ];

    # usePluginDefaults = true;
    plugins = {
      mini.enable = true;

      # Icons
      mini.modules.icons = {};
      mini.mockDevIcons = true;
# cmp
#blink-cmp.enable = true;
mini.modules.completion = {};
      mini.modules.snippets = {
        snippets = [
          "gen_loader.from_lang()"
        ];
      };

      # display possible keys
      which-key.enable = true;

      # markdown
      markdown-preview.enable = true;

      # notes typing
      zk.enable = true;

      # nix
      nix.enable = true;

      # git helpers
      diffview.enable = true;
      fugitive.enable = true;
      #neogit.enable = true;
      #git-messenger.enable = true;
      # gitgutter.enable = true;
      # or maybe thisone?
      #gitsigns.enable = true;

      # manage budgets and transacions with hledger
      #ledger.enable = true;

      telescope.enable = true;

      todo-comments.enable = true;

      # diagnostics definitions and and quick fix listing
      trouble.enable = true;
    };
    plugins.lsp-signature.enable = true;
    #plugins.lspkind.enable = true;
    # Buggy with screenreader:
     #plugins.lspsaga.enable = true;

    plugins.lsp.enable = true;
    plugins.lsp.servers = {
      bashls.enable = true;
      clangd.enable = true;
      ltex.enable = true;
      nixd = {
        enable = true;
        settings.formatting.command = [ "nixpkgs-fmt" ];
      };
      pyright.enable = true;
      #rust_analyzer.enable = true;
      texlab.enable = true;
      gopls.enable = true;
      elixirls.enable = true;
    };
    plugins.treesitter = {
      enable = true;
      settings.indent.enable = true;
      settings.auto_install = true;
    };
      plugins.luasnip.enable = true;

    # debug
    plugins.dap = {
      enable = true;
    };
    plugins.dap-ui.enable = true;
    plugins.dap-virtual-text.enable = true;

    # rust
    plugins.rustaceanvim = {
      enable = true;
    };

    # file manager
    plugins.oil.enable = true;
  };
}
