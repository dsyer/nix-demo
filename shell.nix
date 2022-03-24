with import (builtins.fetchGit {
  name = "nixos-21.11";
  url = https://github.com/nixos/nixpkgs.git;
  ref = "refs/tags/21.11";
}) { };
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
