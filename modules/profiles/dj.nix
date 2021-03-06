{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.rofa.profiles.dj;
in {
  options.rofa.profiles.dj = {
    enable = mkEnableOption "Mixxx DJ Software";

    mainUser = mkOption {
      default = "dj";
      type = types.str;
      description = ''
        The main user on this system, which is to be logged in automatically.
      '';
    };

    enableRealtimeKernel = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to optimize for a realtime kernel whenever possible.
      '';
    };
  };

  config = mkIf cfg.enable {
    rofa.programs.mixxx.enable = true;
    rofa.programs.mixxx.djUser = cfg.mainUser;

    boot.kernelPackages = let
      rtKernel = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
        extraConfig = ''
          PREEMPT_RT_FULL? y
          PREEMPT y
          IOSCHED_DEADLINE y
          DEFAULT_DEADLINE y
          DEFAULT_IOSCHED "deadline"
          HPET_TIMER y
          CPU_FREQ n
          TREE_RCU_TRACE n
        '';
      }) pkgs.linuxPackages_latest;
    in mkIf cfg.enableRealtimeKernel rtKernel;

    boot.loader.grub.timeout = 0;

    i18n = {
      consoleFont = "lat9w-16";
      consoleKeyMap = "de";
      defaultLocale = "de_DE.UTF-8";
    };

    users.extraUsers.dj = {
      name = cfg.mainUser;
      group = "users";
      uid = 1000;
      createHome = true;
      home = "/home/${cfg.mainUser}";
      shell = "/run/current-system/sw/bin/bash";

      hashedPassword = let
        passwdFile = "/etc/nixos/${cfg.mainUser}.passwd";
        hasPasswdFile = builtins.pathExists passwdFile;
      in if hasPasswdFile then builtins.readFile passwdFile else "";
    };

    users.mutableUsers = false;

    environment.systemPackages = let
      startAndPromptShutdown = pkgs.writeScript "mixxx-autostart.sh" ''
        ${pkgs.stdenv.shell} -e
        ${pkgs.mixxxWrapper}/bin/mixxx -f
        qdbus org.kde.ksmserver /KSMServer \
          org.kde.KSMServerInterface.logout 2 2 4
      '';
      mixxxAutoStart = pkgs.stdenv.mkDerivation {
        name = "mixxx-autostart";
        buildCommand = ''
          mkdir -p "$out/share/autostart"
          sed -e '/^[Ee]xec *=/c Exec=${startAndPromptShutdown}' \
            "${pkgs.mixxxWrapper}/share/applications/mixxx.desktop" \
            > "$out/share/autostart/mixxx.desktop"
        '';
      };
    in [ mixxxAutoStart pkgs.qjackctl ];

    services.xserver.enable = true;
    services.xserver.layout = "de";
    services.xserver.xkbOptions = "eurosign:e";

    services.xserver.displayManager.auto.enable = true;
    services.xserver.displayManager.auto.user = cfg.mainUser;
    services.xserver.desktopManager.kde4.enable = true;

    nixpkgs.config.pulseaudio = false;

    nixpkgs.config.packageOverrides = opkgs: rec {
      portaudio = overrideDerivation opkgs.portaudio (o: {
        preConfigure = (o.preConfigure or "") + ''
          addPkgConfigPath "${jack2}"
        '';
      });

      jack2 = overrideDerivation opkgs.jack2 (o: {
        configurePhase = ''
          python waf configure --prefix=$out --classic --alsa
        '';
      });
    };

    systemd.services.jackd = {
      description = "Jack Audio Server";
      wantedBy = [ "sound.target" ];
      before = [ "sound.target" ];

      serviceConfig = {
        User = cfg.mainUser;
        Group = "audio";
        ExecStart = "${pkgs.jack2}/bin/jackd -R -ddummy -r48000 -p1024";
        LimitRTPRIO = "infinity";
        LimitRTTIME = "infinity";
        LimitMEMLOCK = "infinity";
      };

      restartIfChanged = false;
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="sound", KERNEL=="card*", \
        ATTRS{idProduct}=="07af", ATTRS{idVendor}=="077d" \
        ENV{SYSTEMD_WANTS}="imic@$attr{number}.service"
    '';

    systemd.services."imic@" = {
      description = "iMic card %I";
      requires = [ "jackd.service" ];

      serviceConfig = {
        User = cfg.mainUser;
        Group = "audio";
        ExecStart = let
          amixerCmd = "${pkgs.alsaUtils}/bin/amixer -c%I sset PCM 100%";
          jackCmd = "${pkgs.jack2}/bin/alsa_out -j imic%I -d hw:%I";
        in "${pkgs.stdenv.shell} -c '${amixerCmd}; ${jackCmd}'";
        LimitRTPRIO = "infinity";
        LimitRTTIME = "infinity";
        LimitMEMLOCK = "infinity";
      };
    };
  };
}
