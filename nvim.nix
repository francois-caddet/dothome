{ pkgs, nixneovim, ... }:

{
  imports = [
    nixneovim.nixosModules.default
  ];

  programs.nixneovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      yarn
      nodejs
    ];

    # usePluginDefaults = true;
    plugins = {
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

      # autoclose unedited buffs
      hbac.enable = true;

      # manage budgets and transacions with hledger
      ledger.enable = true;

      telescope.enable = true;

      todo-comments.enable = true;

      # diagnostics definitions and and quick fix listing
      trouble.enable = true;
    };
    plugins.lsp-signature.enable = true;
    plugins.lspkind.enable = true;
    # plugins.lspsiga.enable = true;
    plugins.lspconfig.servers = {
      bashls.enable = true;
      clangd.enable = true;
      ltex.enable = true;
      nil.enable = true;
      pyright.enable = true;
      rust-analyzer.enable = true;
      texlab.enable = true;
      gopls.enable = true;
    };
    plugins.treesitter = {
      enable = true;
      indent = true;
      installAllGrammars = true;
    };
    plugins.nvim-cmp = {
      enable = true;
      snippet.luasnip.enable = true;

      sources = {
        treesitter.enable = true;
        nvim_lsp.enable = true;
        luasnip.enable = true;
      };
      mappingPresets = [ "insert" "cmdline" ];
    };

    # debug
    plugins.nvim-dap = {
      enable = true;
    };
    plugins.nvim-dap-ui.enable = true;

    # rust
    plugins.rust-tools = {
      enable = true;
    };

    # file manager
    plugins.oil.enable = true;
    plugins.project-nvim = {
      enable = true;
    };
  };
};
