#!/bin/sh
set -eu
speeds="1000"
optimizations="-O2 -O3"
verbose=0
counters=1
extra_flags="-DSTAGEC_SCALED_SIGNAL=1"

if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [rounds]\n' "$0" >&2
    exit 1
fi
case "${1-1}" in
    ''|*[!0-9]*)
        printf 'Rounds must be a positive integer.\n' >&2
        exit 1 ;;
esac

case "$optimizations" in
    *[![:space:]]*) ;;
    *) printf 'Select -O2, -O3, or both in the optimizations list.\n' >&2; exit 1 ;;
esac

export LC_ALL=C
if ! rounds=$(awk -v input="${1-1}" 'BEGIN {
    if (input < 1 || input > 2147483647) exit 1
    printf "%.0f\n", input
}'); then
    printf 'Rounds must be a positive integer no greater than 2147483647.\n' >&2
    exit 1
fi

stage_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$stage_dir")
report="$stage_dir/stageC_perf_results_pi_opt.md"
work_dir=$(mktemp -d "$stage_dir/.stageC-perf.XXXXXX")
benchmark="$work_dir/benchmark.out"
trap 'rm -f -- "$benchmark" "$work_dir/report.md" "$work_dir/rivals" "$work_dir/stdout" "$work_dir/status" "$work_dir/counters" "$work_dir/errors"; rmdir -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

cd "$project_dir"

have_perf=0
counter_note='Hardware counters are disabled for this run.'
if [ "$counters" -eq 1 ]; then
    counter_note='Linux perf is unavailable on this host.'
    if command -v perf >/dev/null 2>&1; then
        have_perf=1
        counter_note=''
    fi
fi

cat > "$work_dir/report.md" <<'EOF'
# Optimized Stage C performance on Raspberry Pi

EOF
printf 'Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `%s`. Optimization levels `%s`.\n' \
    "-std=c17 -mcpu=cortex-a76 -Wall -Wextra -Werror -D_POSIX_C_SOURCE=200809L $extra_flags" "$optimizations" >> "$work_dir/report.md"
cat >> "$work_dir/report.md" <<'EOF'

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

`perf stat` measures the whole user-space command, including CSV loading. IPC is instructions divided by cycles.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) | Cycles | Instructions | IPC | Cache misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
EOF
cat > "$work_dir/rivals" <<'EOF'

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
EOF

