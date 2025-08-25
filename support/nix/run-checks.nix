# SPDX-License-Identifier: Apache-2.0
{ pkgs
, runCommand
, nix-gitignore
, nix
}:

let
  nixpkgs =
    # This ensures we don't copy over `/nix/store/{new_hash}-{orig_hash}-source`.
    builtins.path {
      name = "source";
      path = pkgs.path;
    }
  ;
in

# Runs checks for CI purposes.
runCommand "dried-nix-flakes-checks" {
  dried_nix_flakes = nix-gitignore.gitignoreSource [] ../..;
  nativeBuildInputs = [
    nix
  ];
} ''
  register_path() {
    local path="$1"; shift
    # Those details don't need to be accurate for this temporary store.
    hash="sha256:0000000000000000000000000000000000000000000000000000"
    size="0"
    refs="0"
    printf "%s\n%s\n%d\n\n%d\n" "$path" "$hash" "$size" "$refs" \
      | nix-store --load-db
  }

  export NIX_STATE_DIR=$TMPDIR/nix/state
  export HOME="$PWD/home"
  PS4=" $ "
  # Copy the project over
  cp --no-preserve=ownership -r "$dried_nix_flakes" dried-nix-flakes
  chmod -R +w dried-nix-flakes
  patchShebangs dried-nix-flakes

  cd dried-nix-flakes

  nix-build --version

  # Patch a replacement `nixpkgs`.
  substituteInPlace examples/check.sh --replace-fail \
    "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz" \
    "${nixpkgs}" \
    --replace-fail "git+file://" ""

  # Force the path to "exist" in the store by registering it.
  # Otherwise Nix will try to edit the builder's store!
  register_path "${nixpkgs}"

  # Then run the checks.
  (
  set -x
  examples/check.sh
  ) |& tee $out
''
