#!/bin/bash
# Measures the gas of the benchmark contracts through a real Hotmoka node started by the official
# moka CLI. See README.md. Usage: bench/mesurer.sh [options] ; bench/mesurer.sh --help
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERE="$ROOT/bench"
WORK="${MOKA_WORK:-$HERE/work}"
IMAGE="${MOKA_IMAGE:-hotmoka/mokamint-node:1.12.3}"
CONTAINER="${MOKA_CONTAINER:-wtsc-moka-node}"
CHAIN_ID="${MOKA_CHAIN_ID:-wtsc}"
PORT="${MOKA_PORT:-8001}"
JDK21="${JDK21:-${JAVA_HOME:-}}"
JAR="${WTSC_JAR:-$HERE/contracts/target/wtsc-contracts-1.0.jar}"
OUT="$ROOT/build/moka/bench_moka-$(date +%Y%m%d-%H%M%S).csv"
CONTRACTS="all"; N=100; RUNS=3; WARMUP=0; GAS=10000000
MODE="run"; KEEP=0

usage() {
	cat <<USAGE
Usage : $0 [options]
  --contracts a,b,c   sous-ensemble de contrats (defaut : tous), noms du CSV (simple_ponzi, example_coin, ...)
  --n N               taille maximale (defaut 100)
  --runs R            nombre d'executions enregistrees (defaut 3)
  --warmup W          executions de chauffe non enregistrees (defaut 0)
  --out FICHIER       CSV de sortie (defaut build/moka/bench_moka-<date>.csv, jamais ecrase)
  --jar FICHIER       jar des contrats (defaut bench/contracts/target/wtsc-contracts-1.0.jar)
  --gas LIMITE        limite de gaz par transaction (defaut 10000000, maximum du noeud)
  --verifier          controle croise : memes transactions par le pilote et par la CLI moka
  --keep-node         ne pas arreter le noeud a la fin
  --stop              arreter et supprimer le conteneur $CONTAINER, puis sortir
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
		--contracts) CONTRACTS="$2"; shift 2;;
		--n) N="$2"; shift 2;;
		--runs) RUNS="$2"; shift 2;;
		--warmup) WARMUP="$2"; shift 2;;
		--out) OUT="$(realpath -m "$2")"; shift 2;;
		--jar) JAR="$(realpath "$2")"; shift 2;;
		--gas) GAS="$2"; shift 2;;
		--verifier) MODE="verifier"; shift;;
		--keep-node) KEEP=1; shift;;
		--stop) MODE="stop"; shift;;
		-h|--help) usage; exit 0;;
		*) echo "option inconnue : $1" >&2; usage; exit 2;;
	esac
done

stop_node() {
	# seulement notre propre conteneur, retrouve par son nom exact
	if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
		docker stop "$CONTAINER" >/dev/null 2>&1 || true
		docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
		echo "[mesurer] conteneur $CONTAINER arrete"
	fi
}

if [ "$MODE" = stop ]; then stop_node; exit 0; fi

# commande moka (client) : conteneur ephemere, reseau hote, repertoire des cles monte
moka() {
	docker run --rm --memory=1g -e JAVA_TOOL_OPTIONS=-Xmx512m --network host --user "$(id -u):$(id -g)" \
		-v "$WORK:/work" -v "$(dirname "$JAR"):/jars:ro" -w /work/keys \
		--entrypoint "" "$IMAGE" moka "$@"
}

