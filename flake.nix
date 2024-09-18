{
  description = "A purescript-tsd-gen package, see https://github.com/minoki/purescript-tsd-gen.";

  nixConfig = {
    # This sets the flake to use the IOG nix cache.
    # Nix should ask for permission before using it,
    # but remove it here if you do not want it to.
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    allow-import-from-derivation = "true";
  };

  inputs = {
    purescript-tsd-gen-14 = {
      url = "github:minoki/purescript-tsd-gen/purs0.14.x";
      # flake = false;
    };
    purescript-tsd-gen-15 = {
      url = "github:minoki/purescript-tsd-gen/purs0.15.x";
      # flake = false;
    };
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, haskell-nix, purescript-tsd-gen-14, purescript-tsd-gen-15, flake-utils, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
      flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ haskell-nix.overlay ] ;
          inherit (haskell-nix) config; 
        };

        versions14 = with builtins; 
            concatMap (name: 
              let matches = match "stack-purs(.*).yaml" name; in
                if isList matches then matches else []
              )
              (attrNames (readDir purescript-tsd-gen-14));

        versions15 = with builtins; 
            concatMap (name: 
              let matches = match "stack-purs(.*).yaml" name; in
                if isList matches then matches else []
              )
              (attrNames (readDir purescript-tsd-gen-15));

        project14 = version: pkgs.haskell-nix.stackProject' {
          name = "purescript-tsd-gen";
          src = purescript-tsd-gen-14;
          stackYaml = "stack-purs${version}.yaml";
        };

        project15 = version: pkgs.haskell-nix.stackProject' {
          name = "purescript-tsd-gen";
          src = purescript-tsd-gen-15;
          stackYaml = "stack-purs${version}.yaml";
        };

        sanitiseName = pkgs.lib.stringAsChars (c:
          if c == "."
          then "_"
          else c);

        makePackages = getAttr: versions: project: builtins.listToAttrs (
          builtins.map (version: {
              name = "purs-tsd-gen-${sanitiseName version}"; 
              value = (getAttr ((project version).flake {}))."purescript-tsd-gen:exe:purs-tsd-gen";
            })
            versions
        );

      in {
        # i.e. nix run .\#purs-tsd-gen-0_14_9
        apps = makePackages (flake: flake.apps) versions14 project14 // makePackages (flake: flake.apps) versions15 project15;
        # i.e. nix build .\#purs-tsd-gen-0_14_9
        packages = makePackages (flake: flake.packages) versions14 project14 // makePackages (flake: flake.packages) versions15 project15;
      }
  );
}
