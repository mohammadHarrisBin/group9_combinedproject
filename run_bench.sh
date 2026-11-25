#!/usr/bin/env bash
set -u

ARCH="$(uname -m)"
IS_PI=0
if [ -f /proc/device-tree/model ] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
    IS_PI=1
fi

if [ "$IS_PI" -eq 1 ]; then
    HOST_TAG="pi5"
    BASE_CPU=""
    TUNED_CPU="-mcpu=cortex-a76"
else
    HOST_TAG="wsl_${ARCH}"
    BASE_CPU="-march=native"
    TUNED_CPU="-march=native"
fi

OUT_DIR="bench_results/${HOST_TAG}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

{
    echo "=== SYSTEM SETUP ($HOST_TAG) ==="
    if [ "$IS_PI" -eq 1 ]; then
        echo -n "Pi Model: "
        tr -d '\0' < /proc/device-tree/model
        echo ""
    fi
    uname -a
    lscpu 2>/dev/null | grep -E "Model name|Architecture|CPU\(s\)|Thread|Core|MHz|cache|Model" || true
    gcc --version | head -n 1
    if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    else
        echo "CPU Governor: N/A (virtualized/WSL or no cpufreq sysfs)"
    fi
} | tee "$OUT_DIR/system_setup.txt"

PLOT_TARGETS="plot_stageA plot_stageA_plus plot_stageB_naive plot_stageB_running plot_stageB_fp plot_stageB_malloc plot_stageC_v0 plot_stageC"
ENGINES="stageA_engine stageA_plus_engine stageB_naive_engine stageB_running_engine stageB_fp_engine stageB_malloc_engine stageC_v0_engine stageC_engine"

run_perf_and_time() {
    local bin_name="$1"
    local arg="$2"
    local out_file="$3"

    {
        echo "=========================================="
        echo "BINARY: ./bin/$bin_name $arg"
        echo "=========================================="
        if command -v perf >/dev/null 2>&1; then
            if command -v /usr/bin/time >/dev/null 2>&1; then
                /usr/bin/time -v perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses \
                    ./bin/"$bin_name" $arg 2>&1
            else
                perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses \
                    ./bin/"$bin_name" $arg 2>&1
            fi
        else
            echo "[perf not installed — falling back to /usr/bin/time -v]"
            if command -v /usr/bin/time >/dev/null 2>&1; then
                /usr/bin/time -v ./bin/"$bin_name" $arg 2>&1
            else
                time ./bin/"$bin_name" $arg 2>&1
            fi
        fi
    } >> "$out_file"
}

# 1. Sweep -O0, -O1, -O2, -O3
for OPT_FLAG in -O0 -O1 -O2 -O3; do
    LVL="${OPT_FLAG#-}"
    RUN_DIR="$OUT_DIR/$LVL"
    mkdir -p "$RUN_DIR/plots"

    echo ">>> [$HOST_TAG] Building with OPT=$OPT_FLAG CPU=\"$BASE_CPU\" <<<"
    make clean > "$RUN_DIR/build_${LVL}.log" 2>&1
    make all OPT="$OPT_FLAG" CPU="$BASE_CPU" >> "$RUN_DIR/build_${LVL}.log" 2>&1

    for tgt in $PLOT_TARGETS; do
        echo "  Running $tgt ($OPT_FLAG)..."
        make "$tgt" OPT="$OPT_FLAG" CPU="$BASE_CPU" > "$RUN_DIR/${tgt}.log" 2>&1 || true
    done

    cp -f plots/* "$RUN_DIR/plots/" 2>/dev/null || true

    : > "$RUN_DIR/perf_and_mem.txt"
    for eng in $ENGINES; do
        if [ -x "./bin/$eng" ]; then
            arg=""
            [ "$eng" = "stageC_engine" ] && arg="1000"
            run_perf_and_time "$eng" "$arg" "$RUN_DIR/perf_and_mem.txt"
        fi
    done
done

# 2. Extra Tuned Run (-O3 + TUNED_CPU) & Replay Speed Sweep (10x, 100x, 1000x)
TUNED_DIR="$OUT_DIR/O3_tuned"
mkdir -p "$TUNED_DIR/plots"

echo ">>> [$HOST_TAG] Building tuned OPT=-O3 CPU=\"$TUNED_CPU\" <<<"
make clean > "$TUNED_DIR/build_tuned.log" 2>&1
make all OPT="-O3" CPU="$TUNED_CPU" >> "$TUNED_DIR/build_tuned.log" 2>&1

for tgt in plot_stageB_running plot_stageC_v0 plot_stageC; do
    make "$tgt" OPT="-O3" CPU="$TUNED_CPU" > "$TUNED_DIR/${tgt}.log" 2>&1 || true
done
cp -f plots/* "$TUNED_DIR/plots/" 2>/dev/null || true

: > "$TUNED_DIR/perf_and_mem.txt"
for eng in stageB_naive_engine stageB_running_engine stageB_fp_engine stageB_malloc_engine stageC_v0_engine; do
    if [ -x "./bin/$eng" ]; then
        run_perf_and_time "$eng" "" "$TUNED_DIR/perf_and_mem.txt"
    fi
done

# Replay speed sweep (10x, 100x, 1000x; add 1 before 10 if you want real-time 1x too)
for spd in 10 100 1000; do
    echo "  Running stageC_engine at ${spd}x speed..."
    run_perf_and_time "stageC_engine" "$spd" "$TUNED_DIR/stageC_replay_${spd}x.log"
done

echo "=========================================="
echo "FINISHED! Results saved in: $OUT_DIR"
echo "=========================================="