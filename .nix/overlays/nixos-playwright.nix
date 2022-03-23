self: super: {

  nixos-playwright = super.stdenv.mkDerivation {
    pname = "nixos-playwright";
    version = "0.0.1";
    src = super.fetchgit {
      url =
        "https://github.com/ludios/nixos-playwright";
      sha256 = "1yb4dx67x3qxs2842hxhhlqb0knvz6ib2fmws50aid9mzaxbl0w0";
    };
    phases = [ "installPhase" ];
    buildPhase = ''
      echo "Nothing here"
    '';
    installPhase = ''
      mkdir -p $out/bin
      cd $out/bin && cp $src/* .
    '';
  };

}
