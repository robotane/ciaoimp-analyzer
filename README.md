# ciaoimp-analyzer

Ce dossier contient l'analyseur portable CiaoImp. La documentation suppose une
racine de projet nommée `ciaoimp-analyzer/`.

Le pipeline prend des contrats dans `data/source/`, les transforme en Prolog
exploitable, puis produit une branche d'analyse (CasLog) et deux branches d'exécution (TNF et Prolog Cafe).

## Flux résumé

```text
data/source/*.pl
  -> build/executable/*.pl
  -> build/normalized/*.pl
     -> build/annotated/*.pl -> CasLog -> results/caslog_*.txt
     -> build/tnf_asm/*.txt  -> TNF    -> results/tnf_*.txt
     -> build/prolog_cafe_classes/ -> Prolog Cafe -> results/prolog_cafe_*.txt

results/stage_diffs.txt compare les étapes publiques générées.
```

Lecture rapide :

- `build/executable/` contient la première sortie Prolog stable du pipeline.
- `build/normalized/` est la forme commune avant bifurcation.
- `build/annotated/` est la version dérivée pour CasLog.
- `build/tnf_asm/` contient l'assembleur TNF généré depuis `build/normalized/`.
- `build/prolog_cafe_classes/` contient le bytecode Java généré par Prolog Cafe.
- `results/` rassemble les rapports consolidés.

## Commandes rapides

Depuis la racine du projet :

```bash
# Lancer le pipeline complet pour un contrat
python3 pipeline.py run blind_auction.pl
# (Ou plus court)
python3 pipeline.py blind_auction.pl

# Lancer sans CasLog ni Prolog Cafe
python3 pipeline.py run --no-caslog --no-prolog-cafe blind_auction.pl

# Relancer uniquement l'étape TNF (sur des contrats déjà normalisés)
python3 pipeline.py run-tnf blind_auction

# Exécuter directement un fichier ASM avec l'interpréteur TNF
python3 pipeline.py run-asm data/source/auction_asm.txt
```

Pour lancer le pipeline complet sur tous les contrats :

```bash
python3 pipeline.py
```

## Documentation

La source de vérité documentaire est dans `docs/`, avec la configuration
MkDocs dans `mkdocs.yml`. Le dossier `site/` contient une version HTML générée.

Pour reconstruire la documentation :

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r docs/requirements.txt
.venv/bin/mkdocs build
```

Lire ensuite :

- [Installation Ubuntu](INSTALLATION_UBUNTU.md)
- [Architecture](docs/architecture.md)
- [Guide pipeline](docs/pipeline-guide.md)
