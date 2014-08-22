{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.rofa.programs.mixxx;

  mixxxConfig = pkgs.substituteAll {
    name = "mixxx.cfg";
    src = ./mixxx.cfg;
    inherit (pkgs) mixxx;
    playlistDir = "/home/${cfg.djUser}";
    recordingsDir = "/home/${cfg.djUser}/Mixxx/Recordings";
  };

  soundConfig = ./soundconfig.xml;

  runMixxx = pkgs.writeScriptBin "mixxx" ''
    #!${pkgs.stdenv.shell}
    mkdir -p "$HOME/.mixxx"
    rm -f "$HOME/.mixxx/soundconfig.xml"
    ln -sf "${mixxxConfig}" "$HOME/.mixxx/mixxx.cfg"
    exec ${pkgs.mixxx}/bin/mixxx -f --settingsPath "$HOME/.mixxx" "$@"
  '';
in {
  options.rofa.programs.mixxx = {
    enable = mkEnableOption "Mixxx DJ Software";

    djUser = mkOption {
      default = "dj";
      type = types.str;
      description = ''
        The username which is the main DJ user and has access to the
        sound devices and a specialized jackd service.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ runMixxx ];

    nixpkgs.config.packageOverrides = opkgs: {
      mixxx = overrideDerivation opkgs.mixxx (o: {
        NIX_CFLAGS_COMPILE = [
          "-I${opkgs.mp4v2}/include" "-L${opkgs.mp4v2}/lib"
          "-I${opkgs.faad2}/include" "-L${opkgs.faad2}/lib"
        ];
        patches = (o.patches or []) ++ [
          ./patches/udisks.patch
          ./patches/imic.patch
        ];
        sconsFlags = o.sconsFlags ++ [ "faad=1" "optimize=8" ];
      });
    };
  };
}
