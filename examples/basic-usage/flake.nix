{
  description = "A very simple dried-up hello example Flake";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  inputs.dried-nix-flakes.url = "github:cyberus-technology/dried-nix-flakes";

  outputs =
    inputs: # ➊
    
    (inputs.dried-nix-flakes.for /* ➋ */ inputs).exportOutputs (# ➌
      { nixpkgs, ... }:

      {
        packages = {
          inherit (nixpkgs.legacyPackages) # ➍
            hello
          ;
        };
      }
    )
  ;
}
