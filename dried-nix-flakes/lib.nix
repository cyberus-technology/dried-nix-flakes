let
  # When printing values in errors, escape them slightly using `e`.
  e = builtins.toJSON;

  # Library functions.
  # There is no SLA for using these from other Flakes at this point in time.
  lib = {
    #
    # Basic
    #

    # Returns true when the givne value is a derivation.
    isDerivation =
      value:
      builtins.isAttrs value && (value.type or null) == "derivation"
    ;

    # Wrapper around `typeOf` adding "derivation" to the known types.
    # Prefer `lib.isDerivation` for code.
    # Use this for error messages.
    typeOf =
      value:
      if lib.isDerivation value
      then "derivation"
      else builtins.typeOf value
    ;

    #
    # Attribute Sets
    #

    # Given a function and a list, builds an attribute set keyed by the list entries, and values from the function return values.
    # The function receives the list entry (the new attribute's name).
    genAttrs =
      fn: list:
      builtins.listToAttrs
      (
        builtins.map
        (
          name:
          {
            inherit name;
            value = fn name;
          }
        )
        list
      )
    ;

    # Given an attribute set, maps on the attribute set's values.
    # The function receives the key and values as input.
    # It must return only the new value.
    mapAttrValues =
      fn: attrs:
      lib.genAttrs
      (
        name:
        fn /*key: */ name /*value: */ attrs.${name}
      )
      (builtins.attrNames attrs)
    ;

    # Whether `deepMergeAttrs` knows how to merge the given value.
    deepMergeAttrsCanMerge =
      value:
      builtins.isAttrs value && !(lib.isDerivation value)
    ;

    # Merges two attribute sets together, deeply (recursively).
    deepMergeAttrs =
      a: b:
      a // (
        lib.mapAttrValues
        (name: b_value:
          let
            a_value = a.${name};
          in
          if !(a ? ${name}) then
            b_value
          else if !(lib.deepMergeAttrsCanMerge a_value && lib.deepMergeAttrsCanMerge b_value) then
            builtins.throw (
              "deepMergeAttrs encountered unmergeable values with the same key.\n"
              #  error: ...
              + "       a.${e name} is a ${lib.typeOf a_value}.\n"
              + "       b.${e name} is a ${lib.typeOf b_value}."
            )
          else
            lib.deepMergeAttrs a.${name} b_value
        )
        b
      )
    ;

    # Given a list of attribute sets, deep merges them all together.
    # Convenience wrapper around `deepMergeAttrs`.
    deepMergeAttrsList =
      list:
      builtins.foldl'
      lib.deepMergeAttrs
      {}
      list
    ;

    #
    # Lists
    #

    # Given a list, returns an attribute set keyed with the list entries.
    # All values are `true`.
    toLookupTable =
      list:
      lib.genAttrs
      (_: true)
      list
    ;

    #
    # Convenience
    #

    # Returns a list of (lossy) unique elements from the input list.
    # The elements must be valid as an attribute set key!
    uniqLossy =
      list:
      builtins.attrNames
      (lib.toLookupTable list)
    ;

    # Given two lists, returns a (lossy) list of elements found it both lists.
    # See uniqLossy for details about loss.
    uniqLossyIntersect =
      a: b:
      builtins.attrNames
      (
        builtins.intersectAttrs
        (lib.toLookupTable a)
        (lib.toLookupTable b)
      )
    ;
  };
in
  lib
