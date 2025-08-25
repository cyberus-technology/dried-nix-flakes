Dried Nix Flakes
================

> Flakes, but *DRY*er.

* * *

What's this?
------------

This is a pure Nix library handling the worst parts of having to deal with Flakes:
The lack of `builtins.currentSystem` or similar semantics.

It does so while respecting the intent behind the design.


How?
----

It does so in different ways.

First, by collapsing and then expanding the systems-indexed attribute sets from inputs and outputs with a convenience function.
This enables a `flake.nix` expression to implicitly use and export all systems that *by default and by convention* should.

Then, this also exposes some useful helpers to further help.
For example, `builtins.currentSystem` ***from a Flake*** will in imported expressions when using the `import` function exposed by this Flake's export functions.


### Basic Usage

```nix
{
  description = "A very simple dried-up hello example Flake";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  inputs.dried-nix-flakes.url = "github:cyberus-technology/dried-nix-flakes";
  outputs =
    inputs: # ➊
    
    ((inputs.dried-nix-flakes.for /* ➋ */ inputs).exportOutputs # ➌
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
```

This is making a dog's dinner out of parentheses,
and might look harder to reason about,
but it's simpler than it looks like.

The numbers in comments show:

 1. The actual Flake output's inputs are taken as a whole.
 2. They are fed into the `for` function of this Flake.
 3. The `exportOutputs` function is called, more on it later.
 4. The intended inputs can be used without tautologically referring to the system types.

The following example shows side-by-side the "translated equivalent" for a single system.

```side-by-side-nix
# A classic Flake.                                          | # A dried-up Flake.
{                                                           | {
  /* inputs */                                              |   /* inputs */
                                                            | 
  outputs =                                                 |   outputs =
                                                            |     inputs:
                                                            |  /* ------- */
                                                            |     
                                                            |     ((inputs.dried-nix-flakes.for inputs).exportOutputs
                                                            |  /* --------------------------------------------------- */
   { nixpkgs, ... }:                                        |       { nixpkgs, ... }:
                                                            | 
   {                                                        |       {
     packages =                                             |         packages = {
       x86_64-linux = {                                     |
    /* ------------ */                                      |
         inherit (nixpkgs.legacyPackages.x86_64-linux)      |           inherit (nixpkgs.legacyPackages)
           hello                      /* ------------ */    |             hello
         ;                                                  |           ;
       };                                                   |
     };                                                     |         };
   }                                                        |       }
                                                            |     )
  ;                                                         |   ;
}                                                           | }
```

Highlighted by dashes are the trade-off this utility Flake makes:
exchanging repetition of a “scoped fact” (a system) for an intermediary function call.

Without using other additional helper libraries,
the example on the left would need to explicitly list any platform that could work,
or end-up listing only a subset of what actually does work.


### Exporting pure Nix too

The `exportOutputs` function will skip expanding the systems on some outputs.

Check the source if in doubts, but the list should map to the usual well-known outputs.

For example:

 - `lib`
 - `nixosModule`
 - `nixosModules`
 - `overlay`
 - `overlays`

One major distinction from "classic" Flakes is that when producing these outputs with `exportOutputs`,
access to any “system-indexed” output ***is forbidden***.

If you (really) need to expose a `lib` function that accesses a system,
use the `merge` pattern to merge a simple attribute set.

Additional outputs can be configured to not be expanded.

```nix
{
  /* inputs */

  outputs =
    inputs:
    let
      dried-nix-flakes = 
        (inputs.dried-nix-flakes.for inputs).override {
          extraIndexedOutputs = [
            "viruses"
          ];
        }
      ;
    in
    {
      packages = dried-nix-flakes.exportOutput (
        { shady-stuff, ... }:
        {
          inherit (shady-stuff.viruses)
            hello
          ;
        }
      );
    }
  ;
}
```



### Adding unconventional system-indexed outputs

The `override` function can take in either `indexedOutputs` or `extraIndexedOutputs` to configure additional outputs that should be collapsed down.

```nix
{
  /* inputs */

  outputs =
    inputs:
    let
      dried-nix-flakes = 
        (inputs.dried-nix-flakes.for inputs).override {
          extraIndexedOutputs = [
            "viruses"
          ];
        }
      ;
    in
    {
      packages = dried-nix-flakes.exportOutput (
        { shady-stuff, ... }:
        {
          inherit (shady-stuff.viruses)
            hello
          ;
        }
      );
    }
  ;
}
```

### Adding systems to be collapsed down and expanded

The `override` function can take in either `systems` or `extraSystems` to configure additional systems that should be handled.

The following example *adds* `armv5tel-linux` to the systems collapsed and expanded by this Flakes support library.

```nix
{
  /* inputs */

  outputs =
    inputs:
    let
      dried-nix-flakes = 
        (inputs.dried-nix-flakes.for inputs).override {
          extraSystems = [
            "armv5tel-linux"
          ];
        }
      ;
    in
    dried-nix-flakes.exportOutput (
      /* ... */
    )
  ;
}
```


How??
-----

We can use conventions to do some of the inconvenient stuff.

Namely, due to how Flakes inputs work,
it is very likely that `nixpkgs` refers to the main package set *your* Flake and *your outputs* use.
We then use the `nixpkgs` input in the `for` utility function to seed the (default) list of systems with `lib.systems.flakeExposed`.

This means that the upstream package set is the one dictating which systems are plausible.
*Not us* (except for the fallback if `nixpkgs` is not an input).

