{ stdenv, pkg-config, fetchurl, xorgproto, testers }: stdenv.mkDerivation (finalAttrs: {
  pname = "lndir";
  version = "1.0.5";
  builder = ./builder.sh;
  src = fetchurl {
    url = "mirror://xorg/individual/util/lndir-1.0.5.tar.xz";
    sha256 = "1nsd23kz6iqxfcis3432zq01i54n98b94m2gcsay1k3mamx5fr9v";
  };
  hardeningDisable = [ "bindnow" "relro" ];
  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ xorgproto ];
  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  meta = {
    pkgConfigModules = [ ];
    platforms = lib.platforms.unix;
  };
})

