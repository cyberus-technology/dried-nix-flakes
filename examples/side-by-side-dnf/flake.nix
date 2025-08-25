# A dried-up Flake.
{
  /* inputs */

  outputs =
    { dried-nix-flakes, nixpkgs, ... }@inputs:
 /* ------- */
    
    (inputs.dried-nix-flakes.for inputs).exportOutputs (
 /* --------------------------------------------------- */
      { nixpkgs, ... }:

      {
        packages = {


          inherit (nixpkgs.legacyPackages)
            hello
          ;

        };
      }
    )
  ;
}