Then, armed with that knowledge, we expose a set of utility functions to handle the unergonomic conventions.
The `exportOutputs` and `exportOutput` functions will automatically “expand” the list of systems from the *`inputs`'s `outputs`*, and pass them to your function.
The function mirrors the usual Flake structure for outputs, but without thinking about systems.

If you are interacting with non-Flake code, there's a bit more that can help you.
This Flake inserts the `import` function into the inputs,
which can be used to import Nix expressions that refers “impurely”[sic] to `builtins.currentSystem` without any changes.

> [!NOTE]
> While opinions differ on whether `builtins.currentSystem` should be considered an impurity, ***this is not introducing an impurity***.
>
> The `builtins.currentSystem` function exposed within this `import` function returns the system from the pure Nix evaluation from within the Flake.
> It is a compatibility shim, and as pure as writing the string it would refer to.
>
> Evaluation or build-time failures with an “unexpected” system name can be pure!


... but why?
------------

While it may seem like explicitly declaring the systems is better, it's really a liability.
***Explicitly declaring systems makes Flakes less composable***.

Any system a Flake can support is limited by the lowest common subset of systems any Flake in the dependency chain exposes.

So if you are referring to a `contoso/widget` Flake,
which only exposes `x86_64-linux` in its outputs,
your outputs won't have any way to even *try* other systems.
Even though it may just as well work on other systems!

When considering composability of Flakes,
it should be desirable to keep the plausible set of systems as wide as possible.
I assume so, since other utility Flakes tried handling this problem with varying degrees of success.

This is why this is defaults to using `inputs.nixpkgs.lib.systems.flakeExposed` when possible.
We're letting the likeliest most-upstream package set dictate which systems to *expose*.
This way, even if you did not test on all of them,
your downstream users can rely on your Flake outputs if it ends-up working.

All of this, without having to specify a long list of systems.


### ... but why *this* solution?

Ergonomics.

All other options I am aware of end-up very leaky about the abstractions.
Either the platforms still need to be declared, the platforms are defined by some other authority, or end-up using very weird hacks.

The main goal when designing the library was that *there should be no system or system variable in play for most use-cases*.
The `system` for all intents and purposes is an implementation detail that for most developers should *just* be inherited from ambient facts.
I want to write a `packages.my-package`, not think about the implementation detail that allows supporting different systems in a Nix evaluation by the upstream package set.

The secondary goal is to *reduce boilerplate, and write the Flake as “Flake-ish” as intended*, especially for the simpler use-cases.
This means the semantics of `outputs` has to be kept as close to the intended ones: a set-pattern function expression exposing the inputs to produce outputs.
No unexpected magic, no additional new semantics, no other shortcuts.

All of this was also designed with the goal of making it easier to produce a Flake stub for generic composable Nix expressions, including expressions relying on Nixpkgs.
With this, it's possible to keep writing standard Nix expressions taking a `pkgs` as an input, and expose it in a form usable within Flakes.


Drawbacks
---------

### Mixing systems

This makes it less convenient to mix different systems in a single output.
Though doing this *may* not be desirable: the systems that Flakes expose are ***build-time systems***.
In other words, the operating system and instruction set the builder uses.
Mixing different systems in a single output *from other Flake outputs* would require multiple builders to build a given output.

This does not affect cross-compilation, for example like how it works in Nixpkgs.


Questions
---------

### Is it okay to depend on Nixpkgs for systems?

Just as much as it is okay for Nix to encode a lot of Nixpkgs-isms into Flakes.

Since Nix assumes a lot about Nixpkgs or its present in Flakes, it is fine to assume that when Nixpkgs is available, we should follow its semantics.

The common usage of Flakes implies Nixpkgs is present, so this is the most ergonomic default.
Usage without Nixpkgs is assumed to be an advanced user choice, and may imply additionally semantics around Flakes.
The fallback default platforms *should be sufficient* in these situations.


* * *


Reference
---------

> [!NOTE]
> This section is a stub.

### `outputs.merge`

Merges attribute sets recursively, only merging attribute sets together.

This fails (errors) on derivations or any other type.

This function is exposed on the Flake as a convenience, as it allows mixing different Flakes conventions.

> [!TIP]
> This function also has been exported on the return value of the `for` function.

The following example produces a Flake with a `lib` output, with two functions, `lib.a` and `lib.b`.

```nix
{
  /* inputs */

  outputs =
    inputs:
    let
      inherit (inputs.dried-nix-flakes.for inputs)
        exportOutputs
      ;
    in
    inputs.dried-nix-flakes.merge [
      {
        lib = {
          a = a: a + "a";
        };
      }
      (exportOutputs {
        { ... }:
        {
          lib = {
            b = b: b + "b";
          };
        }
      })
    ]
  ;
}
```


### `outputs.lib`

For now, know that `lib` functions while accessible, have no SLA.

None are expected to have a stable API.
None are expected to stay exported.


### `outputs.for`

The `for` output is a function intended to receive the `inputs` from a Flake,
and returning a set of utility functions to make writing Flakes more ergonomic.

The public API functions returned currently are:

 - `exportOutput`, which collapses *systems* for inputs, then expands *systems* with the given set-pattern function result.
 - `exportOutputs`, which collapses *systems* for inputs, then expands *systems* on all outputs, except for `outputsWithoutSystems`.
 - `override`, which allows configuring some options.
 - `merge`, which merges attribute sets recursively. (see: `outputs.merge`)


### `outputs.__functor`

As an extra convenience feature, it is possible the call the Flake itself as a function.
Doing so is equivalent to calling `inputs: (dried-nix-flakes.for inputs).exportOutputs`.


```nix
{
  /* inputs */

  outputs =
    inputs:
    inputs.dried-nix-flakes inputs (
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
```
