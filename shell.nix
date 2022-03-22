with import <nixpkgs> {};
mkShell {

  name = "env";
  buildInputs = [
    figlet
  ];

  shellHook = ''
    export MESSAGE=Hello
    git clone https://github.com/ludios/nixos-playwright /tmp/nixos-playwright || echo Already cloned
    (cd /tmp/nixos-playwright; git pull)
  '';

}