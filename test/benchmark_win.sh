#!/usr/bin/env bash
set -u

OUT="full_bench_win.log"
: > "$OUT"

MAKE_CMD="make"
command -v make >/dev/null 2>&1 || MAKE_CMD="mingw32-make"

{
  echo "=========================================="
  echo "=== WINDOWS BENCHMARK SUITE (CSC1103) ==="
  echo "=========================================="
  uname -a
  gcc --version | head -n 1
  echo ""

  echo "=========================================="
  echo "=== CORRECTNESS CHECK: test20.csv ==="
  echo "=========================================="
  "$MAKE_CMD" clean && "$MAKE_CMD" test20 2>&1 || true
  if [ -x ./bin/test20_stageA_engine.exe ]; then
    ./bin/test20_stageA_engine.exe 2>&1 || true
  elif [ -x ./bin/test20_stageA_engine ]; then
    ./bin/test20_stageA_engine 2>&1 || true
  fi

  echo "=========================================="
  echo "=== STAGE 0: MICROBENCHMARKS ==="
  echo "=========================================="
  for OPT_FLAG in -O0 -O1 -O2 -O3; do
    echo "--- Stage 0 (${OPT_FLAG}) ---"
    "$MAKE_CMD" clean && "$MAKE_CMD" OPT="$OPT_FLAG" stage0 2>&1 || true
    for s0bin in parta_O0 parta_O1 parta_O2 parta_O3; do
      if [ -f "./bin/${s0bin}.exe" ] || [ -x "./bin/$s0bin" ]; then
        echo ">>> Running $s0bin (${OPT_FLAG}) with N=100000000 <<<"
        echo 100000000 | ./bin/"$s0bin" 2>&1 || true
      fi
    done
    for s0bin in partb_O0 partb_O1 partb_O2 partb_O3; do
      if [ -f "./bin/${s0bin}.exe" ] || [ -x "./bin/$s0bin" ]; then
        echo ">>> Running $s0bin (${OPT_FLAG}) <<<"
        ./bin/"$s0bin" 2>&1 || true
      fi
    done
  done

  ENGINES=(
    stageA_engine
    stageA_plus_engine
    stageB_naive_engine
    stageB_running_engine
    stageB_fp_engine
    stageB_malloc_engine
    stageC_v0_engine
    stageC_engine
  )

  for OPT_FLAG in -O0 -O1 -O2 -O3; do
    echo "=========================================="
    echo "=== BUILDING SUITE: OPT=${OPT_FLAG} ==="
    echo "=========================================="
    "$MAKE_CMD" clean && "$MAKE_CMD" OPT="$OPT_FLAG" stageA stageA_plus stageB stageC_v0 stageC 2>&1 || true

    for bin in "${ENGINES[@]}"; do
      if [ ! -f "./bin/${bin}.exe" ] && [ ! -x "./bin/$bin" ]; then
        echo "[SKIP] ./bin/$bin not built"
        continue
      fi

      echo "------------------------------------------"
      echo ">>> WINDOWS (${OPT_FLAG}): ${bin} <<<"
      echo "------------------------------------------"

      for i in 1 2 3 4 5; do
        echo "--- Trial $i ($OPT_FLAG, $bin) ---"
        if [ "$bin" = "stageC_engine" ]; then
          ./bin/"$bin" 1000 2>&1 || true
        else
          ./bin/"$bin" 2>&1 || true
        fi
      done
    done
  done
} 2>&1 | tee -a "$OUT"

echo "Done! All outputs saved to $OUT"
