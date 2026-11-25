#!/usr/bin/env bash
set -u

OUT="full_bench_pi5.log"
: > "$OUT"

# 1. Lock CPU scaling governor to performance
echo "Setting CPU governor to performance..."
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true

# 2. Verify test20.csv correctness first (Short=3, Long=5)
echo "=========================================="
echo "=== CORRECTNESS CHECK: test20.csv ==="
echo "=========================================="
make clean && make test20 2>&1 || true
if [ -x ./bin/test20_stageA_engine ]; then
  sudo taskset -c 0 ./bin/test20_stageA_engine 2>&1 || true
fi

# 3. Stage 0 Microbenchmarks (parta_O0..O3, partb_O0..O3)
echo "=========================================="
echo "=== STAGE 0: MICROBENCHMARKS ==="
echo "=========================================="
for cfg in "-O0|" "-O1|" "-O2|" "-O3|" "-O3|-mcpu=cortex-a76"; do
  OPT_FLAG="${cfg%%|*}"
  CPU_FLAG="${cfg##*|}"
  echo "--- Stage 0 (${OPT_FLAG} ${CPU_FLAG}) ---"
  make clean && make OPT="$OPT_FLAG" CPU="$CPU_FLAG" stage0 2>&1 || true
  for s0bin in parta_O0 parta_O1 parta_O2 parta_O3 partb_O0 partb_O1 partb_O2 partb_O3; do
    if [ -x "./bin/$s0bin" ]; then
      echo ">>> Running $s0bin (${OPT_FLAG} ${CPU_FLAG}) <<<"
      sudo taskset -c 0 ./bin/"$s0bin" 2>&1 || true
      if command -v perf >/dev/null 2>&1; then
        sudo perf stat -r 3 -e task-clock,cycles,instructions,branches,branch-misses,cache-references,cache-misses           taskset -c 0 ./bin/"$s0bin" 2>&1 || true
      fi
    fi
  done
done

# 4. Full Suite Across All Flags (-O0, -O1, -O2, -O3, -O3 -mcpu=cortex-a76)
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

run_suite() {
  local opt="$1"
  local cpu="$2"
  echo "=========================================="
  echo "=== BUILDING SUITE: OPT=${opt} CPU=${cpu} ==="
  echo "=========================================="
  make clean && make OPT="$opt" CPU="$cpu" stageA stageA_plus stageB stageC_v0 stageC 2>&1

  for bin in "${ENGINES[@]}"; do
    if [ ! -x "./bin/$bin" ]; then
      echo "[SKIP] ./bin/$bin not built"
      continue
    fi

    echo "------------------------------------------"
    echo ">>> PI5 (${opt} ${cpu}): ${bin} <<<"
    echo "------------------------------------------"

    for i in 1 2 3 4 5; do
      echo "--- Trial $i ($opt $cpu, $bin) ---"
      if [ "$bin" = "stageC_engine" ]; then
        sudo taskset -c 0 ./bin/"$bin" 1000
      else
        sudo taskset -c 0 ./bin/"$bin"
      fi
    done

    if command -v perf >/dev/null 2>&1; then
      echo "--- perf stat ($opt $cpu, $bin) ---"
      if [ "$bin" = "stageC_engine" ]; then
        sudo perf stat -r 3 -e task-clock,cycles,instructions,branches,branch-misses,cache-references,cache-misses           taskset -c 0 ./bin/"$bin" 1000 2>&1 || true
      else
        sudo perf stat -r 3 -e task-clock,cycles,instructions,branches,branch-misses,cache-references,cache-misses           taskset -c 0 ./bin/"$bin" 2>&1 || true
      fi
    fi
  done
}

{
  echo "Host: $(uname -a)"
  echo "CPU: $(lscpu | grep -E 'Model name|Architecture|CPU\(s\)' | paste -sd ' | ' -)"
  echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
  echo ""

  run_suite "-O0" ""
  run_suite "-O1" ""
  run_suite "-O2" ""
  run_suite "-O3" ""
  run_suite "-O3" "-mcpu=cortex-a76"
} 2>&1 | tee -a "$OUT"

echo "Done! All outputs saved to $OUT"