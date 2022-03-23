{ pkgs ? import ./.nix/nixpkgs.nix
}:
let
  inherit (pkgs) mkShell figlet pack;
in mkShell {

  name = "env";
  buildInputs = [
    figlet
    pack
  ];

  shellHook = ''
    export MESSAGE=Hello
    git clone https://github.com/ludios/nixos-playwright /tmp/nixos-playwright || echo Already cloned
    (cd /tmp/nixos-playwright; git pull)
  '';

}