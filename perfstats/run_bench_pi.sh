#!/usr/bin/env bash
set -u

OUT="02-median_pi5"
: > "$OUT"

ENGINES=(
  stageA_engine
  stageA_plus_engine
  stageB_naive_engine
  stageB_running_engine
  stageB_fp_engine
  stageB_malloc_engine
  stageC_engine
)
DATA="Datasets/Group09/stress_full.csv"

echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true

run_suite() {
  local opt="$1"
  make clean && make OPT="$opt" stageA stageA_plus stageB stageC

  for bin in "${ENGINES[@]}"; do
    echo "=========================================="
    echo "=== PI5 (${opt}): ${bin} ==="
    echo "=========================================="

    for i in 1 2 3 4 5; do
      echo "--- Trial $i ($opt, $bin) ---"
      sudo taskset -c 0 ./bin/"$bin" "$DATA"
    done

    if command -v perf >/dev/null 2>&1; then
      echo "--- perf stat ($opt, $bin) ---"
      sudo perf stat -r 5 -e task-clock,cycles,instructions,branches,branch-misses,cache-references,cache-misses \
        taskset -c 0 ./bin/"$bin" "$DATA" 2>&1 || true
    fi

    echo "--- AArch64 Assembly ($opt, $bin) ---"
    objdump -d -S -C ./bin/"$bin" | awk '
      /<main>|<(stage|calc|sma|vwap|ohlc|signal|parse|med|alloc|init|step|run)[a-zA-Z0-9_]*>:/ { printing=1; print ""; print $0; next }
      /^$/ { if (printing) { print ""; printing=0 }; next }
      { if (printing) print $0 }
    ' | head -n 160
  done
}

{
  echo "Host: $(uname -a)"
  echo "CPU: $(lscpu | grep -E 'Model name|Architecture|CPU\(s\)' | paste -sd ' | ' -)"
  echo ""
  run_suite "-O0"
  run_suite "-O2"
} 2>&1 | tee -a "$OUT"