(lang dune 3.6)

(name camllib)

(version 1.4.0)

(generate_opam_files true)

(source
 (github PaulRaUnite/camllib))

(authors "Bertrand Jeannet")

(maintainers "Nicolas Berthier <m@nberth.space>")

(license LGPL-2.1-only)

(documentation
 https://www.inrialpes.fr/pop-art/people/bjeannet/bjeannet-forge/camllib/index.html)

(package
 (name camllib)
 (synopsis
  "Various abstract datatypes inspired by the standard OCaml library.")
 (depends
  (ocaml
   (> 4.02))
  stdlib-shims
  dune
  (odoc :with-doc)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
