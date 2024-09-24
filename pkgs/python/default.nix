{ __splicedPackages
, callPackage
, darwin ? null
, lib
, libffiBoot ? null
, stdenv
# For passthruFun
, config
, makeScopeWithSplicing'
}@args:

assert stdenv.isDarwin -> darwin != null;

(let

  # Common passthru for all Python interpreters.
  passthruFun = import ./passthrufun.nix args;

  sources = {
    python312 = {
      sourceVersion = {
        major = "3";
        minor = "12";
        patch = "4";
        suffix = "";
      };
      hash = "sha256-9tQZpth0OrJnAIAbSQjSbZfouYbhT5XeMbMt4rDnlVQ=";
    };
  };

  python-setup-hook = callPackage ./setup-hook.nix { };

in {

  # Minimal versions of Python (built without optional dependencies)
  python3Minimal = (callPackage ./cpython ({
    self = __splicedPackages.python3Minimal;
    inherit passthruFun python-setup-hook;
    pythonAttr = "python3Minimal";
    # strip down that python version as much as possible
    openssl = null;
    readline = null;
    ncurses = null;
    gdbm = null;
    configd = null;
    sqlite = null;
    tzdata = null;
    libffi = libffiBoot; # without test suite
    stripConfig = true;
    stripIdlelib = true;
    stripTests = true;
    stripTkinter = true;
    rebuildBytecode = false;
    stripBytecode = true;
    includeSiteCustomize = false;
    enableOptimizations = false;
    enableLTO = false;
    mimetypesSupport = false;
  } // sources.python312)).overrideAttrs(old: {
    # TODO(@Artturin): Add this to the main cpython expr
    strictDeps = true;
    pname = "python3-minimal";
  });

})
