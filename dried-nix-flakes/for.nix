let
  lib = import ./lib.nix;

  # Safe-enough list of systems.
  # Limit this list known-well-supported Nixpkgs systems.
  # I.e. systems where Nix is easy to get useful results out of.
  # This is **very likely** not used in practice, as the utility functions
  # instead rely on the input `nixpkgs` for the exposed outputs, when feasible.
  # When not feasible, either this is sufficient, or the user has specific needs,
  # and they should build their own systems list using `override`.
  # This is an implementation detail and not exposed.
  FALLBACK_SYSTEMS_LIST = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
in
{
  # List of Flake output attributes that will be flattened down to the current system.
  # This list includes the common default expectations.
  # When an attribute gains enough conventional usage in the broader ecosystem,
  # it can be added here with citation about the provenance.
  indexedOutputs = [
    # All output names using `checkSystemName` in Lix's Flakes support.
    # https://git.lix.systems/lix-project/lix/src/tag/2.93.0/lix/nix/flake.cc#L605-L795
    "checks"
    "formatter"
    "packages" "devShells"
    "apps"
    "legacyPackages"
    "bundlers"
    # Deprecated, but indexed by system names.
    "defaultPackage" "devShell"
    "defaultApp"
    "defaultBundler"
  ];

  # List of outputs where access to any `indexedOutputs` is forbidden (by us).
  # It's more strict than the default Flakes semantics, but not mandatory.
  # These only affect outputs in `exportOutputs`.
  outputListWithoutSystemRefs = [
    "lib"
    "nixosModule"
    "nixosModules"
    "overlay"
    "overlays"
  ];

  makeImportScope =
    system:
    let
      scope = {
        builtins = builtins // {
          import = scope.import;
          currentSystem = system;
        };
        import = 
          builtins.scopedImport scope
        ;
      };
    in
      scope
  ;

  # Exposes a sort of "constructor" that takes in *only* the inputs from the Flake using this.
  # Why not directly a function, and instead as a functor?
  # Because it might be helpful to access some of the fields or customize the set beforehand.
  __functor =
    initialSelf: inputs:
    let
      self = initialSelf // {
        systems =
          if initialSelf ? systems
          then initialSelf.systems
          else
            # Automatically try to get Nixpkgs's exposed systems if possible.
            let inherit (self) inputs; in
            if
              (inputs ? nixpkgs)
              && (inputs.nixpkgs ? lib)
              && (inputs.nixpkgs.lib ? systems)
              && (inputs.nixpkgs.lib.systems ? flakeExposed)
            then inputs.nixpkgs.lib.systems.flakeExposed
            else FALLBACK_SYSTEMS_LIST
        ;

        inherit inputs;

        # Returns the given inputs with their indexedOutputs's system attribute sets hoisted down as a direct descendent.
        # nixpkgs.legacyPackages.${currentSystem}.${...} -> nixpkgs.legacyPackages.${...}
        collapseSystemsDown =
          inputs: currentSystem:
          let
            indexedOutputs = lib.toLookupTable self.indexedOutputs;
          in
          lib.mapAttrValues
          (
            inputName: inputOutputs:
            lib.mapAttrValues
            (
              outputName: outputValues:
              if indexedOutputs ? ${outputName}
              then outputValues.${currentSystem}
              else outputValues
            )
            inputOutputs
          )
          inputs
        ;

        # As a convenience, export `deepMergeAttrsList` as `merge` here too.
        merge = lib.deepMergeAttrsList;

        makeInputs =
          currentSystem:
          (self.collapseSystemsDown self.inputs currentSystem) // {
            inherit currentSystem;
            inherit (self.makeImportScope currentSystem)
              builtins
              import
            ;
          }
        ;

        # Exports a single "output attribute" for all systems.
        exportOutput =
          output:
          lib.genAttrs
          (
            currentSystem:
            output
            (self.makeInputs currentSystem)
          )
          self.systems
        ;

        # Exports the given outputs injecting the system types on all root-level elements attribute sets.
        #
        # NOTE: This ***necessarily*** always indexes all elements at the root.
        # The inputs have been collapsed down to a single system, so referring to `package.something` would
        # produce a `package.${system}.something`, meaning it logically needs to be indexed by the same system.
        exportOutputs =
          outputs:
          let
            # The outputs with the `currentSystem` applied, but with the systems in front of the output names.
            # {
            #   "x86_64-linux" = {
            #      "packages" = { /* ... */ };
            #   };
            # }
            systemsThenOutputs =
              self.exportOutput outputs
            ;

            # The full list of known outputs from all systems.
            exportedOutputs =
              lib.uniqLossy
              (
                builtins.concatLists
                (
                  builtins.map
                  builtins.attrNames
                  (builtins.attrValues systemsThenOutputs)
                )
              )
            ;

            # All outputs at the root are expanded to their per-systems form.
            # Yes, including those outputsWithoutSystems!
            # Thanks to laziness, we can *just* handle that next.
            outputsWithSystems =
              lib.genAttrs
              # From the output names list...
              (
                outputName:
                lib.mapAttrValues
                # Pick the output name for the given system.
                (_: outputs: outputs.${outputName})
                systemsThenOutputs
              )
              exportedOutputs
            ;

            # *Only* handle the outputs that are listed as being "without system refs".
            # This is how we get e.g. `lib` working as expected.
            outputsWithoutSystems =
              lib.genAttrs
              (
                outputName:
                (
                  outputs
                  (
                    self.makeInputs 
                    (
                      # Thanks to laziness, we can just put this instead of a real system string, and... it works!
                      builtins.throw "Access to `currentSystem` is not allowed in `dried-nix-flakes.exportOutputs` on output `${outputName}`."
                    )
                  )
                ).${outputName}
              )
              (lib.uniqLossyIntersect self.outputListWithoutSystemRefs exportedOutputs)
            ;
          in
            outputsWithSystems // outputsWithoutSystems
        ;

        # Public interface to improve composition of the data fields of this helper library.
        # The argument names are the correct interface to override or augment values for systems and "indexed" outputs.
        override =
          { systems ? self.systems
          , extraSystems ? []
          , indexedOutputs ? self.indexedOutputs
          , extraIndexedOutputs ? []
          , outputsWithoutSystems ? self.outputListWithoutSystemRefs
          , extraOutputsWithoutSystems ? []
          }@values:
          (
            self // values // {
              systems = systems ++ extraSystems;
              indexedOutputs = indexedOutputs ++ extraIndexedOutputs;
              outputListWithoutSystemRefs = outputsWithoutSystems ++ extraOutputsWithoutSystems;
            }
          ) self.inputs
        ;
      };
    in
      {
        inherit (self)
          __functor
          exportOutput
          exportOutputs
          merge
          override
        ;
      }
  ;
}
