let
  lib = import (builtins.fetchGit {
  url = "https://github.com/jonringer/nix-lib.git";
  rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
});
in lib.extend(self: _: {
  systems = import ./systems { lib = self; };

  # Backwards compatibly alias
  platforms = self.systems.doubles;

  # This repo is curated as a set, references to a particular maintainer is
  # likely an error
  maintainers = { };
})
