#!/usr/bin/env bash
# Usage: caslog_prep/run.sh <contract> [output_dir]
#   <contract>: name of a contract of dsl/ (e.g. gradual_ponzi)
# Writes <output_dir>/<contract>_caslog.pl (CasLog input) and <contract>_caslog.out (CasLog output).
# One process at a time, memory capped at 2 GB. CASLOG: path of CasLog's caslog.gprolog (required).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CONTRACTS="$ROOT/dsl"
: "${CASLOG:?set CASLOG to the path of caslog.gprolog (see README.md)}"
CASLOG="$(realpath "$CASLOG")"
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
