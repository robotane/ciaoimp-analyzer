#!/usr/bin/env bash
# Usage: tools/caslog_prep/run.sh <contrat> [dossier_sortie]
#   <contrat> : nom d'un contrat de data/contracts_hotmoka (ex. gradual_ponzi)
# Écrit <sortie>/<contrat>_caslog.pl (entrée CasLog) et <contrat>_caslog.out (résultat CasLog).
# Un seul processus à la fois, mémoire limitée à 2 Go.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CONTRACTS="$ROOT/data/contracts_hotmoka"
CASLOG="${CASLOG:-/home/robotane/Projects/stage/tools/caslog/caslog.gprolog}"
name="$1"
out="$(mkdir -p "${2:-$ROOT/build/caslog_prep}" && cd "${2:-$ROOT/build/caslog_prep}" && pwd)"
cat > "$out/$name.in" <<EOT
use_module('$HERE/caslog_prep.pl').
module('$CONTRACTS/$name.pl').
caslog_prep('$out/${name}_caslog.pl', '$HERE/hotmoka_caslog_prims.pl').
halt.
EOT
(cd "$CONTRACTS" && ulimit -v 2000000 && timeout 180 ciaopp -T < "$out/$name.in" > "$out/$name.ciaopp.log" 2>&1)
(cd "$(dirname "$CASLOG")" && ulimit -v 2000000 && timeout 180 "./$(basename "$CASLOG")" "$out/${name}_caslog.pl" > "$out/${name}_caslog.out" 2>&1)
awk '/^ +[^ ]+\/[0-9]+ *$/{p=$1} /Time functions/{t=1;next} t && /^\[/{print p" : "$0; t=0} /rror/{print}' "$out/${name}_caslog.out"
