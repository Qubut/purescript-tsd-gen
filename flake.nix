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
    purescript-tsd-gen = {
      url = "github:minoki/purescript-tsd-gen/purs0.14.x";
      # flake = false;
    };
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, haskell-nix, purescript-tsd-gen, flake-utils, ... }:
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

        versions = with builtins; 
            concatMap (name: 
              let matches = match "stack-purs(.*).yaml" name; in
                if isList matches then matches else []
              )
              (attrNames (readDir purescript-tsd-gen));

        project = version: pkgs.haskell-nix.stackProject' {
          name = "purescript-tsd-gen";
          src = purescript-tsd-gen;
          stackYaml = "stack-purs${version}.yaml";
        };

        project1 = pkgs.haskell-nix.stackProject' {
          name = "purescript-tsd-gen";
          src = purescript-tsd-gen;
          stackYaml = "stack-purs0.14.9.yaml";
        };
        
        sanitiseName = pkgs.lib.stringAsChars (c:
          if c == "."
          then "_"
          else c);

      in {
        apps = builtins.listToAttrs (
            builtins.map (version: {
                name = "purs-tsd-gen-${sanitiseName version}"; 
                value = ((project version).flake {}).apps."purescript-tsd-gen:exe:purs-tsd-gen";
              })
              versions
          );
        inherit sanitiseName;
      }
  );
}
