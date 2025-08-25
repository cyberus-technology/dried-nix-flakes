# SPDX-License-Identifier: Apache-2.0

{ pkgs ? import <nixpkgs> {} }:

{
  # CI checks.
  examples-checks = pkgs.callPackage ./support/nix/run-checks.nix {};
}
