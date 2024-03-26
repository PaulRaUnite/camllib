## Release 1.4.0

- now use dune as build system
- in OCaml 4.12 `caml_hash_univ_param` was removed, use `caml_hash` instead

## Release 1.3.0

- Updated Hashhe, DHashhe, Sette and Mappe according to changes
  brought by release 4.00 of OCaml, minor one thing: new seeded
  hash functions not provided, in order to remain compatible with
  older OCaml runtimes.

- New Ilist.t type (sublists are now give an attribute/exponent),
  induces non compatible changes in graphs modules
