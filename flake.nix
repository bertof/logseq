{
  description = "Minimal flake environment";

  inputs = {
    dotfiles.url = "gitlab:bertof/nix-dotfiles";
    nixpkgs.follows = "dotfiles/nixpkgs-u";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = import inputs.systems;
    imports = [
      # To import a flake module
      # 1. Add foo to inputs
      # 2. Add foo as a parameter to the outputs function
      # 3. Add here: foo.flakeModule
      inputs.pre-commit-hooks-nix.flakeModule
    ];
    perSystem = { config, pkgs, system, lib, self', ... }: {
      # Per-system attributes can be defined here. The self' and inputs'
      # module parameters provide easy access to attributes of the same
      # system.

      # This sets `pkgs` to a nixpkgs with allowUnfree option set.
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-28.3.3"
        ];
      };

      packages = let src = ./.; in {
        logseq = pkgs.mkYarnPackage {
          pname = "logseq";
          version = "master";
          inherit src;
          nativeBuildInputs = with pkgs; [
            fixup-yarn-lock
          ];
          offlineCache = pkgs.fetchYarnDeps {
            yarnLock = src + "/yarn.lock";
            hash = "sha512-EBZunp1gOYqvU6yM1EY+DJUJNSd04SLolbEXaZdWdn8JlF7JW+9rAZG3BOFvAc9cf3kdCHwc/A8aHphTBunnZA==";
          };
          offlineCacheTldraw = pkgs.fetchYarnDeps {
            yarnLock = src + "/tldraw/yarn.lock";
            hash = "sha512-SB2pZm2re7eDnfbiwNyzpXuk+K/8LncUrxyT0WHoAwccZa1kkjzNIbUIioqTSRMjhLMJLyp8W4zfNGtCfHatAA==";
          };
          offlineCacheUi = pkgs.fetchYarnDeps {
            yarnLock = src + "/packages/ui/yarn.lock";
            hash = "sha512-nD1OZt5KPn48F08hvWiiZSQZE2rSJieQl7ZCQQCwYyyoysj8S1bdxrbZkVlIfizgw08r3kqLeSDB3d2fkCFXvQ==";
          };
          offlineCacheAmplify = pkgs.fetchYarnDeps {
            yarnLock = src + "/packages/amplify/yarn.lock";
            hash = "sha512-4iEYtNvx859NhSL6GwjYU+8Q3sZ7OmMM+4CwMX01voUwpFVRIbuqy4AHgC2fQrkiXio6l/D5fHIgecNF1jXGbg==";
          };

          configurePhase = ''
            runHook preConfigure

            # Yarn writes cache directories etc to $HOME.
            export HOME=$TMPDIR

            fixup-yarn-lock yarn.lock
            yarn config --offline set yarn-offline-mirror $offlineCache
            yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress

            pushd tldraw
            fixup-yarn-lock yarn.lock
            yarn config --offline set yarn-offline-mirror $offlineCacheTldraw
            yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
            popd

            pushd packages/ui
            fixup-yarn-lock yarn.lock
            yarn config --offline set yarn-offline-mirror $offlineCacheUi
            yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
            popd

            pushd packages/amplify
            fixup-yarn-lock yarn.lock
            yarn config --offline set yarn-offline-mirror $offlineCacheAmplify
            yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
            popd

            patchShebangs {,packages/ui/,packages/amplify/,tldraw/}node_modules

            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild

            yarn --offline run gulp:build

            # tsc && cd app && yarn --offline run build && cd ..
            #
            # yarn --offline run electron-builder --dir \
            #   -c.electronDist=electron-dist \
            #   -c.electronVersion=${pkgs.electron_28.version}

            runHook postBuild
          '';
        };
      };

      pre-commit.settings.hooks = {
        deadnix.enable = true;
        nixpkgs-fmt.enable = true;
        statix.enable = true;
      };

      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          clojure
          electron_28
          nodePackages.gulp
          nodePackages.postcss
          nodePackages.yarn
          nodejs
          yarn2nix
        ];
        shellHook = ''
          ${config.pre-commit.installationScript}
        '';
      };

      formatter = pkgs.nixpkgs-fmt;
    };
    flake = {
      # The usual flake attributes can be defined here, including system-
      # agnostic ones like nixosModule and system-enumerating ones, although
      # those are more easily expressed in perSystem.
    };
  };
}
