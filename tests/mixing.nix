import <nixpkgs/nixos/tests/make-test.nix> ({ pkgs, ... }:

with pkgs.lib;

let
  soundFormats = [ "wav" "ogg" "mp3" "flac" ];
  fileTitles = [ "sine_up" "sine_down" ];

  betterSox = pkgs.sox.override {
    enableLame = true;
  };

  testSounds = pkgs.stdenv.mkDerivation {
    name = "test-sounds";
    buildInputs = singleton betterSox;
    buildCommand = ''
      mkdir -p "$out"
    '' + concatMapStrings (fmt: ''
      sox -n "$out/sine_up.${fmt}"   synth 30 sine 100-100000
      sox -n "$out/sine_down.${fmt}" synth 30 sine 100000-100
    '') soundFormats;
  };

in {
  name = "audio";

  machine = {
    imports = [ ../common.nix ];
    rofa.profiles.dj.enable = true;
    rofa.profiles.dj.enableRealtimeKernel = false;
    rofa.programs.mixxx.reindexOnLaunch = true;
    rofa.programs.mixxx.playlistDir = "/music";
    virtualisation.memorySize = 1024;
    virtualisation.qemu.options = [ "-soundhw hda,hda" ];
    environment.systemPackages = [ pkgs.sqlite ];
    systemd.mounts = singleton {
      wantedBy = [ "multi-user.target" ];
      what = toString testSounds;
      where = "/music";
      options = "bind";
    };
  };

  testScript = let
    databaseFile = "/home/dj/.mixxx/mixxxdb.sqlite";

    windowName = "Mixxx ${pkgs.mixxx.version} x64";

    xdo = name: text: let
      xdoScript = pkgs.writeText "${name}.xdo" text;
    in "${pkgs.xdotool}/bin/xdotool '${xdoScript}'";

    mkDbCheck = title: fmt: let
      specialEscape = s:
        escape ["'" "\\"] "'${replaceChars ["'"] [("'\\'" + "'")] s}'";
      query = "SELECT title FROM library WHERE "
            + "filetype = '${fmt}' AND title = '${title}';";
    in ''
      Machine::retry sub {
        my ($status, $out) = $machine->execute(
          'echo ${specialEscape query} | sqlite3 ${databaseFile}'
        );
        chomp $out;
        return 1 if $status == 0 && $out eq '${title}';
      };
    '';

    checkFormats = title: concatMapStrings (mkDbCheck title) soundFormats;
    checkLibrary = concatMapStrings checkFormats fileTitles;
  in ''
    $ENV{QEMU_AUDIO_DRV} = "wav";
    $ENV{QEMU_WAV_PATH} = cwd() . "/sound.wav";
    $machine->waitForX;

    $machine->nest("waiting for Mixxx to start", sub {
      $machine->waitUntilSucceeds("test -e ${databaseFile}");
      ${checkLibrary}
      $machine->waitUntilSucceeds(
        'test "$(' . (
          q[xwininfo -name "${windowName}"] .
          " | " .
          q[grep '\(Width\|Height\): *[0-9]\{3,\}' | wc -l]
        ) . ')" -eq 2'
      );
      $machine->waitUntilFails("${xdo "wait-until-library-scan-finished" ''
        search --onlyvisible --name "Library Scanner"
      ''}");
      $machine->screenshot("started");
    });

    $machine->execute("${xdo "search-activate-load-decks-and-play" ''
      search --sync --onlyvisible --name "${windowName}"
      windowfocus --sync
      windowactivate --sync
      sleep 1

      key Tab Tab Down Up
      key shift+Left
      sleep 1
      key Down
      key shift+Right
      sleep 1
      key d l
    ''}");

    $machine->sleep(30);

    $machine->screenshot("playing");

    $log->nest("shutting down and generating spectrogram", sub {
      $machine->shutdown;
      system("${betterSox}/bin/sox sound.wav -n spectrogram".
             " -o $ENV{'out'}/spectrogram_main.png");
    }, { image => "spectrogram_main.png" });
  '';
})
