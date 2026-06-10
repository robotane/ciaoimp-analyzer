#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/.build-script"
OUTPUT_JAR="${ROOT_DIR}/plcafe.jar"
BOOTSTRAP_JAR="${ROOT_DIR}/plcafe.jar"
KEEP_BUILD=0
CLEAN_ONLY=0

usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

Build Prolog Cafe without Bazel by running:
  1. SWI-Prolog source generation
  2. javac compilation
  3. jar assembly

Options:
  --build-dir DIR   Override the working build directory
  --output FILE     Override the output jar path
  --bootstrap FILE  Seed compilation/assembly from an existing plcafe.jar
  --no-bootstrap    Build only from generated/manual sources
  --keep-build      Keep generated files under the build directory
  --clean           Remove the build directory and exit
  -h, --help        Show this message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_JAR="$2"
      shift 2
      ;;
    --bootstrap)
      BOOTSTRAP_JAR="$2"
      shift 2
      ;;
    --no-bootstrap)
      BOOTSTRAP_JAR=""
      shift
      ;;
    --keep-build)
      KEEP_BUILD=1
      shift
      ;;
    --clean)
      CLEAN_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}

require_tool swipl
require_tool javac
require_tool jar

if [[ ${CLEAN_ONLY} -eq 1 ]]; then
  rm -rf "${BUILD_DIR}"
  exit 0
fi

if [[ ${KEEP_BUILD} -eq 0 ]]; then
  trap 'rm -rf "${BUILD_DIR}"' EXIT
fi

SRC_DIR="${ROOT_DIR}/src"
GEN_SRC_DIR="${BUILD_DIR}/generated-src"
CLASS_DIR="${BUILD_DIR}/classes"
WORK_DIR="${BUILD_DIR}/work"
ASSEMBLE_DIR="${BUILD_DIR}/assemble"

rm -rf "${BUILD_DIR}"
mkdir -p "${GEN_SRC_DIR}" "${CLASS_DIR}" "${WORK_DIR}" "${ASSEMBLE_DIR}"

run_swipl() {
  local goal_file="$1"
  swipl --traditional --quiet -g go,halt -t 'halt(1)' "${goal_file}"
}

generate_pl2j() {
  local source_rel="$1"
  local stem="$2"
  local am_file="${WORK_DIR}/${stem}.am"
  local java_dir="${GEN_SRC_DIR}/${stem}"
  local pl2am_goal="${WORK_DIR}/${stem}_pl2am.go"
  local am2j_goal="${WORK_DIR}/${stem}_am2j.go"

  mkdir -p "${java_dir}"

  cat >"${pl2am_goal}" <<EOF
go :-
  load_files([
    '${SRC_DIR}/compiler/package_fx.pl',
    '${SRC_DIR}/builtin/system.pl',
    '${SRC_DIR}/compiler/pl2am.pl'
  ]),
  pl2am(['$(basename "${source_rel}")', '${am_file}', [ed,ac,ie,rc,idx]]).
EOF

  (
    cd "$(dirname "${SRC_DIR}/${source_rel}")"
    run_swipl "${pl2am_goal}"
  )

  cat >"${am2j_goal}" <<EOF
go :-
  load_files(['${SRC_DIR}/compiler/am2j.pl']),
  am2j(['${am_file}', '${java_dir}']).
EOF

  (
    cd "${ROOT_DIR}"
    run_swipl "${am2j_goal}"
  )
}

echo "==> Generating Java sources from Prolog"
generate_pl2j "builtin/builtins.pl" "builtins"
generate_pl2j "builtin/system.pl" "system"
generate_pl2j "builtin/io.pl" "io"
generate_pl2j "builtin/cafeteria.pl" "cafeteria"
generate_pl2j "compiler/pl2am.pl" "pl2am"
generate_pl2j "compiler/am2j.pl" "am2j"

SOURCE_LIST="${WORK_DIR}/sources.list"
{
  find "${SRC_DIR}/exceptions" -type f -name '*.java' | sort
  find "${SRC_DIR}/lang" -type f -name '*.java' | sort
  find "${SRC_DIR}/builtin" -type f -name '*.java' | sort
  find "${SRC_DIR}/compiler" -maxdepth 1 -type f -name '*.java' | sort
  find "${SRC_DIR}/compiler/am2j" -type f -name '*.java' \
    ! -name 'PRED_package_encoding_3.java' \
    ! -name 'PRED_pred_encoding_3.java' | sort
  find "${SRC_DIR}/repl" -type f -name '*.java' | sort
  find "${GEN_SRC_DIR}" -type f -name '*.java' | sort
} > "${SOURCE_LIST}"

echo "==> Compiling Java sources"
JAVAC_ARGS=()
if [[ -n "${BOOTSTRAP_JAR}" && -f "${BOOTSTRAP_JAR}" ]]; then
  JAVAC_ARGS+=(-classpath "${BOOTSTRAP_JAR}")
fi
if javac --help >/dev/null 2>&1; then
  if javac --help 2>/dev/null | grep -q -- '--release'; then
    javac --release 8 "${JAVAC_ARGS[@]}" -d "${CLASS_DIR}" @"${SOURCE_LIST}"
  else
    javac -source 1.8 -target 1.8 "${JAVAC_ARGS[@]}" -d "${CLASS_DIR}" @"${SOURCE_LIST}"
  fi
else
  javac -source 1.8 -target 1.8 "${JAVAC_ARGS[@]}" -d "${CLASS_DIR}" @"${SOURCE_LIST}"
fi

mkdir -p "${ASSEMBLE_DIR}/META-INF"
if [[ -n "${BOOTSTRAP_JAR}" && -f "${BOOTSTRAP_JAR}" ]]; then
  echo "==> Seeding assembly from ${BOOTSTRAP_JAR}"
  (
    cd "${ASSEMBLE_DIR}"
    jar xf "${BOOTSTRAP_JAR}"
  )
fi

cat >"${ASSEMBLE_DIR}/META-INF/MANIFEST.MF" <<'EOF'
Manifest-Version: 1.0
Created-By: build.sh

EOF
cat >"${ASSEMBLE_DIR}/build-data.properties" <<'EOF'
name=prolog-cafe
builder=build.sh
EOF

cp -R "${CLASS_DIR}/." "${ASSEMBLE_DIR}/"

mkdir -p "$(dirname "${OUTPUT_JAR}")"
rm -f "${OUTPUT_JAR}"

echo "==> Assembling ${OUTPUT_JAR}"
(
  cd "${ASSEMBLE_DIR}"
  jar cfm "${OUTPUT_JAR}" META-INF/MANIFEST.MF .
)

echo "Build complete: ${OUTPUT_JAR}"
if [[ ${KEEP_BUILD} -eq 1 ]]; then
  echo "Retained build directory: ${BUILD_DIR}"
fi
