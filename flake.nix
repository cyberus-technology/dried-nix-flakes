{
  description = "Dried Nix Flakes: Pure Nix library to make Flakes usable";
  outputs =
    { self }:
    let
      lib = import ./dried-nix-flakes/lib.nix;
      for = import ./dried-nix-flakes/for.nix;
    in
    lib.deepMergeAttrsList [
      {
        inherit lib;
        inherit for;

        # We're exposing `exportOutputs` for `arg` as this allows even less repetition.
        # With *a bit more magic* this can even be used for mischief by having the `dried-nix-flakes`
        # input named as `__functor`. `{ outputs = input: input ({ ... }: { /* ... */ }) }`
        __functor = _: arg: (for arg).exportOutputs;

        # As a convenience, export `deepMergeAttrsList` as `merge`.
        # Use `merge` to combine different "incompatible" output export schemes together.
        # For example, an un-indexed set (`{ lib = /* ... */; }`) and an indexed set (`exportOutputs ({ ... }: { /* ... */ })`)
        merge = self.lib.deepMergeAttrsList;

        ################################################################################
        #  Checks  #####################################################################
        ################################################################################
        # NOTE: **Must** be free-standing and not rely on any input.
        checks =
          let
            # Fake inputs for our checks.
            checkInputs = {
              some-input = {
                packages = {
                  "ABC-XYZ" = { test = builtins.abort "Invalid access to 'invalid' system type in some-input."; };
                  # NOTE: Must match FALLBACK_SYSTEMS_LIST for proper checks.
                  "x86_64-linux"   = { test = builtins.toFile "check" "success for x86_64-linux\n"; };
                  "aarch64-linux"  = { test = builtins.toFile "check" "success for aarch64-linux\n"; };
                  "x86_64-darwin"  = { test = builtins.toFile "check" "success for x86_64-darwin\n"; };
                  "aarch64-darwin" = { test = builtins.toFile "check" "success for aarch64-darwin\n"; };
                };
              };
              other-input = {
                packages = {
                  # NOTE: only x86_64-linux used by design in these.
                  "x86_64-linux" = { test = builtins.toFile "check" "success for x86_64-linux\n"; };
                  "aarch64-linux"  = builtins.throw "Invalid access to valid output in other-input.";
                  "x86_64-darwin"  = builtins.throw "Invalid access to valid output in other-input.";
                  "aarch64-darwin" = builtins.throw "Invalid access to valid output in other-input.";
                };
              };
            };
          in
          self.merge [
            ((self.for checkInputs).exportOutput (
              { some-input, other-input, currentSystem, builtins, import }:
              {
                # Something self-contained that can be built for a proper end-to-end check.
                success = derivation {
                  name = "success";
                  builder = "/bin/sh";
                  args = [
                    "-c"
                    ''
                      set -x
                      printf 'Reading from input: %s\n' "$input"
                      (
                        while read -r line; do
                          printf '%s\n' "$line"
                        done < "$input"
                        printf "$system"
                      ) > $out
                    ''
                  ];
                  input = some-input.packages.test;
                  system = currentSystem;
                };
              }
            ))
            (((self.for checkInputs).override {
              systems = [ "x86_64-linux" ];
            }).exportOutput (
              { some-input, other-input, currentSystem, builtins, import }:
              {
                limited-systems = derivation {
                  name = "limited-systems";
                  builder = "/bin/sh";
                  args = [
                    "-c"
                    ''
                      set -x
                      printf 'Reading from input: %s\n' "$input"
                      (
                        while read -r line; do
                          printf '%s\n' "$line"
                        done < "$input"
                        printf "$system"
                      ) > $out
                    ''
                  ];
                  input = other-input.packages.test;
                  system = currentSystem;
                };
              }
            ))
          ]
        ;
      }
      # This checks that `exportOutputs` properly keeps `lib` unexpanded.
      ((for {}).exportOutputs (
        { currentSystem, ... }:
        {
          # Using `__internal` to hide this from the exported `lib`.
          # This will get exported.
          lib.__internal = {
            # Returns the value used as input.
            identity = v: v;
          };
          
          checks = {
            purelib = derivation {
              name = "purelib";
              builder = "/bin/sh";
              args = [
                "-c"
                ''
                  set -x
                  printf "%s" "$value" > $out
                ''
              ];
              value = self.lib.__internal.identity "okay";
              system = currentSystem;
            };
          };
        }
      ))
    ];
  }
