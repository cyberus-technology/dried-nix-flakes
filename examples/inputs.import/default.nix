# NOTE: angled-bracket syntax used as an example to represent any preferred input management scheme.
{ pkgs ? import <nixpkgs> {} }:

{
  hello = pkgs.hello;
}
