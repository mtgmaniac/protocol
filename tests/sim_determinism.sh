#!/usr/bin/env bash
# Balance-sim determinism gate (Package A.5): same seed + same config must
# produce BYTE-IDENTICAL JSONL. Runs the headless sim twice and compares.
#
# Covers a small CONFIG MATRIX, not one config: facility/pulse,combat,shield
# never fires the global-RNG branches (summon randi_range, Overflow Vent /
# Dead Man's Charge randi), so a single config would miss a whole class of
# non-determinism (it did — sim-E caught it via broad batches). The second
# config is summon-heavy (voidCirclet Synod) with a different squad.
#
# Usage:   tests/sim_determinism.sh [seed]
# Godot:   override the binary with  GODOT=/path/to/godot  tests/sim_determinism.sh
set -euo pipefail

GODOT="${GODOT:-C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe}"
SCENE="res://scenes/sim/sim_main.tscn"
SEED="${1:-12345}"
OUT_DIR="results/determinism"
mkdir -p "${OUT_DIR}"

# name:squad:op config matrix.
CONFIGS=(
	"facility:pulse,combat,shield:facility"
	"synod:medic,ghost,breaker:voidCirclet"
)

for CONFIG in "${CONFIGS[@]}"; do
	IFS=':' read -r NAME SQUAD OP <<< "${CONFIG}"
	ARGS="--seed ${SEED} --squad ${SQUAD} --op ${OP}"
	# Every policy has its own seeded decision stream — cover them all (B.2).
	for POLICY in stub l0 l1 l2; do
		A="${OUT_DIR}/seed_${SEED}_${NAME}_${POLICY}_a.jsonl"
		B="${OUT_DIR}/seed_${SEED}_${NAME}_${POLICY}_b.jsonl"
		"${GODOT}" --headless --path . "${SCENE}" -- ${ARGS} --policy "${POLICY}" --out "${A}" >/dev/null 2>&1
		"${GODOT}" --headless --path . "${SCENE}" -- ${ARGS} --policy "${POLICY}" --out "${B}" >/dev/null 2>&1
		if cmp -s "${A}" "${B}"; then
			echo "[DETERMINISM] PASS — seed ${SEED} ${NAME}/${POLICY} byte-identical ($(wc -l < "${A}") lines)"
		else
			echo "[DETERMINISM] FAIL — seed ${SEED} ${NAME}/${POLICY} differs:"
			diff "${A}" "${B}" | head -20
			exit 1
		fi
	done
done
exit 0
