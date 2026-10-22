# Screen reader (Orca) — everything Orca-specific lives here; imported by homeModules.fcaddet, so NixOS and standalone
# home-manager configurations both get it.
#
# How GNOME starts Orca: gnome-settings-daemon's accessibility plugin asks the user's systemd for the unit named
# `orca.service` (StartUnit) whenever org.gnome.desktop.a11y.applications screen-reader-enabled is true, and also ENABLES
# it (EnableUnitFilesWithFlags; StopUnit + DisableUnitFilesWithFlags when it turns off). Only if no such unit can be
# started does it run `orca` from PATH. systemd picks the first `orca.service` in its unit folders, ~/.config/systemd/user
# first, so PATH never decides which Orca runs while some orca.service exists.
{ config, lib, pkgs, ... }:

let
  cfg = config.fcaddet.screenReader;

  # speech-dispatcher's Python module (`speechd`), which Orca needs to speak, is missing from nixpkgs builds after
  # 75f645ed "speechd: stricter deps" (fix: nixpkgs PR #576062). Python is added to the build tools only where it is
  # missing, so this turns into a no-op once nixpkgs carries the fix.
  withPython = drv: drv.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs
      ++ lib.optional (!lib.elem pkgs.python3Packages.python old.nativeBuildInputs) pkgs.python3Packages.python;
  });
  orca = pkgs.orca.override { speechd-minimal = withPython pkgs.speechd-minimal; };
  # The speech server Orca talks to (its own Python part is not needed).
  speechd = pkgs.speechd;
in
{
  options.fcaddet.screenReader.useNixOrca = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Provide Orca and its speech server (speech-dispatcher with espeak-ng) from this configuration, as units in
      ~/.config/systemd/user, the folder systemd reads first: they then win over any Orca the system has. For machines
      whose own Orca is missing or broken and where nothing can be installed system-wide. The login screen always
      uses the system's Orca (it runs as another user).
    '';
  };

  config = lib.mkMerge [
    {
      # GNOME starts Orca whenever this is on.
      dconf.settings."org/gnome/desktop/a11y/applications".screen-reader-enabled = true;

      # Turn the screen reader back on at every login; Super+Alt+S still switches it off for the rest of a session.
      systemd.user.services.screen-reader-on-at-login = {
        Unit.Description = "Turn the screen reader back on at each login";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/a11y/applications/screen-reader-enabled true";
        };
        Install.WantedBy = [ "graphical-session-pre.target" ];
      };

      # GNOME's enable of a unit whose file lives in the Nix store (NixOS's /etc/systemd/user/orca.service, or a
      # home-manager-installed Orca) writes links to that day's store path into ~/.config/systemd/user; the link then
      # overrides the current unit and survives every later update. Remove such links at each activation (every boot
      # on NixOS, every `home-manager switch` standalone); GNOME re-enables the current build at the next login.
      # Runs before checkLinkTargets so a stale link can never block home-manager's own orca.service (useNixOrca);
      # links into home-manager's own files are kept.
      home.activation.forgetPinnedOrca = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        for f in "$HOME/.config/systemd/user/orca.service" \
                 "$HOME/.config/systemd/user/graphical-session.target.wants/orca.service"; do
          if [ -L "$f" ]; then
            case "$(readlink "$f")" in
              *-home-manager-files/*) ;;
              *) run rm -f $VERBOSE_ARG "$f" ;;
            esac
          fi
        done
      '';
    }

    (lib.mkIf cfg.useNixOrca {
      home.packages = [ orca speechd ];
      # The packages' own units (full paths to these builds); Orca's unit pulls in speech-dispatcher.socket.
      xdg.configFile."systemd/user/orca.service".source = "${orca}/share/systemd/user/orca.service";
      xdg.configFile."systemd/user/speech-dispatcher.service".source =
        "${speechd}/share/systemd/user/speech-dispatcher.service";
      xdg.configFile."systemd/user/speech-dispatcher.socket".source =
        "${speechd}/share/systemd/user/speech-dispatcher.socket";
    })
  ];
}
