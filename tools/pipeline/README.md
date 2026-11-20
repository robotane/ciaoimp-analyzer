# Pipeline unique : CiaoPP + CasLog + gaz mesuré

Une commande, un tableau pour les 14 contrats Hotmoka :

```sh
tools/pipeline/run_pipeline.py                      # les 14 contrats
tools/pipeline/run_pipeline.py simple_ponzi example_coin   # une liste
tools/pipeline/run_pipeline.py --help
```

Étapes (un contrat à la fois, jamais deux CiaoPP/ciaosh/CasLog en même temps ; le script
attend, par pas de 30 s, qu'aucun autre processus d'analyse ne tourne) :

1. régénération de `data/contracts_hotmoka/hotmoka_gas.pl` (`hotmoka-bench/costmodel/gen_model.py`,
   constantes sûres `constants_moka_sur.json`, coût de l'arbre au pire cas) ;
2. CiaoPP, borne de gaz (`rerun_ciaopp_moka.py` : `ulimit -v 3000000`, `CIAOPP_COST_MAX_MB=2800`,
   `timeout 900`) ;
3. CasLog (`tools/caslog_prep/run.sh`) : fonction de temps du point d'entrée, classe déduite ;
4. évaluation de la borne sur les tailles mesurées (`direct_ops.json`, mêmes fonctions que
   `compare_moka.py`) contre le gaz maximal mesuré (`results/bench_moka.csv`) ;
5. écriture de `build/pipeline/<AAAAmmjj-HHMMSS>/` (jamais écrasé, rien n'est supprimé) :
   `tableau.csv`, `tableau.md`, `bounds.json`, `ciaopp/`, `caslog/`.

Colonnes : contrat, opération, borne CiaoPP (formule), classe CiaoPP, fonction CasLog, classe
CasLog, classe mesurée, points, points au-dessus de la borne, ratio médian et maximal
borne/mesuré, verdict (`OK`, `VIOLATION`, `NON BORNE (inf)`, `SANS MESURE`, `ERREUR CiaoPP`),
égalité avec la borne de référence. Une borne `inf` s'affiche sans faire échouer le script.

## Prérequis d'un clone neuf

- `ciaopp` et `ciaosh` dans le `PATH` (`export PATH="$HOME/ciao/build/bin:$PATH"`) ; `gprolog` ;
- CasLog : `CASLOG=/chemin/vers/caslog.gprolog` (défaut : chemin de la machine de l'auteur) ;
- `hotmoka-bench` cloné à côté de `ciaoimp-analyzer` (branche `exp/arbre-pire-cas`, qui contient
  `constants_moka_sur.json`) ou `HOTMOKA_BENCH` ;
- python3 avec `numpy` et `matplotlib` (importé par `costmodel/compare.py`) ;
- pour `--remesurer` seulement : docker et l'image `hotmoka/mokamint-node:1.12.3`, JDK 21, Maven hors
  ligne, et le jar des contrats, à construire d'abord (voir `hotmoka-bench/moka/README.md`) :
  `cd hotmoka-bench/contracts && JAVA_HOME=$HOME/.sdkman/candidates/java/21-tem mvn -o -T1 package`.

Avec le gaz de référence (`results/bench_moka.csv`) : 0 point au-dessus des bornes et `bounds.json`
identique à la référence (`tools/pipeline/reference_bounds.json`). Le contrat témoin `tontine` se
mesure à part (`results/bench_tontine.csv` de la branche `exp/contrat-temoin` de hotmoka-bench) :
`--moka …/bench_tontine.csv tontine`. Avec `--remesurer`, le gaz change un peu d'un nœud à l'autre
(adresses de comptes aléatoires) : quelques points peuvent dépasser une borne (voir la section
« Reproductibilité du gaz » du README de moka).

## Options

- `--out DIR` dossier parent des sorties ; `--moka CSV` gaz mesuré ; `--constants JSON` (défaut
  `costmodel/constants_moka_sur.json` de hotmoka-bench) ;
  `--reference JSON` (défaut `tools/pipeline/reference_bounds.json`, écarts signalés) ;
  `--skip-caslog`.
- `--remesurer` : relance d'abord `hotmoka-bench/moka/mesurer.sh` (nœud moka sous docker
  `--memory=2g`, pilote JVM `-Xmx1g`) pour les contrats choisis, dans un nouveau CSV
  `<sortie>/bench_moka.csv` utilisé à la place de `--moka`. Désactivé par défaut (docker + JVM,
  long) ; non exécuté lors de la mise au point.

## Variables

- `HOTMOKA_BENCH` : dépôt hotmoka-bench (défaut `../hotmoka-bench` relatif à ciaoimp-analyzer, ou au dépôt principal depuis un worktree).
  Il doit contenir le commit de `gen_model.py`/`rerun_ciaopp_moka.py` acceptant `CIAOIMP_ROOT`
  (le pipeline la fixe sur son propre checkout, donc fonctionne depuis un worktree).
- `CASLOG` : exécutable CasLog.

## Gaz des BigInteger selon leur taille

Par défaut, l'arithmétique sur les montants est comptée à coût constant et les bornes de
`reference_bounds.json` ne changent pas. Un contrat peut demander le coût selon la taille des
nombres avec les primitives `big_add/3`, `big_sub/3`, `big_mul/3`, `big_div/3`, `big_mod/3`,
`big_gt/2`, `big_ge/2` et `big_pay/2` de `data/contracts_hotmoka/hotmoka.pl`, et la directive
`:- bigint_cost.` (le préfixe d'une méthode `payable` compte alors aussi le paiement du montant).
Le modèle (`hotmoka_gas.pl.in`) reprend la règle de `BigIntegerSupport` (takamaka-code 1.8.1) :
opération arithmétique : +2·(bl(a)+bl(b)) (CPU et RAM), comparaison : +(bl(a)+bl(b)) (CPU), avec
bl(x) ≤ log2(x+1)+1. `Contract.pay` (compareTo, subtract, add) coûte 5·bl(montant) + 3·bl(solde du
payeur) + 2·bl(solde du bénéficiaire) : `big_pay(Montant, Solde)` compte les deux premiers termes, le solde
du payeur étant une hypothèse écrite dans le contrat (borne `Solde`), les soldes des comptes
utilisateurs étant ceux de la calibration de `C_PAY`. Seuls `simple_ponzi` et `gradual_ponzi` les utilisent.
Les bornes contiennent alors des termes `log(2,int(X)+1)` ; `bigint_ops.json` donne la valeur de `X`
à chaque point mesuré. CasLog ne voit pas ce terme (voir `tools/caslog_prep/README.md`).
