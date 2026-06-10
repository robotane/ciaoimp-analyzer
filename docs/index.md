# CiaoImp Pipeline

Documentation de référence du pipeline `ciaoimp_pipeline`.

Le pipeline transforme les contrats de `data/source/` en trois sorties
exploitables :

- une entrée annotée pour l'analyse statique CasLog ;
- un programme compilé en ASM TNF puis exécuté par la VM Python ;
- une traduction en Java compilée et exécutée par la JVM via Prolog Cafe.

## Vue rapide

```text
data/source/*.pl
  -> build/executable/*.pl
  -> build/normalized/*.pl
     -> build/annotated/*.pl -> CasLog
     -> build/tnf_asm/*.txt  -> TNF
     -> build/prolog_cafe_classes/ -> Prolog Cafe
  -> results/*.txt
```

`build/normalized/` est la forme commune avant bifurcation. CasLog lit
`build/annotated/`, TNF lit `build/normalized/` et Prolog Cafe génère son code
Java à partir de `build/normalized/`.

## Commandes essentielles

```bash
# Lancer le pipeline complet
python3 pipeline.py blind_auction.pl
# Lancer sans l'étape TNF
python3 pipeline.py run --no-tnf blind_auction.pl
# Relancer uniquement l'étape TNF
python3 pipeline.py run-tnf blind_auction
```

## Source de vérité

- `src/` contient la logique du pipeline.
- `docs/` contient la documentation source.
- `site/`, `build/` et `results/` contiennent des fichiers générés.
- `tools/caslog/` et `tools/LogicTransformers/` sont des dépendances embarquées.

## Par où commencer

1. Lire [Prérequis et démarrage](prerequisites.md) pour installer et lancer le
   pipeline sur une machine nouvelle.
2. Lire [Guide pipeline](pipeline-guide.md) pour les commandes de lancement et
   de dépannage.
3. Lire [Architecture](architecture.md) pour comprendre la structure complète,
   les entrées, les sorties et les outils utilisés.
