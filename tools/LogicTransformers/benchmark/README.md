# Benchmark CasLog vs VM TNF

Ce dossier contient une campagne de benchmarks experimentaux qui compare :

- une borne symbolique obtenue par CasLog
- avec un temps empirique mesure apres compilation TNF puis execution dans la VM Python

L'objectif n'est pas de prouver une equivalence formelle entre CasLog et TNF, mais de confronter :

- une complexite statique sur les predicats Prolog normalises
- a un comportement empirique observe apres transformation et execution


## 1. Vue d'ensemble

Le benchmark suit le pipeline suivant :

1. selection des contrats a analyser
2. relance du pipeline CasLog si necessaire
3. extraction des predicats importants et de leurs formules depuis `results/caslog_important_results.txt`
4. generation de scenarios Prolog temporaires adaptes a chaque contrat et a chaque predicat
5. compilation TNF de ces scenarios en assembleur
6. execution de la VM Python TNF
7. mesure des temps d'execution
8. evaluation numerique des formules CasLog pour les memes tailles d'entree
9. generation des CSV/JSON et des graphes


## 2. Arborescence

Depuis `tools/LogicTransformers/benchmark/` :

- `run_all_benchmarks.py`
  Point d'entree unique. Il supporte une campagne reduite ou complete.

- `benchmarks/catalog.py`
  Catalogue des benchmarks. Chaque entree correspond a un couple `(contrat, predicat)` et contient :
  - le nom du contrat
  - la signature du predicat CasLog
  - la liste des tailles `N`
  - le mapping entre variables CasLog et taille `N`
  - le generateur de scenario a executer

- `core/`
  Logique factorisee :
  - extraction CasLog
  - gestion des chemins
  - generation des artefacts
  - export CSV/JSON
  - execution de la VM TNF

- `results/raw/`
  Sorties brutes :
  - `all_benchmarks.csv`
  - `all_benchmarks.json`
  - `focused_benchmarks.csv`
  - `focused_benchmarks.json`

- `results/plots/<contrat>/`
  Sorties graphiques par contrat :
  - un graphe par predicat
  - un graphe groupe `predicats.png`

- `work/`
  Artefacts auto-generes uniquement.
  Tout ce qui s'y trouve est regenerable.


## 3. Point d'entree unique

Toutes les executions passent par :

```bash
python3 run_all_benchmarks.py --suite focused
python3 run_all_benchmarks.py --suite all
```

Deux modes sont disponibles.

### `--suite focused`

Cette suite reduite sert a produire rapidement quelques graphes de reference sur des contrats deja selectionnes.

Elle couvre actuellement :

- `simple_ponzi`
- `distributor`
- `simple_pyramid`

Chaque contrat contient plusieurs predicats importants.

### `--suite all`

Cette suite execute la campagne complete sur l'ensemble des contrats et des predicats numeriques importants presentes dans les resultats CasLog.

Elle genere :

- les donnees brutes globales
- les graphes par contrat
- les graphes individuels par predicat
- les graphes groupes `predicats.png`


## 4. Source de verite pour les predicats

Les predicats traces doivent correspondre aux resultats CasLog effectivement obtenus.

La source de verite est :

- `results/caslog_important_results.txt`

Le benchmark n'utilise pas de formules theorique recopiees a la main pour les courbes finales. Il relit les formules CasLog produites par le pipeline, puis les evalue numeriquement.

Cela signifie :

- si CasLog ne produit pas un predicat dans les resultats importants, il ne doit pas etre trace
- si CasLog produit un predicat avec `inf`, il n'y a pas de comparaison numerique exploitable CasLog/VM
- seuls les predicats numeriques benchmarkables sont traces


## 5. Comment la campagne est construite

Chaque benchmark correspond a un `BenchmarkSpec` dans `benchmarks/catalog.py`.

Un `BenchmarkSpec` definit :

- `name`
  identifiant technique du benchmark

- `contract`
  nom du contrat

- `predicate`
  signature CasLog du predicat a comparer, par exemple `invest/8`

- `complexity_label`
  etiquette informative, par exemple `O(N)` ou `O(N²)`

- `ns`
  liste des tailles `N` testees

- `caslog_bindings`
  mapping entre les variables CasLog (`$i`) et la taille experimentale `N`

- `build_source`
  generateur de scenario Prolog pour ce predicat

- `x_label`
  etiquette de l'axe horizontal


## 6. Interpretation des graphes

### Graphes individuels

Chaque fichier du type :

- `results/plots/<contrat>/<predicat>.png`

compare :

