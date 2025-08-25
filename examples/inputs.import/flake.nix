{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  inputs.dried-nix-flakes.url = "github:cyberus-technology/dried-nix-flakes";

  outputs =
    inputs:
    (inputs.dried-nix-flakes.for inputs).exportOutputs (
      { nixpkgs, import /* ➊ */, ... }:

      {
        # Exposes the standard Nix evaluation for this project on `packages`.
        packages =
          import ./default.nix {
            pkgs = nixpkgs.legacyPackages; /* ➋ */
          }
        ;
      }
    )
  ;
}
