let
  lib = import (builtins.fetchGit {
  url = "https://github.com/jonringer/nix-lib.git";
  rev = "9ec8ccc745ea8d3e767e2d4db4f62b03aea11135";
});
in lib.extend(self: _: {
  systems = import ./systems { lib = self; };
})
