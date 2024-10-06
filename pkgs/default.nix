{ lib, noSysDirs, config, overlays }:

final: prev: with final; {

  inherit lib noSysDirs;

  inherit (lib) lowPrio;

  pkgs = final;

  mkReleaseLib = import ../release/lib.nix;

  stdenvNoCC = stdenv.override (
    { cc = null; hasCC = false; }

    // lib.optionalAttrs (stdenv.hostPlatform.isDarwin && (stdenv.hostPlatform != stdenv.buildPlatform)) {
      # TODO: This is a hack to use stdenvNoCC to produce a CF when cross
      # compiling. It's not very sound. The cross stdenv has:
      #   extraBuildInputs = [ targetPackages.darwin.apple_sdks.frameworks.CoreFoundation ]
      # and uses stdenvNoCC. In order to make this not infinitely recursive, we
      # need to exclude this extraBuildInput.
      extraBuildInputs = [];
    }
  );

  autoconf-archive = callPackage ./autoconf-archive { };

  bash = lowPrio (callPackage ./bash/5.nix { });
  # WARNING: this attribute is used by nix-shell so it shouldn't be removed/renamed
  bashInteractive = callPackage ./bash/5.nix {
    interactive = true;
    withDocs = true;
  };
  bashInteractiveFHS = callPackage ./bash/5.nix {
    interactive = true;
    withDocs = true;
    forFHSEnv = true;
  };

  binutils-unwrapped = callPackage ./binutils {
    autoreconfHook = autoreconfHook269;
    # TODO: darwin support
    # inherit (darwin.apple_sdk.frameworks) CoreServices;
    # FHS sys dirs presumably only have stuff for the build platform
    noSysDirs = (stdenv.targetPlatform != stdenv.hostPlatform) || noSysDirs;
  };

  binutils-unwrapped-all-targets = callPackage ../development/tools/misc/binutils {
    autoreconfHook = if targetPlatform.isiOS then autoreconfHook269 else autoreconfHook;
    inherit (darwin.apple_sdk.frameworks) CoreServices;
    # FHS sys dirs presumably only have stuff for the build platform
    noSysDirs = (stdenv.targetPlatform != stdenv.hostPlatform) || noSysDirs;
    withAllTargets = true;
  };
  binutils = wrapBintoolsWith {
    bintools = binutils-unwrapped;
  };
  binutils_nogold = lowPrio (wrapBintoolsWith {
    bintools = binutils-unwrapped.override {
      enableGold = false;
    };
  });
  binutilsNoLibc = wrapBintoolsWith {
    bintools = binutils-unwrapped;
    libc = preLibcCrossHeaders;
  };



  # Here we select the default bintools implementations to be used.  Note when
  # cross compiling these are used not for this stage but the *next* stage.
  # That is why we choose using this stage's target platform / next stage's
  # host platform.
  #
  # Because this is the *next* stages choice, it's a bit non-modular to put
  # here. In theory, bootstraping is supposed to not be a chain but at tree,
  # where each stage supports many "successor" stages, like multiple possible
  # futures. We don't have a better alternative, but with this downside in
  # mind, please be judicious when using this attribute. E.g. for building
  # things in *this* stage you should use probably `stdenv.cc.bintools` (from a
  # default or alternate `stdenv`), at build time, and try not to "force" a
  # specific bintools at runtime at all.
  #
  # In other words, try to only use this in wrappers, and only use those
  # wrappers from the next stage.
  bintools-unwrapped = let
    inherit (stdenv.targetPlatform) linker;
  in     if linker == "lld"     then llvmPackages.bintools-unwrapped
    else if linker == "cctools" then darwin.binutils-unwrapped
    else if linker == "bfd"     then binutils-unwrapped
    else if linker == "gold"    then binutils-unwrapped.override { enableGoldDefault = true; }
    else null;
  bintoolsNoLibc = wrapBintoolsWith {
    bintools = bintools-unwrapped;
    libc = preLibcCrossHeaders;
  };

  bintools = wrapBintoolsWith {
    bintools = bintools-unwrapped;
  };

  bintoolsDualAs = wrapBintoolsWith {
    bintools = darwin.binutilsDualAs-unwrapped;
    wrapGas = true;
  };


  lndir = callPackage ./lndir { };

  acl = callPackage ./acl { };

  attr = callPackage ./attr { };

  autoconf = callPackage ./autoconf { };

  autoconf269 = callPackage ./autoconf/269.nix { };

  automake = callPackage ./automake { };

  autoreconfHook = callPackage (
    { makeSetupHook, autoconf, automake, gettext, libtool }:
    makeSetupHook {
      name = "autoreconf-hook";
      propagatedBuildInputs = [ autoconf automake gettext libtool ];
    } ../build-support/setup-hooks/autoreconf.sh
  ) { };

  autoreconfHook269 = autoreconfHook.override {
    autoconf = autoconf269;
  };

  bison = callPackage ./bison { };

  bzip2 = callPackage ./bzip2 { };

  coreutils = callPackage ./coreutils { };

  dieHook = makeSetupHook {
    name = "die-hook";
  } ../build-support/setup-hooks/die.sh;

  diffutils = callPackage ./diffutils { };

  # Provided by libc on Operating Systems that use the Extensible Linker Format.
  elf-header = if stdenv.hostPlatform.isElf then null else
    throw "Non-elf builds are not supported yet in this stdenv repo";

  expand-response-params = callPackage ../build-support/expand-response-params { };

  expat = callPackage ./expat { };

  fetchFromGitHub = callPackage ../build-support/fetchgithub { };

  fetchpatch = callPackage ../build-support/fetchpatch { };

  file = callPackage ./file { };

  findutils = callPackage ./findutils { };

  flex = callPackage ./flex { };

  gawk = callPackage ./gawk { };

  gnupatch = callPackage ./gnupatch { };

  inherit (callPackage ./gcc/all.nix { })
    gcc6 gcc7 gcc8 gcc9 gcc10 gcc11 gcc12 gcc13 gcc14;

  gcc_latest = gcc14;

  db = db5;
  db5 = db53;
  db53 = callPackage ./db/db-5.3.nix { };

  # TODO: don't use a top-level defined attr to define this
  default-gcc-version =
    if (with stdenv.targetPlatform; isVc4 || libc == "relibc") then 6
    else 13;
  gcc = pkgs.${"gcc${toString default-gcc-version}"};
  gccFun = callPackage ./gcc;
  gcc-unwrapped = gcc.cc;

  gccStdenv = if stdenv.cc.isGNU
    then stdenv
    else stdenv.override {
      cc = buildPackages.gcc;
      allowedRequisites = null;
      # Remove libcxx/libcxxabi, and add clang for AS if on darwin (it uses
      # clang's internal assembler).
      extraBuildInputs = lib.optional stdenv.hostPlatform.isDarwin clang.cc;
    };

  gcc6Stdenv = overrideCC gccStdenv buildPackages.gcc6;
  gcc7Stdenv = overrideCC gccStdenv buildPackages.gcc7;
  gcc8Stdenv = overrideCC gccStdenv buildPackages.gcc8;
  gcc9Stdenv = overrideCC gccStdenv buildPackages.gcc9;
  gcc10Stdenv = overrideCC gccStdenv buildPackages.gcc10;
  gcc11Stdenv = overrideCC gccStdenv buildPackages.gcc11;
  gcc12Stdenv = overrideCC gccStdenv buildPackages.gcc12;
  gcc13Stdenv = overrideCC gccStdenv buildPackages.gcc13;
  gcc14Stdenv = overrideCC gccStdenv buildPackages.gcc14;

  gettext = callPackage ./gettext { };

  glibc = callPackage ./glibc {
    stdenv = gccStdenv; # doesn't compile without gcc
  };

  glibcLocales = callPackage ./glibc/locales.nix { };

  gnu-config = callPackage ./gnu-config { };

  gnugrep = callPackage ./gnugrep { };

  gnulib = callPackage ./gnulib { };

  gnumake = callPackage ./gnumake { };

  gnum4 = callPackage ./gnum4 { };
  m4 = gnum4;

  gnused = callPackage ./gnused { };

  gnutar = callPackage ./gnutar { };

  gmp4 = callPackage ./gmp/4.3.2.nix { }; # required by older GHC versions
  gmp5 = callPackage ./gmp/5.1.x.nix { };
  gmp6 = callPackage ./gmp/6.x.nix { };
  gmp = gmp6;
  gmpxx = gmp.override { cxx = true; };

  gzip = callPackage ./gzip { };

  # TODO: make less messy, islVersions?
  isl = isl_0_20;
  isl_0_11 = callPackage ./isl/0.11.1.nix { };
  isl_0_14 = callPackage ./isl/0.14.1.nix { };
  isl_0_17 = callPackage ./isl/0.17.1.nix { };
  isl_0_20 = callPackage ./isl/0.20.0.nix { };
  isl_0_24 = callPackage ./isl/0.24.0.nix { };



  # We can choose:
  libcCrossChooser = name:
    # libc is hackily often used from the previous stage. This `or`
    # hack fixes the hack, *sigh*.
    /**/ if name == null then null
    else if name == "glibc" then targetPackages.glibcCross or glibcCross
    else if name == "bionic" then targetPackages.bionic or bionic
    else if name == "uclibc" then targetPackages.uclibcCross or uclibcCross
    else if name == "avrlibc" then targetPackages.avrlibcCross or avrlibcCross
    else if name == "newlib" && stdenv.targetPlatform.isMsp430 then targetPackages.msp430NewlibCross or msp430NewlibCross
    else if name == "newlib" && stdenv.targetPlatform.isVc4 then targetPackages.vc4-newlib or vc4-newlib
    else if name == "newlib" && stdenv.targetPlatform.isOr1k then targetPackages.or1k-newlib or or1k-newlib
    else if name == "newlib" then targetPackages.newlibCross or newlibCross
    else if name == "newlib-nano" then targetPackages.newlib-nanoCross or newlib-nanoCross
    else if name == "musl" then targetPackages.muslCross or muslCross
    else if name == "msvcrt" then targetPackages.windows.mingw_w64 or windows.mingw_w64
    else if name == "ucrt" then targetPackages.windows.mingw_w64 or windows.mingw_w64
    else if name == "libSystem" then
      if stdenv.targetPlatform.useiOSPrebuilt
      then targetPackages.darwin.iosSdkPkgs.libraries or darwin.iosSdkPkgs.libraries
      else targetPackages.darwin.LibsystemCross or (throw "don't yet have a `targetPackages.darwin.LibsystemCross for ${stdenv.targetPlatform.config}`")
    else if name == "fblibc" then targetPackages.freebsd.libc or freebsd.libc
    else if name == "oblibc" then targetPackages.openbsd.libc or openbsd.libc
    else if name == "nblibc" then targetPackages.netbsd.libc or netbsd.libc
    else if name == "wasilibc" then targetPackages.wasilibc or wasilibc
    else if name == "relibc" then targetPackages.relibc or relibc
    else throw "Unknown libc ${name}";

  libcCross = assert stdenv.targetPlatform != stdenv.buildPlatform; libcCrossChooser stdenv.targetPlatform.libc;

  libffi = callPackage ./libffi { };
  libffi_3_3 = callPackage ./libffi/3.3.nix { };
  libffiBoot = libffi.override {
    doCheck = false;
  };

  libgcc = stdenv.cc.cc.libgcc or null;

  # GNU libc provides libiconv so systems with glibc don't need to
  # build libiconv separately. Additionally, Apple forked/repackaged
  # libiconv, so build and use the upstream one with a compatible ABI,
  # and BSDs include libiconv in libc.
  #
  # We also provide `libiconvReal`, which will always be a standalone libiconv,
  # just in case you want it regardless of platform.
  libiconv =
    if lib.elem stdenv.hostPlatform.libc [ "glibc" "musl" "nblibc" "wasilibc" "fblibc" ]
      then libcIconv (if stdenv.hostPlatform != stdenv.buildPlatform
        then libcCross
        else stdenv.cc.libc)
    else if stdenv.hostPlatform.isDarwin
      then libiconv-darwin
    else libiconvReal;

  libcIconv = libc: let
    inherit (libc) pname version;
    libcDev = lib.getDev libc;
  in runCommand "${pname}-iconv-${version}" { strictDeps = true; } ''
    mkdir -p $out/include
    ln -sv ${libcDev}/include/iconv.h $out/include
  '';

  libiconvReal = callPackage ../development/libraries/libiconv { };

  iconv =
    if lib.elem stdenv.hostPlatform.libc [ "glibc" "musl" ] then
      lib.getBin stdenv.cc.libc
    else if stdenv.hostPlatform.isDarwin then
      lib.getBin libiconv
    else if stdenv.hostPlatform.isFreeBSD then
      lib.getBin freebsd.iconv
    else
      lib.getBin libiconvReal;

  libidn2 = callPackage ./libidn2 { };

  # On non-GNU systems we need GNU Gettext for libintl.
  libintl = if stdenv.hostPlatform.libc != "glibc" then gettext else null;

  libmpc = callPackage ./libmpc { };

  libtool = callPackage ./libtool/libtool2.nix { };

  libunistring = callPackage ./libunistring { };

  libxcrypt = callPackage ./libxcrypt { };

  inherit (callPackages ../os-specific/linux/kernel-headers { inherit (pkgsBuildBuild) elf-header; })
    linuxHeaders makeLinuxHeaders;

  nix-update-script = lib.error "nix-update-script is not supported yet";

  nukeReferences = callPackage ../build-support/nuke-references { };

    makeWrapper = makeShellWrapper;

  makeShellWrapper = makeSetupHook {
    name = "make-shell-wrapper-hook";
    propagatedBuildInputs = [ dieHook ];
    substitutions = {
      # targetPackages.runtimeShell only exists when pkgs == targetPackages (when targetPackages is not  __raw)
      shell = if targetPackages ? runtimeShell then targetPackages.runtimeShell else throw "makeWrapper/makeShellWrapper must be in nativeBuildInputs";
    };
    passthru = {
      tests = tests.makeWrapper;
    };
  } ../build-support/setup-hooks/make-wrapper.sh;

  mpdecimal = callPackage ./mpdecimal { };

  mpfr = callPackage ./mpfr { };

  minizip = callPackage ./minizip { };

  patch = gnupatch;

  patchelf = callPackage ./patchelf { };

  pcre2 = callPackage ./pcre2 { };

  perlInterpreters = callPackage ./perl { };
  perl = perlInterpreters.perl538;

  pkg-config = callPackage ./pkg-config { };

  pythonInterpreters = callPackage ./python { };
  inherit (pythonInterpreters) python3Minimal;

  # For the purpose of the stdenv repo
  python3 = python3Minimal;

  readline = readline_8_2;
  readline_7_0 = callPackage ./readline/7.0.nix { };
  readline_8_2 = callPackage ./readline/8.2.nix { };

  runtimeShell = "${runtimeShellPackage}${runtimeShellPackage.shellPath}";
  runtimeShellPackage = bash;

  # TODO: stdenv: make this minimal for just stdenv
  # testers = callPackage ../build-support/testers { };
  testers = null;

  texinfoVersions = callPackage ./texinfo/packages.nix { };
  texinfo = texinfoVersions.texinfo7;

  threadsCross =
    lib.optionalAttrs (stdenv.targetPlatform.isMinGW && !(stdenv.targetPlatform.useLLVM or false)) {
      # other possible values: win32 or posix
      model = "mcf";
      # For win32 or posix set this to null
      package = targetPackages.windows.mcfgthreads or windows.mcfgthreads;
    };


  updateAutotoolsGnuConfigScriptsHook = makeSetupHook {
    name = "update-autotools-gnu-config-scripts-hook";
    substitutions = { gnu_config = gnu-config; };
  } ../build-support/setup-hooks/update-autotools-gnu-config-scripts.sh;

  wrapBintoolsWith =
    { bintools
    , libc ? if stdenv.targetPlatform != stdenv.hostPlatform then libcCross else stdenv.cc.libc
    , ...
    } @ extraArgs:
      callPackage ../build-support/bintools-wrapper (let self = {
    nativeTools = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeTools or false;
    nativeLibc = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeLibc or false;
    nativePrefix = stdenv.cc.nativePrefix or "";

    noLibc = (self.libc == null);

    inherit bintools libc;
  } // extraArgs; in self);

  wrapCCWith =
    { cc
    , # This should be the only bintools runtime dep with this sort of logic. The
      # Others should instead delegate to the next stage's choice with
      # `targetPackages.stdenv.cc.bintools`. This one is different just to
      # provide the default choice, avoiding infinite recursion.
      # See the bintools attribute for the logic and reasoning. We need to provide
      # a default here, since eval will hit this function when bootstrapping
      # stdenv where the bintools attribute doesn't exist, but will never actually
      # be evaluated -- callPackage ends up being too eager.
      bintools ? pkgs.bintools
    , libc ? bintools.libc
    , # libc++ from the default LLVM version is bound at the top level, but we
      # want the C++ library to be explicitly chosen by the caller, and null by
      # default.
      libcxx ? null
    , extraPackages ? lib.optional (cc.isGNU or false && stdenv.targetPlatform.isMinGW) threadsCross.package
    , nixSupport ? {}
    , ...
    } @ extraArgs:
      callPackage ../build-support/cc-wrapper (let self = {
    nativeTools = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeTools or false;
    nativeLibc = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeLibc or false;
    nativePrefix = stdenv.cc.nativePrefix or "";
    noLibc = !self.nativeLibc && (self.libc == null);

    isGNU = cc.isGNU or false;
    isClang = cc.isClang or false;
    isArocc = cc.isArocc or false;
    isZig = cc.isZig or false;

    inherit cc bintools libc libcxx extraPackages nixSupport zlib;
  } // extraArgs; in self);

  wrapCC = cc: wrapCCWith {
    inherit cc;
  };

  which = callPackage ./which { };

  xz = callPackage ./xz { };

  zlib = callPackage ./zlib { };

}
