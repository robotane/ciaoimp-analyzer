# Prérequis et démarrage

Cette page donne la procédure nécessaire pour installer, vérifier et lancer le
pipeline sur une machine Ubuntu. Elle suppose que le dossier `ciaoimp_pipeline`
a déjà été copié localement.

## 1. Outils nécessaires

Le pipeline s'appuie sur quatre familles d'outils :

`Python 3`
: exécute l'orchestrateur `pipeline.py`, les transformations internes et la VM
TNF Python.

`SWI-Prolog`
: exécute les transformations Prolog locales et compile les programmes vers
TNF.

`GNU Prolog`
: environnement d'exécution utilisé par CasLog.

`CiaoPP`
: effectue l'expansion des contrats source avant leur traduction en Prolog
exploitable.

Le dossier contient déjà les contrats d'exemple dans `data/source/`, CasLog dans
`tools/caslog/` et LogicTransformers/TNF dans `tools/LogicTransformers/`.

## 2. Installer les paquets Ubuntu

```bash
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-pip \
  swi-prolog gprolog \
  curl
```

Installer ensuite Ciao/CiaoPP :

```bash
curl https://ciao-lang.org/boot -sSfL | sh
```

Pour afficher les options du script officiel :

```bash
curl https://ciao-lang.org/boot -sSfL | sh -s -- --help
```

## 3. Vérifier l'installation

```bash
python3 --version
swipl --version
gprolog --version
ciaopp --version
```

Depuis le dossier du pipeline :

```bash
test -x tools/caslog/caslog.gprolog
test -f tools/LogicTransformers/tnf.pro
test -f tools/LogicTransformers/tnf.py
```

## 4. Premier lancement

Lancer un contrat court :

```bash
python3 pipeline.py blind_auction.pl
```

Résultat attendu :

- `build/executable/blind_auction.pl`
- `build/normalized/blind_auction.pl`
- `build/annotated/blind_auction.pl`
- `build/tnf_asm/blind_auction_asm.txt`
- fichiers de résultats dans `results/`

Pour lancer tous les contrats :

```bash
python3 pipeline.py
```

Pour vérifier seulement la transformation et CasLog, sans TNF :

```bash
python3 pipeline.py --no-tnf blind_auction.pl
```

Pour préparer `build/normalized/` puis lancer TNF seul :

```bash
python3 pipeline.py run --no-caslog --no-tnf blind_auction.pl
python3 pipeline.py run-tnf blind_auction
```

## 5. Documentation locale

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

## 6. Dépannage

`CiaoPP not found`
: vérifier que l'installation Ciao est terminée et que `ciaopp --version`
répond.

`CasLog not found`
: vérifier que `tools/caslog/caslog.gprolog` est présent et exécutable.

`No input files`
: vérifier que les contrats `.pl` sont présents dans `data/source/`.

`No TNF input files`
: lancer d'abord `python3 pipeline.py ...` pour produire `build/normalized/`.

`mkdocs: command not found`
: utiliser `.venv/bin/mkdocs` après installation des dépendances de
documentation.

## 7. Sources officielles

- Ciao install : <https://ciao-lang.org/install.html>
- Ciao detailed install : <https://ciao-lang.org/ciao/build/doc/ciao.html/Install.html>
- SWI-Prolog Ubuntu PPA : <https://www.swi-prolog.org/build/PPA.html>
- Paquet Ubuntu `swi-prolog` : <https://packages.ubuntu.com/swi-prolog>
- Paquet Ubuntu `gprolog` : <https://launchpad.net/ubuntu/noble/+package/gprolog>
