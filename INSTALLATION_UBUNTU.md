# Installation Ubuntu

Ce guide décrit la remise en route de l'archive `ciaoimp_pipeline` sur une
machine Ubuntu.

## 1. Copier et décompresser l'archive

Depuis la machine cible :

```bash
mkdir -p ~/work
cd ~/work
tar -xzf ciaoimp_pipeline.tar.gz
cd ciaoimp_pipeline
```

## 2. Installer les dépendances système

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip swi-prolog gprolog curl
curl https://ciao-lang.org/boot -sSfL | sh
```

Vérification rapide :

```bash
python3 --version
swipl --version
gprolog --version
ciaopp --version
test -x tools/caslog/caslog.gprolog
test -f tools/LogicTransformers/tnf.pro
```

## 3. Premier lancement

Commencer par un seul contrat :

```bash
python3 pipeline.py blind_auction.pl
```

Les principales sorties sont générées dans :

- `build/executable/`
- `build/normalized/`
- `build/annotated/`
- `build/tnf_asm/`
- `results/`

Pour lancer tout le corpus :

```bash
python3 pipeline.py
```

## 4. Documentation locale

Le dossier `site/` contient la documentation HTML générée quand elle est incluse
dans l'archive.

Pour reconstruire la documentation :

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r docs/requirements.txt
.venv/bin/mkdocs build
```

Pour la servir localement :

```bash
.venv/bin/mkdocs serve
```

## 5. Dépannage minimal

`CiaoPP not found`
: vérifier que l'installation Ciao est terminée et que `ciaopp --version`
répond.

`CasLog not found`
: vérifier que `tools/caslog/caslog.gprolog` est présent et exécutable.

`No input files`
: vérifier que les contrats `.pl` sont présents dans `data/source/`.

`No TNF input files`
: lancer d'abord `python3 pipeline.py ...` pour produire `build/normalized/`.
