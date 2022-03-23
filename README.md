# Tips and Tricks with Nix Shell

[Nix](https://nixos.org/download.html#download-nix) is a great way to get stable, reproducible package management, without needing to pollute your OS with multiple dependencies. It downloads and manages everything it needs in `/nix/store` (plus a few dotfiles in your home directory), and you can remove that stuff any time you want. You can also have multiple environments with different versions of various tools. And you can use it to prepare an environment for working on a project with its own dependencies and requirements. There is more than one way to do that, but we like to use `nix-shell` and this sample is an introduction to that very useful tool, and shows you how to set up some configuration for it so you can control the environment.

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

We just installed a new package and set up some symlinks so that `hello` is now magically on your `PATH`. You can do that with anything that Nix already knows about, and that is a vast collection of tools and utilities: https://github.com/NixOS/nixpkgs.

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

With that in place you can forget that you have to remember the package name:

```
$ nix-shell
nix:$ hello
Hello World!
```

You can add a hook to set up environment variables or whatever:

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

so now the shell has an environment variable called `MESSAGE`:

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

Some packages don't exist in Nix - it's a large open source community so most things you need will be there, but not if it's new or a bit of a niche. It's better to get it from there if you can because there are caches and it saves toil, but it can happen that you want to install something new. We can do that by adding a package to the defaults. As an example suppose that we want to install the utility scripts at https://github.com/ludios/nixos-playwright. So we modify the `shell.nix`:

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

What we added was a "namespace" for the `mkShell` using `let ... in`. All variables defined in the `let` can be used in the body and we used ours in the `buildInputs` by trivially referring to its identifier `nixos-playwright`. The `...` in the prologue is a "derivation" - a recipe for a new package. Nix comes with a built in `mkDerivation` which we are using as a convenience. It does a bunch of stuff, including if we need it configuring, building and installing software from standard GNU-style source code repositories. 

For the `nixos-playwright` package we just need to clone a git repository and copy the scripts to our path. There is no build and no additional toolchain so we don't really need all of the machinery that `mkDerivation` brings with it, but that's OK, we can configure it to just do what we need:

```nix
nixos-playwright = stdenv.kDerivation {
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

The `sha256` in the recipe above is a hash of the source code after it has been cloned. The build will break if the hash code changes which is useful. If it breaks it will tell you what value it expected and what it saw instead. If you just want the "latest" you can copy paste that value and carry on. Or you can use `nix-prefect-git` to download the source code ahead of time and inspect the metadata:

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

The plain `nix-prefetch` package has `nix-prefetch-url` for example, which you can use to download a tarball before using it in a derivation with `fetchurl`.