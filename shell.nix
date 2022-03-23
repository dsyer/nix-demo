{ pkgs ? import ./.nix/nixpkgs.nix
}:
let
  inherit (pkgs) mkShell figlet pack nixos-playwright;
in mkShell {

  name = "env";
  buildInputs = [
    figlet
    pack
    nixos-playwright
  ];

  shellHook = ''
    export MESSAGE=Hello
    figlet $MESSAGE
  '';

}