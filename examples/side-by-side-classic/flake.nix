# A classic Flake.
{
  /* inputs */

  outputs =





   { nixpkgs, ... }:

   {
     packages = {
       x86_64-linux = {
    /* ------------ */
         inherit (nixpkgs.legacyPackages.x86_64-linux)
           hello                      /* ------------ */
         ;
       };
     };
   }

  ;
}
