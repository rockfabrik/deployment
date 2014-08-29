{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.rofa.programs.mixxx;

  mixxxConfig = pkgs.substituteAll {
    name = "mixxx.cfg";
    src = ./mixxx.cfg;
    inherit (pkgs) mixxx;
    playlistDir = "/music";
    recordingsDir = "/home/${cfg.djUser}/Mixxx/Recordings";
  };

  soundConfig = ./soundconfig.xml;

  runMixxx = pkgs.writeScript "mixxx.sh" ''
    #!${pkgs.stdenv.shell}
    mkdir -p "$HOME/.mixxx"
    rm -f "$HOME/.mixxx/soundconfig.xml"
    ln -sf "${mixxxConfig}" "$HOME/.mixxx/mixxx.cfg"
    exec ${pkgs.mixxx}/bin/mixxx --settingsPath "$HOME/.mixxx" "$@"
  '';

  mixxxWrapper = pkgs.stdenv.mkDerivation {
    name = "mixxx-wrapper-${pkgs.mixxx.version}";
    buildCommand = ''
      mkdir -p "$out/bin" "$out/share/applications" "$out/share/autostart"
      ln -s "${runMixxx}" "$out/bin/mixxx"
      sed -e '/^[Ee]xec *=/c Exec='"$out/bin/mixxx" \
          -e '/^[Ii]con *=/c Icon=${pkgs.mixxx}/share/pixmaps/mixxx-icon.png' \
          "${pkgs.mixxx}/share/applications/mixxx.desktop" \
          > "$out/share/applications/mixxx.desktop"
    '';
  };
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
    environment.systemPackages = [ pkgs.mixxxWrapper ];

    nixpkgs.config.packageOverrides = opkgs: {
      inherit mixxxWrapper;

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