json_get() { python3 -I -c 'import sys,json
d=None
for l in sys.stdin.read().splitlines():
    l=l.strip()
    if l.startswith("{"):
        d=json.loads(l)
for k in sys.argv[1].split("."):
    d=d[k]
if isinstance(d,dict) and "progressive" in d: d="%s#%s" % (d["transaction"]["hash"], d["progressive"])
print(d)' "$1"; }

start_node() {
	stop_node
	mkdir -p "$WORK/keys"
	# etat de la chaine : toujours neuf (le dossier est le notre)
	if [ -d "$WORK/chain" ]; then rm -r "$WORK/chain"; fi
	if [ -d "$WORK/keys" ]; then rm -r "$WORK/keys"; fi
	mkdir -p "$WORK/keys"
	if [ ! -f "$WORK/takamaka.jar" ]; then
		docker run --rm --entrypoint "" "$IMAGE" cat /modules/explicit_or_automatic/io-takamaka-code-1.8.1.jar > "$WORK/takamaka.jar"
	fi
	local pub
	pub=$(moka keys create --json --name=gamete.pem --output-dir=/work/keys | json_get publicKeyBase58)
	# -i est indispensable : sans entree standard ouverte le noeud s'arrete aussitot
	docker run -d -i --name "$CONTAINER" --memory=2g -e JAVA_TOOL_OPTIONS=-Xmx1536m --network host --user "$(id -u):$(id -g)" \
		-v "$WORK:/work" -w /work --entrypoint "" "$IMAGE" \
		moka nodes disk init --yes --open-unsigned-faucet --ignore-gas-price \
		--chain-dir=/work/chain --chain-id="$CHAIN_ID" --port="$PORT" \
		--public-key-of-gamete="$pub" /work/takamaka.jar >/dev/null
	echo "[mesurer] attente du noeud (chain id '$CHAIN_ID', port $PORT)..."
	local i
	for i in $(seq 1 120); do
		if moka nodes manifest show --uri="ws://localhost:$PORT" >/dev/null 2>&1; then break; fi
		sleep 2
	done
	if [ "$i" = 120 ]; then
		echo "[mesurer] le noeud ne repond pas ; journal :" >&2
		docker logs "$CONTAINER" 2>&1 | tail -20 >&2
		return 1
	fi
	# le faucet est ouvert mais plafonne a 0 : on lie la cle de la gamete a son adresse puis on releve le plafond
	local gam
	gam=$(moka nodes manifest show --uri="ws://localhost:$PORT" | sed -n 's/.*gamete: \([0-9a-f]*#[0-9]*\).*/\1/p' | head -1)
	moka keys bind gamete.pem --reference "$gam" >/dev/null
	moka nodes faucet 1000000000000000 --dir=/work/keys --uri="ws://localhost:$PORT" >/dev/null
	echo "[mesurer] noeud pret (gamete $gam, faucet ouvert)"
}

make_account() {  # nom -> ecrit la reference dans stdout ; cle dans keys/<ref>.pem
	local name="$1"
	moka keys create --name="$name.pem" --output-dir=/work/keys >/dev/null
	moka accounts create faucet 1000000000000000 "$name.pem" --yes --json --output-dir=/work/keys --gas-limit=1000000 --gas-price=1 \
		--uri="ws://localhost:$PORT" | json_get account
}

install_jar() {  # payeur -> hash de la transaction du jar
	moka jars install --yes --json --dir=/work/keys --gas-limit=10000000 --gas-price=1 \
		--uri="ws://localhost:$PORT" "$1" "/jars/$(basename "$JAR")" | json_get transaction.hash
}

build_driver() {
	local D="$HERE/moka-driver"
	export JAVA_HOME="$JDK21"; export PATH="$JDK21/bin:$PATH"
	if [ ! -f "$D/target/moka-driver-1.0.jar" ] || [ -n "$(find "$D/src" "$D/pom.xml" -newer "$D/target/moka-driver-1.0.jar" -print -quit)" ]; then
		(cd "$D" && MAVEN_OPTS=-Xmx1g mvn -o -q -T1 package)
	fi
	if [ ! -f "$D/target/cp.txt" ]; then
		(cd "$D" && MAVEN_OPTS=-Xmx1g mvn -o -q -T1 org.apache.maven.plugins:maven-dependency-plugin:3.7.0:build-classpath -Dmdep.outputFile=target/cp.txt)
	fi
}

driver() {
	local D="$HERE/moka-driver"
	"$JDK21/bin/java" -Xmx1g --module-path "$(cat "$D/target/cp.txt"):$D/target/moka-driver-1.0.jar" \
		-m wtsc.moka.driver/wtsc.MokaBench "uri=ws://localhost:$PORT" "$@"
}

[ -f "$JAR" ] || { echo "jar introuvable : $JAR (mvn -o package dans bench/contracts/)" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker est requis" >&2; exit 1; }
[ -x "$JDK21/bin/java" ] || { echo "JDK 21 introuvable : '$JDK21' (variable JDK21 ou JAVA_HOME)" >&2; exit 1; }
avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
if [ "$avail" -lt 4096 ] && [ -z "${MOKA_IGNORE_MEM:-}" ]; then echo "memoire disponible ${avail} Mo < 4096 : attendre (MOKA_IGNORE_MEM=1 pour passer outre)" >&2; exit 3; fi
build_driver
mkdir -p "$(dirname "$OUT")"

if [ "$KEEP" = 0 ]; then trap stop_node EXIT; fi
trap 'exit 130' INT TERM

if [ "$MODE" = verifier ]; then
	# un seul noeud : la CLI cree les comptes et envoie la sequence, puis le pilote rejoue la meme sequence
	# avec les memes comptes (cles lues dans les .pem de moka). Meme comptes = meme ordre des references,
	# donc meme gaz attendu (le gaz depend de l'ordre des references dans les tables de stockage).
	VOUT="$WORK/verifier"; mkdir -p "$VOUT"
	start_node
	PAYER=$(make_account payer)
	CP=$(install_jar "$PAYER")
	echo "[verifier] 1/2 CLI moka"
	"$HERE/verifier_cli.sh" "$CP" "$WORK" "$IMAGE" "$PORT" "$(dirname "$JAR")" > "$VOUT/cli.txt" 2>&1
	cat "$VOUT/cli.txt"
	ACCS=$(sed -n 's/^ACCOUNTS=//p' "$VOUT/cli.txt")
	echo "[verifier] 2/2 pilote Java (memes comptes)"
	rm -f "$VOUT/pilote.csv"
	driver "classpath=$CP" only=check "out=$VOUT/pilote.csv" gas=1000000 "accounts=$ACCS" "keys=$WORK/keys" 2>&1 | grep '^CHECK' | tee "$VOUT/pilote.txt"
	python3 -I "$HERE/comparer_verifier.py" "$VOUT/pilote.txt" "$VOUT/cli.txt"
	exit 0
fi

start_node
PAYER=$(make_account payer)
echo "[mesurer] compte payeur : $PAYER"
CP=$(install_jar "$PAYER")
echo "[mesurer] jar installe : $CP"
echo "[mesurer] mesures -> $OUT"
driver "classpath=$CP" "out=$OUT" "contracts=$CONTRACTS" "n=$N" "runs=$RUNS" "warmup=$WARMUP" "gas=$GAS"
echo "[mesurer] termine : $(($(wc -l < "$OUT") - 1)) points dans $OUT"
