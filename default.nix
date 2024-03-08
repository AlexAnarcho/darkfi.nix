{
  pkgs ? import <nixpkgs> {},
  lib,
  ...
}:
with pkgs; let
  source = pkgs.fetchFromGitHub {
    owner = "darkrenaissance";
    repo = "darkfi";
    rev = "master";
    # rev = "ref/tag/v0.4.1";
    hash = "sha256-z1YdEG+E7i2N65u7NljrgQjpLMfDcvU9xGplCQK/vU0=";
  };
in
  stdenv.mkDerivation rec {
    # Declare nix derivation as intentionnaly impure
    # for compatibility with nixos configuration flag  `nix.settings.sandbox=relaxed`
    __noChroot = true;

    name = "darkfi";
    version = source.rev;
    src = source;

    # Skip cmake reconfigure
    dontUseCmakeConfigure = true;
    # Disable tests
    checkType = "debug";
    doCheck = false;

    buildPhase = ''
      export HOME=$(mktemp -d)
      export RUSTUP_USE_CURL=1
      export CARGO_NET_GIT_FETCH_WITH_CLI=true
      rustup toolchain install nightly
      rustup target add wasm32-unknown-unknown
      rustup target add wasm32-unknown-unknown --toolchain nightly
      rustup default nightly
      cargo check
      make
    '';

    nativeBuildInputs = with pkgs; [
      # Nightly toolchains
      llvmPackages.bintools
      rustup
      pkg-config
      sqlcipher
      gnumake
      cmake
      clang
      libclang
      llvm
      git
      openssl
      cacert
      wabt
      jq
    ];

    installPhase = ''
      mkdir -p $out/bin
      find . -type f -executable ! -name "*.*" -exec cp {} $out/bin \;
    '';

    ## Manage toolchain with Rustup instead of nix-store
    ## https://nixos.wiki/wiki/Rust
    RUSTC_VERSION = "nightly";
    # RUSTC_VERSION = builtins.readFile source + "./rust-toolchain.toml";
    LIBCLANG_PATH = pkgs.lib.makeLibraryPath [pkgs.llvmPackages_latest.libclang.lib];
    shellHook = ''
      export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
      export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
    '';
    # Add precompiled library to rustc search path
    RUSTFLAGS = builtins.map (a: ''-L ${a}/lib'') [
      # add libraries here (e.g. pkgs.libvmi)
    ];
    # Add glibc, clang, glib and other headers to bindgen search path
    BINDGEN_EXTRA_CLANG_ARGS =
      # Includes with normal include path
      (builtins.map (a: ''-I"${a}/include"'') [
        # add dev libraries here (e.g. pkgs.libvmi.dev)
        pkgs.glibc.dev
      ])
      # Includes with special directory paths
      ++ [
        ''-I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
        ''-I"${pkgs.glib.dev}/include/glib-2.0"''
        ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
      ];
  }