- la courbe de temps VM en bleu
- la courbe CasLog en rouge

Le graphe contient aussi un encadre avec la formule CasLog exacte, par exemple :

- `Formule CasLog : [16* $7+22]`

Cela permet de savoir explicitement quelle borne a ete utilisee.

### Graphe groupe `predicats.png`

Chaque dossier de contrat contient aussi :

- `results/plots/<contrat>/predicats.png`

Ce graphe superpose tous les predicats benchmarkes pour ce contrat.

Il contient un encadre listant les formules CasLog de tous les predicats du contrat.

Ce graphe sert a voir rapidement :

- quels predicats sont quasi constants
- quels predicats croissent lineairement
- quels predicats dominent le cout du contrat


## 7. Lecture correcte des resultats

Ces graphes doivent etre interpretes avec prudence.

### Ce qu'ils montrent bien

- la tendance generale de croissance
- la comparaison entre plusieurs predicats d'un meme contrat
- la coherence ou non entre la structure CasLog et le comportement empirique

### Ce qu'ils ne prouvent pas

- une equivalence mathematique entre CasLog et TNF
- une borne asymptotique absolue sur l'implementation Python
- une relation parfaite entre la formule CasLog et le temps reel en millisecondes

### Cas typiques

- si la courbe VM suit grossierement la forme de la courbe CasLog, cela corrobore la tendance
- si la courbe VM est presque plate alors que CasLog croit, cela peut indiquer un bruit de mesure ou un cout fixe dominant
- si un predicat `O(1)` est visuellement ecrase par un predicat `O(N²)` dans `predicats.png`, il faut regarder son graphe individuel


## 8. Resultats bruts

Les fichiers dans `results/raw/` permettent de reconstituer exactement la comparaison.

Chaque ligne contient notamment :

- le benchmark
- le contrat
- le predicat
- la taille `N`
- le temps VM mesure
- la formule CasLog
- la valeur numerique CasLog apres substitution

Ces fichiers sont utiles pour :

- refaire des graphes externes
- tracer des courbes dans un notebook
- verifier quelle formule a servi a chaque figure


## 9. Nettoyage et regeneration complete

Si tu veux repartir d'un etat propre :

1. vider `results/plots/`
2. vider `results/raw/`
3. vider `work/` en conservant `work/README.md`
4. relancer la campagne

Commandes typiques :

```bash
find results/plots -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find results/raw -mindepth 1 -maxdepth 1 -type f -delete
find work -mindepth 1 ! -name README.md -exec rm -rf {} +
python3 run_all_benchmarks.py --suite all
python3 run_all_benchmarks.py --suite focused
```

La regeneration complete reconstruit :

- les scenarios temporaires
- les donnees brutes
- les graphes individuels
- les graphes groupes


## 10. Ajout d'un nouveau predicat

Pour ajouter un nouveau predicat a la campagne :

1. verifier qu'il apparait dans `results/caslog_important_results.txt`
2. verifier que son cout CasLog est numerique et non `inf`
3. ajouter un generateur de scenario dans `benchmarks/catalog.py`
4. ajouter un `BenchmarkSpec` avec :
   - la bonne signature
   - les bons `bindings`
   - les tailles `N` adaptees
5. relancer `--suite all`

Important :

- il faut que le scenario appelle reellement le predicat cible
- il faut que le parametre qui varie dans CasLog corresponde bien a la taille experimentale choisie


## 11. Limites connues

- tous les predicats importants CasLog ne sont pas forcement pertinents pour un benchmark metier
- les predicats a `inf` ne sont pas traces ici
- certaines courbes VM peuvent rester presque plates si le bruit de mesure domine
- la VM Python introduit un cout fixe d'interpretation qui peut masquer la croissance asymptotique sur les petites tailles
- les variables CasLog `$i` restent affichees telles quelles dans les formules ; elles viennent directement des sorties CasLog


## 12. Commandes conseillees

Depuis ce dossier :

```bash
python3 run_all_benchmarks.py --suite all
```

Pour une iteration rapide :

```bash
python3 run_all_benchmarks.py --suite focused
```

Pour verifier le point d'entree sans tout executer :

```bash
python3 -m py_compile run_all_benchmarks.py benchmarks/catalog.py core/*.py
```


## 13. Fichiers importants

- [run_all_benchmarks.py](./run_all_benchmarks.py)
- [benchmarks/catalog.py](./benchmarks/catalog.py)
- [core/caslog.py](./core/caslog.py)
- [core/tnf_runtime.py](./core/tnf_runtime.py)
- [work/README.md](./work/README.md)

