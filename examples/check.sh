#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -eu

PS4=" $ "

# The folder for checks.
this_dir="$(readlink -f "${BASH_SOURCE[0]%/*}")"

export NIX_CONFIG="extra-experimental-features = nix-command flakes"

common_args=(
	--no-write-lock-file
	# Ensures that even if we don't declare the inputs, the example evaluates as expected.
	--override-input nixpkgs "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"
	# Ensures we're using the current state of the repo, not the published version!
	--override-input dried-nix-flakes "git+file://$this_dir/.."
)

cd "$this_dir"
for flake in */flake.nix; do
	flake_dir="$(dirname "$flake")"
	printf "\n\n :: Checking %s\n\n" "$flake"
	(
		set -x
		cd "$flake_dir"
		nix flake check --no-build "${common_args[@]}"
	)
done
