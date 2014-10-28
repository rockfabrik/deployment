with import <nixpkgs/lib>;

{
  machines = mapAttrs (name: configuration: (import <nixpkgs/nixos> {
    inherit configuration;
  }).system) (import ./network.nix);

  tests = {
    mixing = import ./tests/mixing.nix { system = "x86_64-linux"; };
  };
}
