with import <nixpkgs> { };
let
  nixos-playwright = stdenv.mkDerivation {
    pname = "nixos-playwright";
    version = "0.0.1";
    src = fetchgit {
      url = "https://github.com/ludios/nixos-playwright";
      sha256 = "1yb4dx67x3qxs2842hxhhlqb0knvz6ib2fmws50aid9mzaxbl0w0";
      rev = "fdafd9d4e0e76bac9283c35a81c7c0481a8b1313";
    };
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cd $out/bin && cp $src/* .
    '';
  };
in mkShell {

  name = "env";
  buildInputs = [ figlet nixos-playwright ];

  shellHook = ''
    export MESSAGE=Hello
    figlet $MESSAGE
  '';

}
