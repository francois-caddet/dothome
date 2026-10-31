# Screen reader (Orca) — everything Orca-specific lives here; imported by homeModules.fcaddet, so NixOS and standalone
# home-manager configurations both get it.
#
# How GNOME starts Orca: gnome-settings-daemon's accessibility plugin asks the user's systemd for the unit named
# `orca.service` (StartUnit) whenever org.gnome.desktop.a11y.applications screen-reader-enabled is true, and also ENABLES
# it (EnableUnitFilesWithFlags; StopUnit + DisableUnitFilesWithFlags when it turns off). Only if no such unit can be
# started does it run `orca` from PATH. systemd picks the first `orca.service` in its unit folders, ~/.config/systemd/user
# first, so PATH never decides which Orca runs while some orca.service exists.
{ config, lib, pkgs, ... }@args:

let
  cfg = config.fcaddet.screenReader;

  # The system's Orca when home-manager runs as a NixOS module (it then passes `osConfig`) and the system has Orca on;
  # null under standalone home-manager.
  systemOrca =
    if args ? osConfig && args.osConfig.services.orca.enable then args.osConfig.services.orca.package else null;

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

  # RHVoice's settings. At Orca's top rate RHVoice speaks max_rate times the voice's normal speed (default 2, about
  # 355 words per minute); it reads RHVoice.conf from the folder RHVOICE_CONFIG_PATH names (engine.cpp, init_params).
  rhvoiceConfig = pkgs.writeTextDir "RHVoice.conf" ''
    max_rate=3
  '';

  # Orca's settings shared by both profiles; voices and names are per profile (orcaProfile). Orca 50 reads every
  # setting from dconf, under /org/gnome/orca/<profile>/ (gsettings_registry.py, get_settings). It reads its older
  # file, ~/.local/share/orca/user-settings.conf, only when dconf holds no Orca key at all (migrate_all, called by
  # orca.py at each start). Values as Orca had written them, 2026-10-31.
  orcaShared = {
    braille = {
      # Orca stores the table's full path; naming the package keeps it valid across liblouis updates.
      contraction-table = "${pkgs.liblouis}/share/liblouis/tables/en-us-g1.ctb";
      link-indicator = "dots78";
      progress-bar-braille-verbosity = "application";
      rolename-style = "verbose";
      selector-indicator = "dots78";
      text-attributes-indicator = "none";
      verbosity-level = "verbose";
    };
    chat = {
      announce-buddy-typing = true;
      message-verbosity = "all";
      room-histories = true;
      speak-room-name = true;
      speak-room-name-last = true;
    };
    document.find-results-verbosity = "all";
    keybindings = {
      # Orca+Shift+Space cycles the profiles: modifiers 257 are Orca (1 << 8) and Shift (1), keybindings.py.
      entries = [
        (lib.hm.gvariant.mkDictionaryEntry [ "cycleSettingsProfileHandler" [ [ "space" "461" "257" "1" ] ] ])
      ];
      keyboard-layout = "desktop";
    };
    say-all.style = "sentence";
    sound.progress-bar-beep-verbosity = "application";
    speech = {
      capitalization-style = "icon";
      progress-bar-speech-verbosity = "application";
      punctuation-level = "most";
      speak-indentation-and-justification = true;
      speech-server = "Speech Dispatcher";
      speech-server-factory = "speechdispatcherfactory";
      verbosity-level = "verbose";
    };
    typing-echo = {
      action-keys = false;
      alphabetic-keys = false;
      function-keys = false;
      key-echo = false;
      modifier-keys = false;
      numeric-keys = false;
      punctuation-keys = false;
      space = false;
      word-echo = true;
    };
  };

  # One Orca profile as dconf settings. `name` is Orca's internal name: Orca finds the profile's folder from it (lower
  # case, "_" turned into "-", sanitize_gsettings_path), and always starts in "default" (get_starting_profile,
  # profile_manager.py). Every voice type gets the profile's voice, family and rate: Orca hands each type's family
  # name to the synthesizer as is, so a type left on an espeak-ng voice names one the synthesizer lacks, and a type
  # with its own rate ignores the default's. `voices` holds each type's other keys.
  orcaProfile = name: { label, synthesizer, voice, voices }:
    let
      dir = "org/gnome/orca/${lib.replaceStrings [ "_" ] [ "-" ] name}";
      sections = orcaShared // {
        metadata = { display-name = label; internal-name = name; };
        speech = orcaShared.speech // { inherit synthesizer; };
      } // lib.mapAttrs' (type: keys: lib.nameValuePair "voices/${type}" (voice // keys)) voices;
    in
    lib.mapAttrs' (section: keys: lib.nameValuePair "${dir}/${section}" keys) sections;
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
      # On NixOS a switch runs the activation only when the home-manager generation changes, so the system's Orca is
      # named in the script: a switch that changes Orca changes the generation too, and the link goes on that switch
      # rather than at the next boot.
      # Runs before checkLinkTargets so a stale link can never block home-manager's own orca.service (useNixOrca);
      # links into home-manager's own files are kept.
      home.activation.forgetPinnedOrca = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
        lib.optionalString (systemOrca != null) ''
          # The system's Orca: ${systemOrca}
        ''
        + ''
          orcaForgotten=
          for orcaLink in "$HOME/.config/systemd/user/orca.service" \
                          "$HOME/.config/systemd/user/graphical-session.target.wants/orca.service"; do
            if [ -L "$orcaLink" ]; then
              orcaTarget=$(readlink "$orcaLink")
              case "$orcaTarget" in
                *-home-manager-files/*) ;;
                *) echo "forgetPinnedOrca: removing $orcaLink -> $orcaTarget"
                   run rm -f $VERBOSE_ARG "$orcaLink"
                   orcaForgotten=1 ;;
              esac
            fi
          done
          # A running user systemd keeps the removed unit loaded until it reloads.
          if [ -n "$orcaForgotten" ]; then
            orcaSystemctl() {
              XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${config.systemd.user.systemctlPath} --user "$@"
            }
            case "$(orcaSystemctl is-system-running 2>&1 || true)" in
              running|degraded) run orcaSystemctl daemon-reload ;;
            esac
            unset -f orcaSystemctl
          fi
          unset orcaForgotten orcaLink orcaTarget
        ''
      );
    }

    # Orca's two profiles: English with RHVoice in Default (the one Orca 50 always starts in), French with MBROLA in
    # default_fr. Nix is the only source of Orca's settings (user's rule, 2026-10-31): each activation (every boot,
    # every switch) erases everything under /org/gnome/orca/, then home-manager writes the keys declared here. A
    # change made in Orca's preferences is temporary: it lasts until the next boot.
    {
      # Runs where home-manager's own dconf step does, and the same way: through a private D-Bus when the activation
      # has no session bus (at boot).
      home.activation.orcaSettingsFromNixOnly = lib.hm.dag.entryBetween [ "dconfSettings" ] [ "installPackages" ] ''
        if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
          run ${pkgs.dconf}/bin/dconf reset -f /org/gnome/orca/
        else
          run ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon \
            ${pkgs.dconf}/bin/dconf reset -f /org/gnome/orca/
        fi
      '';

      # speech-dispatcher's voice modules inherit its environment. A drop-in adds to the system's unit without
      # replacing it.
      xdg.configFile."systemd/user/speech-dispatcher.service.d/rhvoice.conf".text = ''
        [Service]
        Environment=RHVOICE_CONFIG_PATH=${rhvoiceConfig}
      '';
      # speech-dispatcher also loads the modules it finds in ~/.local/libexec/speech-dispatcher-modules, as long as its
      # speechd.conf names none (the system's names none).
      home.file.".local/libexec/speech-dispatcher-modules/sd_rhvoice".source =
        "${pkgs.rhvoice}/libexec/speech-dispatcher-modules/sd_rhvoice";

      dconf.settings = lib.mkMerge [
        # Rate 86: RHVoice at 1 + 0.74 x (3 - 1) = 2.48 times normal speed; on a 40-word test paragraph Slt reads 449
        # words per minute there, against 442 for espeak-ng's klatt6 at Orca 100. Family values as Orca writes them
        # from speech-dispatcher's voice list.
        (orcaProfile "default" {
          label = "Default";
          synthesizer = "rhvoice";
          voice = {
            family-name = "Slt";
            family-lang = "en";
            family-dialect = "";
            family-variant = "none";
            rate = 86;
          };
          voices = {
            default = { established = true; pitch = 5.0; volume = 8.0; };
            uppercase.pitch = 7.0;
            hyperlink.established = false;
            system.established = false;
          };
        })
        # Rate 74: espeak-ng speed 309 for MBROLA fr4, 4.88 s on a 40-word French test paragraph against 4.91 s for
        # espeak-ng's David at Orca 100. Pitch 5.0 is neutral, as fr4 was heard; 7.4 was set for David.
        (orcaProfile "default_fr" {
          label = "default_fr";
          synthesizer = "espeak-ng-mbrola";
          voice = {
            family-name = "french-mbrola-4";
            family-lang = "fr";
            family-dialect = "FR";
            family-variant = "none";
            rate = 74;
          };
          voices = {
            default = { established = true; pitch = 5.0; volume = 8.0; };
            uppercase.pitch = 7.0;
            hyperlink.established = false;
            system = { established = true; pitch = 6.5; };
          };
        })
      ];
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
