# Tips and Tricks with Nix Shell

[Nix](https://nixos.org/download.html#download-nix) is a great way to get stable, reproducible package management, without needing to pollute your OS with multiple dependencies. It downloads and manages everything it needs in `/nix/store` (plus a few dotfiles in your home directory), and you can remove that stuff any time you want. You can also have multiple environments with different versions of various tools. For example you can use it to prepare an environment for working on a project with its own dependencies and requirements. There is more than one way to do that, but we like to use `nix-shell` and this sample is an introduction to that very useful tool, and shows you how to set up some configuration for it so you can control the environment.

- [Tips and Tricks with Nix Shell](#tips-and-tricks-with-nix-shell)
  - [Getting Started](#getting-started)
  - [Finding a Package](#finding-a-package)
  - [Configuring Nix Shell](#configuring-nix-shell)
  - [More Packages](#more-packages)
  - [Adding New Packages](#adding-new-packages)
  - [Prefetch](#prefetch)
  - [Modifying Existing Packages](#modifying-existing-packages)
    - [Downloading a Binary Package](#downloading-a-binary-package)
    - [Overlays: Overriding a GNU Package](#overlays-overriding-a-gnu-package)
    - [Overlays: Overriding a Go Package](#overlays-overriding-a-go-package)
    - [Discovering the Hashes](#discovering-the-hashes)
    - [Overriding Python](#overriding-python)
  - [Modular Nix](#modular-nix)
  - [Immutable Environment](#immutable-environment)
  - [Nix in Docker](#nix-in-docker)

## Getting Started

Suppose that you don't have GNU `hello` installed already (most people don't):

```
$ hello
bash: hello: command not found
```

Nix has a package for that:

```
$ nix-shell -p hello
... downloads and installs a load of things ...
nix:$ hello
Hello, world!
```

You just installed a new package and set up some symlinks so that `hello` is now magically on your `PATH`. You can do that with anything that Nix already knows about, and that is a vast collection of tools and utilities: https://github.com/NixOS/nixpkgs.

## Finding a Package

It can be a bit hard to find the package that you need, but a bit of searching and grepping in `~/.nix-defexpr/channels/nixpkgs` will usually find what you need. Or you can use `nix-env`:

```
$ nix-env -qa 'hello.*'
hello-2.9
hello-wayland-unstable-2020-07-27
```

It can be hard to disentangle the package name from the search results. There is also a utility called `nix search` but it needs to build a huge index and ends up being too slow for casual usage.

## Configuring Nix Shell

In an empty directory, create a file called `shell.nix` and put `hello` in the `buildInputs`:

```nix
with import <nixpkgs> { };
mkShell {
  name = "env";
  buildInputs = [
   hello
  ];
}
```

* The function `mkShell` is defined in `nixpkgs`. It is passed 2 named arguments `name` and `buildInputs`.
* The name "env" is arbitrary; it identifies this shell and its dependencies.
* The `buildInputs` are a list of packages (derivations) defined in `nixpkgs`.

With that in place you can forget that you have to remember the package name:

```
$ nix-shell
nix:$ hello
Hello World!
```

The `mkShell` function has other optional arguments. You can add a hook to source some shell commands, e.g. to set up environment variables:

```nix
with import <nixpkgs> { };
mkShell {
  name = "env";
  buildInputs = [
    hello
  ];
  shellHook = ''
    export MESSAGE='Hi There'
  '';
}
```

Now the shell has an environment variable called `MESSAGE`:

```
$ nix-shell
nix:$ hello --g="$MESSAGE"
Hi There
```

Nix is a language, so you can edit the source files with the IDE of your choice. There are quite a few options. I use VSCode with https://github.com/bbenoist/vscode-nix.

## More Packages

A list in `nix` is whitespace separated, so if you want more packages they just go next to `hello`, or on a new line. Example:

```nix
with import <nixpkgs> { };
mkShell {
  name = "env";
  buildInputs = [
    hello
    figlet
  ];
  shellHook = ''
    export MESSAGE='Hi There'
  '';
}
```

and then

```
$ nix-shell
nix:$ figlet $MESSAGE
 _   _ _   _____ _                   
| | | (_) |_   _| |__   ___ _ __ ___ 
| |_| | |   | | | '_ \ / _ \ '__/ _ \
|  _  | |   | | | | | |  __/ | |  __/
|_| |_|_|   |_| |_| |_|\___|_|  \___|
```

You can add as many packages there as you need to build up the environment for your project. Some common packages that I use: `kubectl`, `kind`, `skaffold`, `kustomize`, `nodejs`, `python3`, `cmake`, `protobuf`.

## Adding New Packages

Some packages don't exist in Nix - it's a large open source community so most things you need will be there, but not if it's new or a bit of a niche. It's better to get it from there if you can because there are caches and it saves toil, but it can happen that you want to install something new. You can do that by adding a package to the defaults. As an example suppose that you want to install the utility scripts at https://github.com/ludios/nixos-playwright. So modify the `shell.nix`:

```nix
with import <nixpkgs> { };
let
  nixos-playwright = stdenv.mkDerivation { ... };
in mkShell {
  name = "env";
  buildInputs = [
    hello
    figlet
    nixos-playwright
  ];
  shellHook = ''
    export MESSAGE='Hi There'
  '';
}
```

What we added was a "namespace" for the `mkShell` using `let ... in`. All variables defined in the `let` can be used in the body and we used ours in the `buildInputs` by trivially referring to its identifier `nixos-playwright`. The `...` in the prologue is a placeholder for a "derivation" - a recipe for a new package. Nix comes with a built in `mkDerivation` which we are using as a convenience. It does a bunch of stuff including if we need them configuring, building and installing software from standard GNU-style source code repositories. 

For the `nixos-playwright` package we just need to clone a git repository and copy the scripts to our path. There is no build and no additional toolchain so we don't really need all of the machinery that `mkDerivation` brings with it, but that's OK, we can configure it to just do what we need:

```nix
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
```

There's quite a bit to unpack there.

* `pname` is the formal package name. It can be different to the variable name we use in the script but it doesn't hurt to call it the same thing.
* `version` is a label. We made this one up because there are no releases of this code, just a repository with scripts.
* `src` is an instruction for where to find the source code. We want to clone it from Github, so we use `fetchgit`. There are other `fetch` utilities that youc an use to download a tarball or zipfile, for instance.
* The argument for `src` is a see of key-value pairs. The definition of `fetchgit` is here: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/fetchgit/default.nix. Only the `url` is mandatory, but it is helpful to be able to specify a `branchName` or `rev` (reference) and a `sha256` to ensure stability
* `phases` by default is a long list of things to do to build a package. We only need one step so we choose `installPhase`.
* `installPhase` is the definition of that phase as a shell script. In it we create a new `bin` directory and copy the scripts from our source code.


## Prefetch

The `sha256` in the recipe above is a hash of the source code after it has been cloned. Everything is immutable in Nix and this is enforced through hashes of source code. To install or override a package from an external source you need the hashes, so Nix provides some utilities to help discover them, and also cache the source code locally. The build will break if the hash code changes which is useful. If it breaks it will tell you what value it expected and what it saw instead. You can copy-paste that value from the error message. Or you can use `nix-prefect-git` to download the source code ahead of time and inspect the metadata:

```
$ nix-shell -p nix-prefetch-git
nix:$ nix-prefetch-git https://github.com/ludios/nixos-playwright
Initialized empty Git repository in /run/user/1000/git-checkout-tmp-B2uEQUzd/nixos-playwright/.git/
remote: Enumerating objects: 8, done.
remote: Counting objects: 100% (8/8), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 8 (delta 1), reused 1 (delta 0), pack-reused 0
Unpacking objects: 100% (8/8), 2.93 KiB | 999.00 KiB/s, done.
From https://github.com/ludios/nixos-playwright
 * branch            HEAD       -> FETCH_HEAD
Switched to a new branch 'fetchgit'
removing `.git'...

git revision is fdafd9d4e0e76bac9283c35a81c7c0481a8b1313
path is /nix/store/rb0ai329w84433pgaqf5sp7s7ns1b4db-nixos-playwright
git human-readable version is -- none --
Commit date is 2022-03-16 08:35:24 -0700
hash is 1yb4dx67x3qxs2842hxhhlqb0knvz6ib2fmws50aid9mzaxbl0w0
{
  "url": "https://github.com/ludios/nixos-playwright",
  "rev": "fdafd9d4e0e76bac9283c35a81c7c0481a8b1313",
  "date": "2022-03-16T08:35:24-07:00",
  "path": "/nix/store/rb0ai329w84433pgaqf5sp7s7ns1b4db-nixos-playwright",
  "sha256": "1yb4dx67x3qxs2842hxhhlqb0knvz6ib2fmws50aid9mzaxbl0w0",
  "fetchLFS": false,
  "fetchSubmodules": false,
  "deepClone": false,
  "leaveDotGit": false
}
```

There are other prefect utilities, each corresponding to a `fetch-*` that you can do to create the `src` for a derivation:

```
$ nix-env -qa 'nix-prefetch.*'
nix-prefetch-0.4.1
nix-prefetch-bzr
nix-prefetch-cvs
nix-prefetch-docker
nix-prefetch-git
nix-prefetch-github-5.0.1
nix-prefetch-hg
nix-prefetch-scripts
nix-prefetch-svn
```

The plain `nix-prefetch` package has `nix-prefetch-url` for example, which you can use to download a tarball before using it in a derivation with `fetchurl`. The `nix-prefetch-scripts` package covers all the source code control options in one place (`bzr`, `cvs`, `git`, `hg`, `svn`).

## Modifying Existing Packages

Supposeyou like the existing package for a tool that you want to use, but you need a different version or something.

### Downloading a Binary Package

You could use the same mechanism as above to simply replace the package with our own manual derivation. For example, you can install the `pack` CLI:

```nix
with import <nixpkgs> { };
let
  buildpack = stdenv.mkDerivation {
    pname = "buildpack";
    version = "0.23.0";
    src = super.fetchurl {
      # nix-prefetch-url this URL to find the hash value
      url =
        "https://github.com/buildpacks/pack/releases/download/v0.23.0/pack-v0.23.0-linux.tgz";
      sha256 = "1vkm0fbk66k8bi5pf4hkmq7929y5av3lh0xj3wpapj2fry18j9yi";
    };
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cd $out/bin && tar -zxf $src
    '';
  };

in mkShell {
  name = "env";
  buildInputs = [
    buildpack
  ];
}
```

It works:

```
$ nix-shell
these derivations will be built:
  /nix/store/sfqx1wf2vwda28ch9p7j4rafa3jrdm09-pack-0.23.0.drv
building '/nix/store/sfqx1wf2vwda28ch9p7j4rafa3jrdm09-pack-0.23.0.drv'...
installing
nix:$ pack version
0.23.0+git-0db2c77.build-3056
```

but that would be more work than necessary and it would miss all the hard work that the existing package already has behind it. The standard package for `pack` also builds it from source and links statically to all the libraries it needs. It is better to re-use the existing derivation if you can because downloading pre-built binaries can fail if they end up in an environment which doesn't have the right shared libraries (e.g. Alpine Linux or NixOS). It is better to use an overlay.

There is already a `buildpack` package in Nix, so this works:

```nix
with import <nixpkgs> { };
mkShell {
  name = "env";
  buildInputs = [
    buildpack
  ];
}
```

A more idiomatic way of overriding an existing package is to define an "overlay". Overlays are an argument (default empty) to the `import <nixpkgs>` so the same example with explicitly empty overlays is:

```nix
with import <nixpkgs> {
  overlays = [
  ];
};
mkShell {
  name = "env";
  buildInputs = [
    buildpack
  ];
}
```

Let's have a look at how to define a couple of overlays.

### Overlays: Overriding a GNU Package

A package that is built with the standard GNU toolchain is usually straighforward to overlay. You can override some of the properties of existing packages by adding expressions to the overlays. Example `shell.nix`:

```nix
with import <nixpkgs> {
  overlays = [
    (self: super: {
      hello = super.hello.overrideAttrs(oldAttrs: rec {
        version = "2.9";
        src = self.fetchurl {
            url = "mirror://gnu/hello/${super.hello.pname}-${version}.tar.gz";
            sha256 = "19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc";        
        };
      });
    })
  ];
};
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
```

The only slightly hard thing there was the hash, which you can find using `nix-prefetch-url`:

```
$ nix-shell -p nix-prefetch --command 'nix-prefetch-url mirror://gnu/hello/hello-2.9.tar.gz'
[0.7 MiB DL]
path is '/nix/store/xdilnlzvvsf7r33gs4vy9jq2bmazlc0j-hello-2.9.tar.gz'
19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc
```

To verify the result:

```
$ nix-shell
nix:$ hello --version
hello (GNU Hello) 2.9
...
```

### Overlays: Overriding a Go Package

Packages built with `buildGoModule` are tricky to override. Let's try and do a better job of overriding the `pack` CLI, downgrading to version 0.22.0:

```nix
with import <nixpkgs> {
  overlays = [
    (self: super: {
      buildpack = let
          version = "0.22.0";
          src = super.fetchFromGitHub {
            owner = "buildpacks";
            repo = "pack";
            rev = "v${version}";
            sha256 = "1wxqrh88yg0jlrsxdjiih64vqf4jm88fx9cp2i9c71x7gcf6mlkm";
          };
      in (super.buildpack.override {
          buildGoModule = args: super.buildGoModule (args // {
          vendorSha256 = "1rr2d014dqjqjl8njvsms9wh21xb4xlzrjrd164ykzjm2k5m2xiy";
          ldflags = [ "-s" "-w" "-X github.com/buildpacks/pack.Version=${version}" ];
          inherit src version;
        });
      });
    })
  ];
};
mkShell {
  name = "env";
  buildInputs = [ buildpack ];
}
```

It was hard to craft that override. The worst thing was the vendor hash (see below). Also the `ldflags` have to be set if you don't want `pack` to report the wrong (not overridden) version, and the only way to find that out is to read the [source code](https://github.com/nixos/nixpkgs/blob/master/pkgs/development/tools/buildpack/default.nix) in `nixpkgs`.

### Discovering the Hashes

Grab some prefetch utilities:

```
$ nix-shell -p nix-prefetch-git nix-prefetch
```

We saw above how to find the hash for a simple `fetchurl`. Example:

```
nix:$ nix-prefetch-url mirror://gnu/hello/hello-2.9.tar.gz
...
19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc
```

This works for to main source hash:

```
nix:$ nix-prefetch-git --url https://github.com/buildpacks/pack --rev v0.22.0
...
{
  "url": "https://github.com/buildpacks/pack",
  "rev": "26d8c5c5607933c6d0738f3c37370c87d2e134f1",
  "date": "2021-11-08T09:05:38-06:00",
  "path": "/nix/store/sw470kma6xbwcd4n57kjv6bb49z9kad1-pack",
  "sha256": "1wxqrh88yg0jlrsxdjiih64vqf4jm88fx9cp2i9c71x7gcf6mlkm",
  "fetchLFS": false,
  "fetchSubmodules": false,
  "deepClone": false,
  "leaveDotGit": false
}
```

The vendor hash is harder, Here's one attempt (after extracting the overlay into a separate file `buildpack.nix`):

```
nix:$ nix-prefetch "{ sha256 }: with import <nixpkgs> { overlays = [(import ./buildpack.nix)]; }; buildpack.go-modules.overrideAttrs (_: {vendorSha256 = sha256; })"
...
sha256-PnZRyxRV/umJCS3L/GknqwcBedJVb2kRlVjiRgJoIuc=
```

It failed with the overlay but got a useful error:

```
hash mismatch in fixed-output derivation '/nix/store/hpv8lr0jrlimsncvp0fzfjx4dlxai7kf-pack-0.22.0-go-modules':
  wanted: sha256:04i7mxai6a1qcsj7w3bf47i5kd9bj6r4y8aydmasjhwpnpgfv1cq
  got:    sha256:1rr2d014dqjqjl8njvsms9wh21xb4xlzrjrd164ykzjm2k5m2xiy
cannot build derivation '/nix/store/z16ffs56xk6w297bfkfs8y6nvsrnvviy-pack-0.22.0.drv': 1 dependencies couldn't be built
```

So replacing the vendor hash with `1rr...` works in our `shell.nix` example above.

### Overriding Python

Python has a lot of modules, some binary, that it likes to store globally. Dynamically downloading additional modules with `pip` is quite a common idiom for developers, but it isn't idiomatic in Nix because it is mutable state and there are no Nix hashes for the dynamic modules. Sometimes life is too short, or you need a Python module that isn't included in `nixpkgs`. In those cases you can hack a bit and create a virtual Python environment locally, so at least the mutable state is all in the local directory. Here is an example installing a wheel (module) called `wasmtime` that isn't included in Nix natively:

```nix
with import <nixpkgs> { };
mkShell {

  name = "env";
  buildInputs = [
    python3Packages.python
    python3Packages.venvShellHook
    wasmtime wabt emscripten nodejs cmake check
  ];

  venvDir = "./.venv";
  postVenvCreation = ''
    unset SOURCE_DATE_EPOCH
    pip install wasmtime
  '';

  postShellHook = ''
    # allow pip to install wheels
    unset SOURCE_DATE_EPOCH
  '';

}
```

It creates a `.venv` directory locally if it doesn't exist, and `pip` will use that to install additional modules.

## Modular Nix

We saw the `import` function a few times, mainly at the start of `shell.nix`:

```nix
with import <nixpkgs> { };
mkShell {
...
}
```

`<nixpkgs>` is the global set of packages that was downloaded when you installed Nix. The `<>` placeholder tells Nix to search the `NIX_PATH` for a directory called `nixpkgs`.

```
$ echo $NIX_PATH
/home/dsyer/.nix-defexpr/channels
$ ls /home/dsyer/.nix-defexpr/channels
manifest.nix  nixpkgs
```

`NIX_PATH` can be a list of directories separated with the usual path separator, but in this case it is just one.

You can also import a local file or directory having a `default.nix`, or a URL if it has a `default.nix` at the root. The result of an import is a Nix expression. So `import <nixpkgs>` loads the content of `default.nix` from that directory and evaluates it. In this case it evaluates to a function definition so you have to provide arguments: `{}` are empty arguments, which we have seen already can contain key value pairs, according to the definition. The function in this case has a large number of arguments, all of which have default values, so empty is OK.

You could extract our overlays out into a separate file, or files. For example in `shell.nix`:

```nix
with import <nixpkgs> {
  overlays = [
    (import ./hello.nix)
  ];
};
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
```

and `hello.nix`:

```nix
self: super: {
  hello = super.hello.overrideAttrs(oldAttrs: rec {
    version = "2.9";
    src = self.fetchurl {
        url = "mirror://gnu/hello/${super.hello.pname}-${version}.tar.gz";
        sha256 = "19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc";
    };
  });
}
```

Or you could collect all the overlays together with `shell.nix` like this:

```nix
with import <nixpkgs> {
  overlays = (import ./overlays.nix);
};
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
```

and `overlays.nix` evaluates to a list:

```nix
[
  (import ./hello.nix)
]
```

Because of the way `import` works, you could also move those scripts into a subdirectory `overlays`, rename `overlays.nix` as `default.nix` and import the directory:

```nix
with import <nixpkgs> {
  overlays = (import ./overlays);
};
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
```

## Immutable Environment

Usually we are more than happy to just use `import <nixpkgs>` as the source of packages for `nix-shell`. It uses the `NIX_PATH` to locate the package definitions, but the contents of that path might change from time to time, and from machine to machine. If you want cast iron guarantees that everyone who downloads your `shell.nix` gets exactly the same result, you need to pin the source of `nixpkgs`. You can do that by importing a specific version:

```nix
with import (builtins.fetchGit {
  name = "nixos-21.11";
  url = https://github.com/nixos/nixpkgs.git;
  ref = "refs/tags/21.11";
}) { };
mkShell {
  name = "env";
  buildInputs = [ hello ];
}
```

It takes a *long* time to start a shell the first time (`nixpkgs` is a lot of repository to clone). You get the reproducible immutability at the cost of everyone having wait for the `nixpkgs` to be downloaded.

## Nix in Docker

If you want to try it out and can't or don't want to install Nix, or if you want to use Nix in a remote or CI environment, it can be useful to pack it into a Docker image. This works:

```Dockerfile
ARG VARIANT="focal"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
   && apt-get -y install --no-install-recommends xz-utils

USER vscode

RUN curl -L https://nixos.org/nix/install | sh
```

It's the default `Dockerfile` for a `.devcontainer` from [VSCode Remote Containers](https://github.com/Microsoft/vscode-remote-release) with 2 additions: the `xz-utils` and the `curl ... | sh`.

You can run that container in VSCode just by running the command (`CTRL-SHIFT P`) "Remote Containers: Open Folder in Container". It also works in Codespaces if you have access.

More generally you need an Ubuntu base image with a non-root user with `sudo` access.