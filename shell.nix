with import <nixpkgs> { };
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
