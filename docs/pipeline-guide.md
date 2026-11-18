# Guide pipeline

## À quoi sert ce guide

Cette page explique comment lancer le pipeline, choisir le bon mode d'exécution
et lire les principales sorties. Pour la structure détaillée et les relations
entre fichiers, voir [Architecture](architecture.md).

## Vérifications minimales

Depuis la racine du projet :

```bash
python3 --version
swipl --version
gprolog --version
ciaopp --version
test -x tools/caslog/caslog.gprolog
test -f tools/LogicTransformers/tnf.pro
```

## Modes de lancement

### Pipeline complet sur un contrat

```bash
python3 pipeline.py blind_auction.pl
```

Ce mode produit la chaîne complète pour un contrat :

```text
data/source/<contrat>.pl
  -> build/executable/<contrat>.pl
  -> build/normalized/<contrat>.pl
     -> build/annotated/<contrat>.pl
     -> build/tnf_asm/<contrat>_asm.txt
     -> build/prolog_cafe_classes/
  -> results/*.txt
```

### Pipeline complet sur tous les contrats

```bash
python3 pipeline.py
```

Sans argument, le pipeline traite tous les fichiers `.pl` présents dans
`data/source/`.

### Pipeline sans TNF

```bash
python3 pipeline.py --no-tnf blind_auction.pl
```

Ce mode s'arrête après la transformation, la normalisation, l'annotation CasLog
et l'exécution CasLog. Il est utile quand la compilation ou l'exécution TNF n'est
pas nécessaire.

### Préparer uniquement `build/normalized/`

```bash
python3 pipeline.py --no-caslog --no-tnf --no-prolog-cafe blind_auction.pl
```

Ce mode produit `build/executable/`, `build/normalized/` et
`results/stage_diffs.txt`. Il sert surtout à préparer une entrée TNF ou à
inspecter la normalisation.

### TNF seul

```bash
python3 pipeline.py run-tnf blind_auction
```

Cette commande suppose que `build/normalized/blind_auction.pl` existe déjà.
Elle relance uniquement la compilation TNF puis la VM Python.

## Sorties à lire

`build/executable/`
: sortie Prolog après expansion, nettoyage et transformation.

`build/normalized/`
: forme normalisée commune avant bifurcation ; entrée directe de TNF.

`build/annotated/`
: version annotée pour CasLog avec `mode/2` et `measure/2`.

`build/tnf_asm/`
: ASM TNF généré depuis `build/normalized/`.

`build/prolog_cafe_classes/`
: bytecode Java compilé par Prolog Cafe depuis `build/normalized/`.

`results/caslog_full_results.txt`
: journal complet CasLog.

`results/caslog_important_results.txt`
: résumé compact CasLog.

`results/tnf_results.txt`
: journal complet TNF.

`results/tnf_important_results.txt`
: résumé compact TNF.

`results/prolog_cafe_results.txt`
: journal d'exécution Java (Prolog Cafe).

`results/stage_diffs.txt`
: comparaison textuelle entre `source`, `executable`, `normalized` et
`annotated`.

## Ce que le pipeline déduit seul

Aucune partie du pipeline ne connaît un contrat par son nom. Ce qui était
écrit à la main pour chaque contrat est maintenant déduit du contrat et de son
scénario `goal/1`.

Specs CiaoPP (`src/ciaopp_cost/genspec.py`)
: le scénario est exécuté appel par appel (`collect_calls.pl`) ; les
opérations sont les prédicats appelés par `goal/1` (hors primitives de
`blockchain.pl`) ; leurs types d'arguments sont la généralisation des valeurs
observées, avant et après chaque appel, les champs d'état étant suivis d'une
opération à la suivante. Une table du modèle de coût (`balances`, ...) garde
son nom. Les specs écrites à la main de `data/ciaopp_cost/specs*` restent
disponibles comme référence avec `CIAOPP_COST_SPECS=hand`.

Modes CasLog (`src/annotation/collect_modes.pl`)
: les modes sont ceux observés quand `goal/1` s'exécute (`+` : argument lié à
chaque appel, ou libre à l'appel et à la sortie ; `-` sinon).

Boucles (`src/cleaning/loops`, `src/annotation/accumulators.py`)
: les boucles `for` du Ciao actuel sont remises sous forme canonique (cas de
base `[]`, sans coupure ni argument de reste), les arguments inutilisés des
auxiliaires sont supprimés ; pour CasLog seulement, une liste construite par
accumulateur devient une récursion structurelle (même longueur, même coût,
ordre inversé).

## Règles d'écriture d'un contrat

1. Le contrat a un scénario `goal/1` qui s'exécute sans échec.
2. Le scénario appelle chaque opération du contrat au moins une fois. Une
   opération jamais appelée n'a ni entrée CiaoPP ni annotation CasLog ; elle
   est signalée (avertissement de `genspec`, commentaire en tête du fichier
   annoté).
3. Les tables d'état que le scénario laisse vides sont typées comme listes de
   termes clos (`gnd`) ; pour un type plus précis, le scénario doit les
   remplir au moins une fois.

## Dépannage

Si un lancement échoue, regarder dans cet ordre :

1. La sortie terminal pour identifier l'étape en échec.
2. `results/stage_diffs.txt` pour voir comment le contrat a évolué.
3. `results/caslog_full_results.txt` si le problème concerne CasLog.
4. `results/tnf_results.txt` si le problème concerne TNF.
5. `build/executable/` puis `build/normalized/` pour inspecter la forme
   générée.

Erreurs fréquentes :

`No input files`
: vérifier que les contrats `.pl` sont présents dans `data/source/`.

`CiaoPP not found`
: vérifier que `ciaopp --version` répond.

`CasLog not found`
: vérifier que `tools/caslog/caslog.gprolog` est présent et exécutable.

`No TNF input files`
: lancer d'abord `python3 pipeline.py ...` pour produire `build/normalized/`.
