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

  # speech-dispatcher's unit, owned by home-manager where some speech-dispatcher already runs from Nix: the system's
  # build on NixOS (the same file the system links), this configuration's under useNixOrca. A standalone machine
  # with its distribution's speech-dispatcher keeps that one.
  systemSpeechd =
    if args ? osConfig && args.osConfig.services.speechd.enable then args.osConfig.services.speechd.package else null;
  ownSpeechdUnit = systemSpeechd != null || cfg.useNixOrca;
  ownedSpeechd = if systemSpeechd != null && !cfg.useNixOrca then systemSpeechd else speechd;

  # speech-dispatcher's English symbol rules, with the decimal point left to the voice. speech-dispatcher rewrites
  # punctuation itself (SymbolsPreproc "char" in the system's speechd.conf); its rule "decimal point" has an empty
  # replacement, and symbols.c puts a space before a replacement, so "5.5" reached the voice as "5 .5", which RHVoice
  # reads "five five". The rule now replaces the dot with itself, "literal" (no space added): "5.5" stays "5.5" and
  # each voice reads its own decimals ("five point five"). Not "-": that marks the replacement as unspecified, and it
  # is then inherited from the "base" locale's file, empty again (speech_symbols_processor_new). Traced in a private
  # speech-dispatcher's debug log, 2026-10-31: "Version 2.0.1 costs 3.14" kept every decimal dot, other dots as
  # before. speech-dispatcher reads this file from ~/.config/speech-dispatcher/locale/en before the system's. The
  # build fails if the rule ever changes.
  speechdSymbolsEn = pkgs.runCommand "speechd-symbols-en.dic" { } ''
    cp ${ownedSpeechd}/share/speech-dispatcher/locale/en/symbols.dic $out
    chmod u+w $out
    substituteInPlace $out --replace-fail $'decimal point\t\tnone\talways' $'decimal point\t.\tnone\tliteral'
  '';

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

  # Orca's volume for every voice type: 2.35 sends speech-dispatcher 0 (Orca sends int(15 x volume - 35)), each
  # synthesizer's own normal level. Above it RHVoice turns on a fast limiter (hts_engine_call.cpp) that roughens the
  # voice, and espeak-ng with MBROLA clips (amplitude = 100 + the value): at Orca's 8.0, fr4 had 4,375 clipped
  # samples in 107,661, against 45 at normal. Heard 2026-10-31: Bdl at 8.0 matched Orca, at normal it was cleaner.
  # Orca's own default is 10.0, the maximum, so no voice type is left without it.
  orcaNormalVolume = 2.35;

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

      # speech-dispatcher's voice modules inherit its environment, and it reads that environment and looks for modules
      # only when it starts. home-manager's switch tool (sd-switch) restarts a running unit when its unit file or a
      # drop-in beside it changes, but only for a unit whose file is in home-manager's own folder
      # (find_unit_file_path, then collect_overrides): hence the owned unit below, with its restart triggers.
      xdg.configFile."systemd/user/speech-dispatcher.service.d/rhvoice.conf".text = ''
        [Service]
        Environment=RHVOICE_CONFIG_PATH=${rhvoiceConfig}
      '';
      # speech-dispatcher also loads the modules it finds in ~/.local/libexec/speech-dispatcher-modules, as long as its
      # speechd.conf names none (the system's names none).
      home.file.".local/libexec/speech-dispatcher-modules/sd_rhvoice".source =
        "${pkgs.rhvoice}/libexec/speech-dispatcher-modules/sd_rhvoice";

      dconf.settings = lib.mkMerge [
        # Bdl at rate 80 and pitch 5.5, chosen by ear (2026-10-31). Rate 80 sends 62 to speech-dispatcher: RHVoice at
        # 1 + 0.62 x (3 - 1) = 2.24 times normal speed. Pitch 5.5 sends 20: 1.2 times the voice's own pitch. Family
        # values as Orca writes them from speech-dispatcher's voice list.
        (orcaProfile "default" {
          label = "Default";
          synthesizer = "rhvoice";
          voice = {
            family-name = "Bdl";
            family-lang = "en";
            family-dialect = "";
            family-variant = "none";
            rate = 80;
            volume = orcaNormalVolume;
          };
          voices = {
            default = { established = true; pitch = 5.5; };
            # Chosen by ear (2026-10-31): at 7.0 some capitals, like P and B, were not heard as higher. Orca caps the
            # pitch it sends at 9 (speechdispatcherfactory.py, _set_pitch), so this is the maximum: 1.9 times Bdl's.
            uppercase.pitch = 10.0;
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
            volume = orcaNormalVolume;
          };
          voices = {
            default = { established = true; pitch = 5.0; };
            uppercase.pitch = 7.0;
            hyperlink.established = false;
            system = { established = true; pitch = 6.5; };
          };
        })
      ];
    }

    # speech-dispatcher's unit under the same name: ~/.config/systemd/user comes before /etc/systemd/user, and drop-ins
    # from both folders still apply. Rewritten at each activation, so it follows every update of the build it names.
    (lib.mkIf ownSpeechdUnit {
      xdg.configFile."systemd/user/speech-dispatcher.service".source =
        "${ownedSpeechd}/lib/systemd/user/speech-dispatcher.service";
      xdg.configFile."speech-dispatcher/locale/en/symbols.dic".source = speechdSymbolsEn;
      # What speech-dispatcher loads only at start and its unit does not name: the RHVoice module (through the link
      # below) and the symbol file. One key in one drop-in: sd-switch merges drop-ins key by key, the later file
      # replacing the earlier (SystemdIni::extend), so the same key in two drop-ins would hide one. systemd ignores
      # X- keys.
      xdg.configFile."systemd/user/speech-dispatcher.service.d/restart-triggers.conf".text = ''
        [Unit]
        X-Restart-Triggers=${pkgs.rhvoice} ${speechdSymbolsEn}
      '';
    })

    (lib.mkIf cfg.useNixOrca {
      home.packages = [ orca speechd ];
      # The packages' own units (full paths to these builds); Orca's unit pulls in speech-dispatcher.socket. The
      # speech-dispatcher service comes from the block above.
      xdg.configFile."systemd/user/orca.service".source = "${orca}/share/systemd/user/orca.service";
      xdg.configFile."systemd/user/speech-dispatcher.socket".source =
        "${speechd}/share/systemd/user/speech-dispatcher.socket";
    })
  ];
}