for optimization in $optimizations; do
    case "$optimization" in
        -O2|-O3) ;;
        *) printf 'Select -O2, -O3, or both in the optimizations list.\n' >&2; exit 1 ;;
    esac

    printf '[Stage C] Compiling with GCC %s -mcpu=cortex-a76.\n' "$optimization" >&2
    gcc -std=c17 "$optimization" -mcpu=cortex-a76 -Wall -Wextra -Werror -D_POSIX_C_SOURCE=200809L $extra_flags -Icommon \
        "$stage_dir/main_stageC_perf_opt.c" common/fast_reader.c "$stage_dir/signal_opt.c" -o "$benchmark"

    for speed in $speeds; do
        round=1
        while [ "$round" -le "$rounds" ]; do
            printf '[Stage C] Running %s at %sx, round %s.\n' "$optimization" "$speed" "$round" >&2
            : > "$work_dir/counters"
            result=0
            if [ "$have_perf" -eq 1 ]; then
                rm -f -- "$work_dir/status"
                # Use the benchmark status when perf successfully launched its wrapper.
                if ! perf stat -x ';' -o "$work_dir/counters" -e cycles:u,instructions:u,cache-misses:u -- \
                    sh -c 'printf "started\n" > "$1" || exit 1; result=0; "$2" "$3" 2>&3 3>&- || result=$?; printf "%s\n" "$result" > "$1"; exit "$result"' \
                    perf-benchmark "$work_dir/status" "$benchmark" "$speed" \
                    3>&2 > "$work_dir/stdout" 2> "$work_dir/errors"; then
                    cat "$work_dir/errors" >&2
                fi
                if [ -e "$work_dir/status" ]; then
                    result=$(cat "$work_dir/status")
                else
                    have_perf=0
                    counter_note='Linux perf could not launch Stage C. This and subsequent runs used elapsed timing.'
                    printf '%s\n' "$counter_note" >&2
                    : > "$work_dir/counters"
                fi
            fi
            if [ "$have_perf" -eq 0 ]; then
                "$benchmark" "$speed" > "$work_dir/stdout" || result=$?
            fi
            if [ "$result" != 0 ]; then
                cat "$work_dir/stdout" >&2
                printf 'Stage C %s failed at %sx, round %s (status %s).\n' "$optimization" "$speed" "$round" "$result" >&2
                exit 1
            fi

            if ! awk -F '\t' -v optimization="$optimization" -v speed="$speed" -v round="$round" -v verbose="$verbose" \
                -v report="$work_dir/report.md" -v rivals="$work_dir/rivals" '
                BEGIN {
                    expected = split("0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0", thresholds, " ")
                    for (i = 1; i <= expected; i++) allowed[thresholds[i]] = 1
                }
                function counter(event) { return (event in count) ? count[event] : "N/A" }
                FILENAME == ARGV[1] {
                    split($0, fields, ";")
                    if (fields[3] ~ /^(cycles|instructions|cache-misses)(:u)?$/ &&
                        fields[1] ~ /^[0-9]+(\.[0-9]+)?$/) {
                        sub(/:u$/, "", fields[3])
                        count[fields[3]] = fields[1]
                    }
                    next
                }
                { sub(/\r$/, "", $0) }
                /^stageC_perf\t/ {
                    if (++replay_count != 1 || NF != 8 || ("s" $2) != ("s" speed) ||
                        $3 !~ /^[1-9][0-9]*$/ || $4 !~ /^[0-9]+$/ || $5 !~ /^[0-9]+$/ ||
                        $6 !~ /^[0-9]+\.[0-9][0-9]$/ || $7 !~ /^[0-9]+$/ || $8 !~ /^[0-9]+$/) {
                        invalid = 1
                        next
                    }
                    replay_row = sprintf("| %s | %s | %s | %s | %s | %s | %s | %s | %s |",
                        optimization, round, speed, $3, $4, $5, $6, $7, $8)
                    next
                }
                /^stageC_rival\t/ {
                    if (NF != 5 || !($2 in allowed) || ($2 in rival_rows) ||
                        $3 !~ /^-?[0-9]+\.[0-9][0-9]$/ || $4 !~ /^[0-9]+$/ || $5 !~ /^[0-9]+$/) {
                        invalid = 1
                        next
                    }
                    rival_count++
                    rival_rows[$2] = sprintf("| %s | %s | %s | %s | %s | %s | %s |", optimization, round, speed, $2, $3, $4, $5)
                    next
                }
                verbose { print }
                END {
                    if (invalid || replay_count != 1 || rival_count != expected) exit 1
                    ipc = "N/A"
                    if (("cycles" in count) && count["cycles"] > 0 && ("instructions" in count)) {
                        ipc = sprintf("%.3f", count["instructions"] / count["cycles"])
                    }
                    printf "%s %s | %s | %s | %s |\n", replay_row,
                        counter("cycles"), counter("instructions"), ipc, counter("cache-misses") >> report
                    for (i = 1; i <= expected; i++) print rival_rows[thresholds[i]] >> rivals
                }
            ' "$work_dir/counters" "$work_dir/stdout"; then
                if [ "$verbose" -eq 0 ]; then
                    cat "$work_dir/stdout" >&2
                fi
                printf 'Invalid benchmark output for %s at %sx, round %s.\n' "$optimization" "$speed" "$round" >&2
                exit 1
            fi
            round=$((round + 1))
        done
    done
done

cat "$work_dir/rivals" >> "$work_dir/report.md"
if [ -n "$counter_note" ]; then
    printf '\n%s\n' "$counter_note" >> "$work_dir/report.md"
fi
mv -f -- "$work_dir/report.md" "$report"
printf 'Saved %s\n' "$report"
