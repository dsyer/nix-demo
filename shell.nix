with import <nixpkgs> {
  overlays = import .nix/overlays;
};
mkShell {

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