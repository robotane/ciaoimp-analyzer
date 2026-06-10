# Refonte des registres Prolog Cafe

Cette note documente la refonte appliquée pour supprimer la dépendance
structurelle aux registres et aux choice points hard codés dans Prolog Cafe.

La référence amont est la version `v1.4.4` du dépôt officiel sur
Googlesource, puis la copie embarquée dans `ciaoimp_pipeline_portable`.

Le but n'était pas d'augmenter encore une borne fixe, mais de changer le
modèle de représentation pour que les grandes arités soient gérées par un
mécanisme générique.

## Objectif

L'ancienne architecture reposait sur:

- une base upstream à 10 registres/arités dans `v1.4.4`
- des champs `r1..r10` dans `src/lang/Prolog.java`, puis l'extension locale
  temporaire jusqu'à `r32`
- des classes de sauvegarde `S1..S10`, puis l'extension locale temporaire
  jusqu'à `S32` dans `src/lang/ChoicePointFrame.java`
- des méthodes `jtry1..jtry10`, puis le workaround local `jtry11..jtry32`
- une borne d'arité répliquée dans le générateur `src/compiler/am2j.pl`

Le but était de remplacer cette structure par un mécanisme générique,
maintenable et extensible sans nouvelle série de champs ou de classes.

Le point important est que le changement touche le runtime et le générateur
ensemble. Changer uniquement le générateur aurait laissé le runtime dépendre de
la vieille structure. Changer uniquement le runtime aurait laissé `am2j.pl`
continuer à produire du code non compatible.

## Architecture cible

L'architecture retenue est volontairement simple:

- un banc de registres unique `Term[] r`
- un helper d'extension `ensureRegisterCapacity(int)`
- une sauvegarde de choice point générique qui stocke les `N` premiers
  registres dans un tableau
- un unique point d'entrée `jtry(Operation p, Operation next, int arity)`
- le générateur Java qui écrit des accès indexés au lieu de noms de champs
  matérialisés

Cette forme garde la sémantique actuelle du runtime, mais retire la dépendance
aux séries fixes `r1..rN`, `S1..SN` et `jtry1..jtryN`.

## Pourquoi ce choix

Il existe des variantes plus sophistiquées, par exemple un objet registre dédié
ou une abstraction par vue/banque de registres. Je n'ai pas retenu cela ici car
ce serait plus invasif sans gain immédiat sur ce codebase.

La solution retenue est la plus petite qui supprime réellement le hard coding:

- elle s'appuie sur `Term[]`, donc elle reste proche de la représentation
  actuelle
- elle permet d'étendre la capacité sans changer le code structurel
- elle évite de régénérer des classes ou des méthodes selon l'arité
- elle reste lisible dans le Java généré

## Changements principaux

### Runtime Java

- `src/lang/Prolog.java`
  - remplacement des champs fixes `r1..r32` par un banc de registres `Term[] r`
  - ajout de `ensureRegisterCapacity(int)`
  - ajout de `getRegister(int)` et `setRegister(int, Term)`
  - ajout de `copyRegisters(int)` et `restoreRegisters(Term[])`
  - remplacement de `jtry1..jtry32` par `jtry(Operation p, Operation next, int arity)`
  - `switch_on_term` et `switch_on_hash` utilisent désormais `r[0]`

Concrètement, les accessions 1-based sont converties en indices 0-based dans le
runtime. Le banc de registres est agrandi à la demande avant les écritures et
avant les sauvegardes de choice point.

- `src/lang/ChoicePointFrame.java`
  - suppression de la hiérarchie `S1..S32`
  - remplacement par une seule structure de frame avec `Term[] savedRegisters`
  - restauration générique des registres sauvegardés

Le frame garde uniquement le préfixe utile des registres au moment du choix.
Lors de `restore`, ce préfixe est recopié dans le banc courant puis la
continuation est restaurée comme auparavant.

### Effet sur `try/retry/trust`

Avant:

- `try` sélectionnait `jtryN`
- `jtryN` dépendait d'une classe `S<N>`
- chaque classe codait explicitement les affectations `r1`, `r2`, ...

Après:

- `try` transmet l'arité au runtime
- le runtime fabrique une frame générique avec le nombre de registres à sauver
- `retry` et `trust` n'ont pas besoin d'une variante par arité

Le comportement observable du choix et du retour arrière reste le même, mais la
représentation interne n'est plus figée.

### Générateur Java

- `src/compiler/am2j.pl`
  - génération de `engine.r[index]` au lieu de `engine.rN`
  - génération de `engine.jtry(..., arity)` au lieu de `engine.jtryN(...)`
  - ajout d'un `engine.ensureRegisterCapacity(A)` au début des `exec`
  - suppression de la borne codée en dur dans `write_reg/2`

Le générateur émet toujours du Java direct, mais sans supposer que les
registres existent sous forme de champs nommés. L'arité du prédicat pilote la
capacité requise au moment de l'exécution.

### Builtins Java manuels

- `src/builtin/PRED_regex_match_3.java`
  - migration vers `setRegister/getRegister`
  - remplacement de l'appel `jtry2(...)` par le `jtry(..., 2)` générique

Ce fichier a été ajusté parce qu'il codait encore l'ancien contrat runtime en
dur. C'était la dernière dépendance Java manuelle au modèle `r1/r2` et
`jtry2`.

## Déploiement dans le pipeline portable

Le jar refactoré a été recopié dans:

- `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/plcafe.jar`

La source Prolog Cafe a aussi été copiée à côté du jar dans:

- `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/src`

L'objectif était d'avoir le code source disponible au même endroit que le jar
utilisé par le pipeline, pour faciliter l'inspection, le débogage et une reprise
ultérieure sans devoir retourner au dépôt principal.

Les backups précédents ont été conservés:

- `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/plcafe.jar.bak`
- `projet/src/ciaoimp_pipeline_portable/tools/prolog_cafe/plcafe.jar.bak2`

Le `.bak2` correspond à la version embarquée avant remplacement. Le `.bak`
reste le backup intermédiaire déjà présent.

## Validation

La refonte a été validée par:

1. Rebuild complet de Prolog Cafe via `./build.sh --no-bootstrap`
2. Compilation d'un exemple existant `examples/prolog/list.pl`
3. Compilation d'un prédicat d'arité 12 avec génération Java et `javac`
4. Exécution du pipeline portable complet après suppression du `build/`

Résultat final:

- `CasLog` OK
- `TNF Java VM` OK
- `Prolog Cafe` OK

Le smoke test direct a aussi été vérifié avec:

- compilation d'un exemple standard `examples/prolog/list.pl`
- compilation d'un prédicat d'arité 12
- compilation Java des fichiers générés
- exécution du pipeline portable complet après nettoyage du `build/`

## Notes de maintenance

- Si une nouvelle source Java manuelle manipule les registres, elle doit passer
  par `getRegister`/`setRegister` ou par `engine.r[index]`.
- Si une nouvelle instruction de choix est ajoutée, elle doit utiliser
  `jtry(..., arity)` et non une variante figée.
- Si une future optimisation veut changer la représentation des registres, il
  n'y a plus qu'un seul point à adapter dans le runtime et un seul point à
  adapter dans le générateur.
