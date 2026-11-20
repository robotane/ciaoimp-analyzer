#!/bin/bash
# Memes transactions que "mesurer.sh --verifier" (pilote), envoyees une par une avec la CLI moka.
# Arguments : <hash du jar> <repertoire de travail> <image> <port> <repertoire du jar>
# Sortie : lignes "CHECK <etiquette> cpu=.. ram=.. storage=.."
set -euo pipefail
CP="$1"; WORK="$2"; IMAGE="$3"; PORT="$4"; JARDIR="$5"
URI="ws://localhost:$PORT"
M() { docker run --rm --memory=1g -e JAVA_TOOL_OPTIONS=-Xmx512m --network host --user "$(id -u):$(id -g)" -v "$WORK:/work" -v "$JARDIR:/jars:ro" -w /work/keys --entrypoint "" "$IMAGE" moka "$@"; }
parse() {  # etiquette ; lit la sortie json de moka sur stdin, imprime la ligne CHECK, puis la reference de l'objet ou du compte
	python3 -I -c 'import sys,json
lab=sys.argv[1]; d=None
for l in sys.stdin.read().splitlines():
    if l.strip().startswith("{"): d=json.loads(l)
g=d["gasCost"]
print("CHECK %s cpu=%s ram=%s storage=%s" % (lab,g["forCPU"],g["forRAM"],g["forStorage"]), file=sys.stderr)
if "account" in d: print("%s#%s" % (d["account"]["transaction"]["hash"], d["account"]["progressive"]))
elif "object" in d: print("%s#%s" % (d["object"]["transaction"]["hash"], d["object"]["progressive"]))
else: print("")' "$1"
}
G="--yes --json --dir=/work/keys --gas-price=1 --gas-limit=1000000 --uri=$URI"
declare -a ACC
for i in 0 1 2 3; do
	M keys create --name="v$i.pem" --output-dir=/work/keys >/dev/null
	ACC[$i]=$(M accounts create faucet 1000000000000000 "v$i.pem" --yes --json --output-dir=/work/keys --gas-price=1 --gas-limit=1000000 --uri="$URI" | parse "account_create$i")
done
echo "ACCOUNTS=$(IFS=,; echo "${ACC[*]}")"
CC="--classpath=$CP"
SP=io.hotmoka.examples.ponzi.SimplePonzi
P=$(M objects create $G $CC "${ACC[0]}" $SP | parse ponzi_create)
k=1
for amt in 1000 2000 3000; do
	M objects call $G $CC --receiver="$P" "${ACC[$k]}" $SP invest $amt | parse "ponzi_invest$k" >/dev/null
	k=$((k+1))
done
EC=io.hotmoka.examples.tokens.ExampleCoin
UBI=io.takamaka.code.math.UnsignedBigInteger
COIN=$(M objects create $G $CC "${ACC[0]}" $EC | parse coin_create)
U=$(M objects create $G $CC --selection=4 "${ACC[0]}" $UBI 1000 | parse ubi1000_create)
M objects call $G $CC --receiver="$COIN" --selection=2 "${ACC[0]}" $EC transfer "${ACC[1]}" "$U" | parse coin_transfer1 >/dev/null
M objects call $G $CC --receiver="$COIN" --selection=2 "${ACC[0]}" $EC transfer "${ACC[2]}" "$U" | parse coin_transfer2 >/dev/null
