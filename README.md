# ciaoimp-analyzer

Bornes de gaz statiques pour des contrats intelligents Hotmoka/Takamaka.

Chaque contrat est réécrit dans un petit DSL Ciao impératif (`data/contracts_hotmoka/`).
Le pipeline en tire trois résultats par opération :

- une **borne de gaz** calculée par CiaoPP (analyse de ressources, modèle de gaz Hotmoka) ;
- une **classe de complexité** O(·) calculée par CasLog ;
- une **validation** contre le gaz réellement mesuré sur un nœud Hotmoka 1.12.3.

```text
data/contracts_hotmoka/<contrat>.pl  (DSL : hotmoka.pl, hotmoka_tr.pl)
  ├─ modèle de gaz (hotmoka_gas.pl, constantes mesurées) ─> CiaoPP ─> borne de gaz
  ├─ tools/caslog_prep ──────────────────────────────────> CasLog ─> classe O(·)
  └─ gaz mesuré sur un nœud Hotmoka (results/bench_moka.csv) ─> borne ≥ mesuré ?
```

Résultat de référence : sur les 14 contrats, aucune des 3312 mesures ne dépasse la borne
calculée ; aucune des 131 mesures du contrat témoin `tontine` non plus.

## Lancer le pipeline

```sh
tools/pipeline/run_pipeline.py
tools/pipeline/run_pipeline.py simple_ponzi example_coin
```

Prérequis, options et variables d'environnement : [`tools/pipeline/README.md`](tools/pipeline/README.md).
Préparation pour CasLog : [`tools/caslog_prep/README.md`](tools/caslog_prep/README.md).

## Organisation

| Chemin | Contenu |
|---|---|
| `data/contracts_hotmoka/` | les 14 contrats et `tontine` en DSL, le DSL (`hotmoka.pl`, `hotmoka_tr.pl`), le modèle de gaz (`hotmoka_gas.pl.in`) |
| `tools/pipeline/` | pipeline unique CiaoPP + CasLog + gaz mesuré, bornes de référence |
| `tools/caslog_prep/` | traduction du DSL vers l'entrée de CasLog |
| `data/ciaopp_cost/`, `src/ciaopp_cost/` | lecture des sorties de CiaoPP |

Le DSL propose notamment `require/1,2`, des accès `Obj[f]` comptés comme lectures de stockage,
les opérations sur les collections Takamaka (arbres rouge-noir, coût au pire cas dérivé de leur
code) et, en option, le coût des BigInteger selon leur taille (règle de
`io.takamaka.code.math.BigIntegerSupport`, voir `tools/pipeline/README.md`).

## Ancienne version (xsyntax, TNF, Prolog Cafe)

Le dépôt contient encore le premier pipeline (`pipeline.py`, `src/`, `data/source/`, `docs/`,
`Dockerfile`) : contrats Prolog en syntaxe impérative (xsyntax) traduits vers CasLog, l'assembleur
TNF et Prolog Cafe. Il n'est plus maintenu et n'a pas été revérifié depuis le passage au pipeline
ci-dessus ; il est gardé pour l'historique. L'état du dépôt avant ce passage est marqué par le tag
`archive/ancien-pipeline-2026-11-19`.
