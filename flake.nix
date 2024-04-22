{
  description = "A Nix flake for OSXPhotos";

  inputs = {
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, poetry2nix, ... }:
    let
      inherit (nixpkgs) lib;

      # This example is only using x86_64-linux
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      poetry2nixInstance = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

      bpylist2 = poetry2nixInstance.mkPoetryApplication {
        projectDir = pkgs.fetchFromGitHub {
          owner = "parabolala";
          repo = "bpylist2";
          rev = "ddb89e0b0301c6b298de6469221d99b5fe127b58";
          hash = "sha256-OBwDQZL5++LZgpQM96tmplAh1Pjme3KGSNFTKqKUn00=";
        };
      };

      objexplore = pkgs.python3Packages.buildPythonPackage rec {
        pname = "objexplore";
        version = "1.6.2";
        src = pkgs.fetchFromGitHub {
          owner = "kylepollina";
          repo = pname;
          rev = "3c2196d26e5a873eed0a694cddca66352ea7c81e";
          hash = "sha256-BgeuRRuvbB4p99mwCjNxm3hYEZuGua8x2GdoVssQ7eI=";
        };

        propagatedBuildInputs = with pkgs.python3Packages; [
          blessed
          rich
        ];

        # has tests but they break with an error containing `python3.11: No module named pip`
        doCheck = false;
      };

      rich_theme_manager = poetry2nixInstance.mkPoetryApplication {
        projectDir = pkgs.fetchFromGitHub {
          owner = "RhetTbull";
          repo = "rich_theme_manager";
          rev = "v0.11.0";
          hash = "sha256-nSNG+lWOPmh66I9EmPvWqbeceY/cu+zBpgVlDTNuHc0=";
        };

        overrides = poetry2nixInstance.defaultPoetryOverrides.extend (self: super: {
          inherit (pkgs.python3Packages) pytest-mypy rich;
        });
      };

      strpdatetime = poetry2nixInstance.mkPoetryApplication {
        projectDir = pkgs.fetchFromGitHub {
          owner = "RhetTbull";
          repo = "strpdatetime";
          rev = "17ab99a2f2392ae11b1fb687b239cf3d807730d7";
          hash = "sha256-eb3KJCFRkEt9KEP1gMQYuP50qXqItrexJhKvtJDHl9o=";
        };

        overrides = poetry2nixInstance.overrides.withDefaults (self: super: {
          textx = super.textx.override {
            preferWheel = true;
          };
          mypy = super.mypy.override {
            preferWheel = true;
          };
        });
      };

      osxphotos = pkgs.python3Packages.buildPythonPackage rec {
        pname = "osxphotos";
        version = "0.67.9";
        src = pkgs.fetchgit {
          url = "https://github.com/RhetTbull/osxphotos.git";
          rev = "v${version}";
          sparseCheckout = [
            "/"
            "/osxphotos"
            "!tests" # around 3GB of test data
          ];
          hash = "sha256-yt9Dl7WlrVVbMK6//9BDMORDQhi9xmL1FUVNvK1uTR4=";
        };

        patches = [
          ./ios-path.patch
        ];

        propagatedBuildInputs = with pkgs.python3Packages; [
          bitmath
          bpylist2
          click
          mako
          more-itertools
          objexplore
          packaging
          pathvalidate
          ptpython
          pytimeparse2
          pyyaml
          requests
          rich_theme_manager
          rich
          shortuuid
          strpdatetime
          tenacity
          # textx # nixpkgs has 3.0, osxphotos gets newer from strpdatetime
          toml
          wrapt
          wurlitzer
          xdg-base-dirs
        ] ++ lib.optionals pkgs.stdenv.isDarwin [
          mac-alias
          osxmetadata
          photoscript
          # a bunch of pyobjc packages not in Nixpkgs
        ];

        # has tests but they break with an error containing `python3.11: No module named pip`
        doCheck = false;

        meta = {
          description = "Python app to export pictures and associated metadata from Apple Photos on MacOS.";
          longDescription = ''
          OSXPhotos provides the ability to interact with and query Apple's
          Photos.app library on macOS and Linux. You can query the Photos
          library database — for example, file name, file path, and metadata
          such as keywords/tags, persons/faces, albums, etc. You can also
          easily export both the original and edited photos. OSXPhotos also
          works with iPhoto libraries though some features are available only
          for Photos.
          '';
          homepage = "https://github.com/RhetTbull/osxphotos";
          license = lib.licenses.mit;
          #maintainers = with lib.maintainers; [ axelkar ];
          platforms = lib.platforms.darwin ++ lib.platforms.linux;
          badPlatforms = lib.platforms.darwin; # missing pyobjc dependencies
          changelog = "https://github.com/RhetTbull/osxphotos/blob/v${version}/CHANGELOG.md";
        };
      };

    in
    {
      devShells.x86_64-linux.default =
        pkgs.mkShell {
          packages = [ (pkgs.python3.withPackages (ps: [osxphotos])) ];
        };

      packages.x86_64-linux.bpylist2 = bpylist2;
      packages.x86_64-linux.objexplore = objexplore;
      packages.x86_64-linux.rich_theme_manager = rich_theme_manager;
      packages.x86_64-linux.osxphotos = osxphotos;
      packages.x86_64-linux.default = osxphotos;
    };
}
