# Changelog

## Unreleased

Source de reference: le depot officiel Prolog Cafe `v1.4.4` sur Googlesource,
plus la copie embarquee dans `ciaoimp_pipeline_portable`.

### Refonte des registres et des choice points

- Base upstream `v1.4.4` sur 10 registres/arités, puis suppression du
  workaround local 10 -> 32 au profit d'un banc de registres dynamique
  `Term[] r` dans `src/lang/Prolog.java`.
- Ajout de `ensureRegisterCapacity(int)`, `getRegister(int)`,
  `setRegister(int, Term)`, `copyRegisters(int)` et
  `restoreRegisters(Term[])`.
- Suppression des classes `ChoicePointFrame.S1..S10` puis de l'extension
  locale temporaire jusqu'à `S32`, au profit d'une seule frame générique avec
  sauvegarde tabulaire des registres.
- Remplacement des variantes `jtry1..jtry10` puis du workaround local
  `jtry11..jtry32` par `jtry(Operation p, Operation next, int arity)`.
- Mise à jour de `switch_on_term` et `switch_on_hash` pour lire le registre
  argumentaire via `r[0]`.

### Générateur `am2j.pl`

- Génération d'accès indexés `engine.r[index]` au lieu des champs fixes
  `engine.rN`.
- Génération de `engine.jtry(..., arity)` au lieu des variantes `jtryN`.
- Ajout d'un `engine.ensureRegisterCapacity(A)` au début des `exec`
  générés.
- Suppression de la borne codée en dur sur l'arité dans `write_reg/2`.
- Conservation du code généré compatible avec les prédicats d'arité > 10.

### Builtins Java

- Migration de `src/builtin/PRED_regex_match_3.java` vers
  `setRegister/getRegister`.
- Remplacement de `engine.jtry2(...)` par le `jtry(..., 2)` générique.
- Le portable embarque aussi les helpers Java de `am2j` qui n'existent pas dans
  l'amont `v1.4.4` de cette forme (`src/compiler/am2j/PRED_pred_encoding_3.java`
  et `src/compiler/am2j/PRED_package_encoding_3.java`).

### Déploiement portable

- Recopie du jar refactoré dans
  `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/plcafe.jar`.
- Recopie du code source Prolog Cafe dans
  `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/src`.
- Conservation des sauvegardes `plcafe.jar.bak` et `plcafe.jar.bak2`.
- Ajout de `build.sh` comme wrapper de génération/compilation locale.
- Ajout de `CHANGELOG.md` et `REFONTE_REGISTRES.md` dans la copie portable.
- Ajout de `README.md` mis à jour avec un pointeur vers le changelog.
- `BUILD` et `WORKSPACE` de la copie portable suivent la variante Bazel
  moderne du dépôt local, pas l'arbre strictement identique de `v1.4.4`.

### Validation

- Rebuild complet de Prolog Cafe via `./build.sh --no-bootstrap`.
- Compilation d'un exemple existant `examples/prolog/list.pl`.
- Compilation et génération Java d'un prédicat d'arité 12.
- Exécution du pipeline portable complet après suppression du `build/`.
- Comparaison explicite avec la source officielle `v1.4.4` clonée depuis
  Googlesource.
