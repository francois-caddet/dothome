{ lib, pkgs, ... }:
{
home.shellAliases = {
tunnelRabbit="ssh -N -L 5672:127.0.0.1:5672 linux@164.30.72.223";
tunnelPostgres="ssh -N -L 5432:127.0.0.1:5432 linux@164.30.72.223";
tunnelMongo="ssh -N -L 27017:127.0.0.1:27017 linux@164.30.72.223";
tunnelTemporal="ssh -N -L 7233:127.0.0.1:7233 linux@164.30.72.223";
tunnelRedis="ssh -N -L 6379:127.0.0.1:6379 linux@164.30.72.223";
tunnelSpiceDB="ssh -N -L 50052:127.0.0.1:50052 linux@164.30.72.223";
    tunnelsCybee = lib.strings.concatStringsSep " " [
      "ssh -N"
      "-L 5672:127.0.0.1:5672"
      "-L 5432:127.0.0.1:5432"
      "-L 27017:127.0.0.1:27017"
      "-L 7233:127.0.0.1:7233"
      "-L 6379:127.0.0.1:6379"
      "-L 50052:127.0.0.1:50052"
      "linux@164.30.72.223"
    ];
sshCybee="ssh linux@164.30.72.223";
};

  programs.bash = {
    enable = true;
    initExtra = ''
    . "${pkgs.asdf-vm}/share/asdf-vm/asdf.sh"
    . "${pkgs.asdf-vm}/share/asdf-vm/completions/asdf.bash"
    '';
  };

  programs.starship = {
    enableBashIntegration = true;
  };
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  programs.atuin = {
    enableBashIntegration = true;
  };

  programs.iamb = {
    enable = true;
    settings = {
      profiles.perso.user_id = "@francois-caddet:matrix.org";
    };
  };

  home.packages = with pkgs; [
    asdf-vm
    #erlang
    #elixir
  ];
}
