{ pkgs, ... }:

let
  my-python-packages = ps: with ps; let
    pick = buildPythonPackage rec {
      pname = "pick";
      version = "1.6.0";
      pyproject = true;
      build-system = [ setuptools poetry-core ];
      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-Kv1GyJtQIxHTuDHs7hoA6Kv4kq1elubLr5PxcrKa4cU=";
      };
      doCheck = false;
    };
  in [
  # ...
  (
    buildPythonPackage rec {
      pname = "qobuz-dl";
      version = "0.9.9.10";
      pyproject = true;
      build-system = [ setuptools ];
      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-q7TUl3scg+isoLB0xJvJLCtvJU7O+ogMlftt0O73qb4=";
      };
      doCheck = false;
      propagatedBuildInputs = [
        # Specify dependencies
        pathvalidate
        requests
        mutagen
        pick
        tqdm
        beautifulsoup4
        colorama
      ];
    }
    )
  ];
in
  {
    accounts.email.accounts.gmail = {
      primary = true;
      thunderbird.enable = true;
      realName = "François CADDET";
      address = "francois.caddet@gmail.com";
      flavor  = "gmail.com";
      notmuch.enable = true;
      lieer.enable = true;
      lieer.sync.enable = true;
    };

    programs.notmuch.enable = true;
    programs.lieer.enable = true;

  # Installed packages
  home.packages = with pkgs; [
    authenticator
    rustc
    rustfmt
    cargo
    rust-analyzer
    cachix
    libreoffice
    karere
    (python3.withPackages my-python-packages)
  ];

  programs.texlive.enable = true;
  programs.pandoc.enable = true;

  programs.zsh.enable = true;

  programs.starship = {
    enableZshIntegration = true;
  };

  programs.atuin = {
    enableZshIntegration = true;
  };

  # set dark theme
  gtk = {
    enable = true;

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    theme = {
      name = "palenight";
      package = pkgs.palenight-theme;
    };

    cursorTheme = {
      name = "Numix-Cursor";
      package = pkgs.numix-cursor-theme;
    };

    gtk3.extraConfig = {
      Settings = ''
      gtk-application-prefer-dark-theme=1
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
      gtk-application-prefer-dark-theme=1
      '';
    };
  };

  home.sessionVariables.GTK_THEME = "palenight";
  home.sessionVariables.QT_QPA_PLATFORM = "wayland";

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
