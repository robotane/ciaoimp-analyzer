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
   constantes `constants_moka.json`) ;
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

## Options

- `--out DIR` dossier parent des sorties ; `--moka CSV` gaz mesuré ; `--constants JSON` ;
  `--reference JSON` (défaut `costmodel/final_moka_ciaopp_reveal/bounds.json`, écarts signalés) ;
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
