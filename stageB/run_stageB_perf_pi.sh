#!/bin/sh
set -eu

export LC_ALL=C
stage_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$stage_dir")
report="$stage_dir/stageB_perf_results_pi.md"

work_dir=$(mktemp -d "$stage_dir/.stageB-perf.XXXXXX")
trap 'rm -f -- "$work_dir/benchmark.out" "$work_dir/report.md" "$work_dir/stdout" "$work_dir/status" "$work_dir/counters" "$work_dir/errors"; rmdir -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

cd "$project_dir"
benchmark="$work_dir/benchmark.out"
have_perf=0
counter_note='Linux perf is unavailable on this host.'
if command -v perf >/dev/null 2>&1; then
    have_perf=1
    counter_note=''
fi

expected_config=''
trade_count=''
for variant in NAIVE RUNNING FIXEDPOINT MALLOC; do
    case "$variant" in
        NAIVE) name='Static naive'; source=main_stageB_perf_naive.c ;;
        RUNNING) name='Static running sum'; source=main_stageB_perf_running.c ;;
        FIXEDPOINT) name='Fixed-point running sum'; source=main_stageB_perf_fixedpoint.c ;;
        MALLOC) name='Heap naive'; source=main_stageB_perf_malloc.c ;;
    esac
    printf '[Stage B %s] Compiling with -O2 -mcpu=cortex-a76.\n' "$variant" >&2
    gcc -std=c17 -O2 -mcpu=cortex-a76 -Wall -Wextra -Werror -Icommon -Iindicators \
        "$stage_dir/$source" common/fast_reader.c indicators/vwap.c \
        indicators/ohlc.c indicators/sma.c indicators/signal.c -o "$benchmark"

    config=$("$benchmark" --config)
    if [ -z "$expected_config" ]; then
        expected_config=$config
        if ! fields=$(printf '%s\n' "$config" | awk -F '\t' '
            NR == 1 && NF == 5 && $1 ~ /^(TEST20|DEV|STRESS)$/ &&
                $2 ~ /^[1-9][0-9]*$/ && $3 ~ /^[1-9][0-9]*$/ &&
                $4 ~ /^[1-9][0-9]*$/ && $5 ~ /^[1-9][0-9]*$/ { print $1, $2, $3, $4, $5; next }
            { exit 1 }
            END { if (NR != 1) exit 1 }
        '); then
            printf 'Invalid benchmark configuration for %s.\n' "$variant" >&2
            exit 1
        fi
        read -r dataset rounds passes short long <<EOF
$fields
EOF
        {
            printf '# Stage B performance on Raspberry Pi\n\n'
            printf 'Dataset %s, SMA windows %s/%s, GCC -O2 -mcpu=cortex-a76. ' "$dataset" "$short" "$long"
            printf 'Elapsed time is averaged over %s passes per round and covers only in-memory processing. Trade and signal counts are per pass.\n\n' "$passes"
            printf '%s\n\n' 'Perf event counts are per-pass averages over the whole user-space command and include data loading. IPC is total instructions divided by total cycles.'
            printf '%s\n' '| Variant | Round | Trades | BUY | SELL | Average elapsed (ns) | Cycles | Instructions | IPC | Cache misses |'
            printf '%s\n' '| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        } > "$work_dir/report.md"
    elif [ "$config" != "$expected_config" ]; then
        printf 'Inconsistent benchmark configuration for %s.\n' "$variant" >&2
        exit 1
    fi

    printf '[Stage B %s] Running %s.\n' "$variant" "$dataset" >&2
    round=1
    while [ "$round" -le "$rounds" ]; do
        : > "$work_dir/counters"
        if [ "$have_perf" -eq 1 ]; then
            rm -f -- "$work_dir/status"
            # Preserve progress and distinguish a perf startup failure from a benchmark failure.
            if ! perf stat -x ';' -o "$work_dir/counters" -e cycles:u,instructions:u,cache-misses:u -- \
                sh -c 'printf "started\n" > "$1"; result=0; "$2" --round "$3" 2>&3 3>&- || result=$?; printf "%s\n" "$result" > "$1"; exit "$result"' \
                perf-benchmark "$work_dir/status" "$benchmark" "$round" \
                3>&2 > "$work_dir/stdout" 2> "$work_dir/errors"; then
                cat "$work_dir/errors" >&2
            fi
            if [ ! -e "$work_dir/status" ]; then
                have_perf=0
                counter_note='Linux perf could not start hardware counter recording. Remaining rounds used elapsed timing.'
                printf '%s\n' "$counter_note" >&2
                : > "$work_dir/counters"
            elif [ "$(cat "$work_dir/status")" != 0 ]; then
                cat "$work_dir/stdout" >&2
                printf 'Benchmark failed for %s, round %s.\n' "$variant" "$round" >&2
                exit 1
            fi
        fi
        if [ "$have_perf" -eq 0 ] && ! "$benchmark" --round "$round" > "$work_dir/stdout"; then
            cat "$work_dir/stdout" >&2
            printf 'Benchmark failed for %s, round %s.\n' "$variant" "$round" >&2
            exit 1
        fi

        if ! result=$(awk -F '\t' -v round="$round" '
            { sub(/\r$/, "", $0) }
            NR == 1 && NF == 6 && $1 == "stageB_perf" && $2 == round &&
                $3 ~ /^[1-9][0-9]*$/ && $4 ~ /^[0-9]+$/ && $5 ~ /^[0-9]+$/ &&
                $6 ~ /^[0-9]+\.[0-9]+$/ { print $3, $4, $5, $6; next }
            { exit 1 }
            END { if (NR != 1) exit 1 }
        ' "$work_dir/stdout"); then
            printf 'Invalid benchmark output for %s, round %s.\n' "$variant" "$round" >&2
            exit 1
        fi
        read -r trades buys sells elapsed <<EOF
$result
EOF
        if [ -z "$trade_count" ]; then trade_count=$trades; fi
        if [ "$trades" != "$trade_count" ]; then
            printf 'Inconsistent trade count for %s, round %s.\n' "$variant" "$round" >&2
            exit 1
        fi

        counters=$(awk -F ';' -v passes="$passes" '
            $3 ~ /^(cycles|instructions|cache-misses)(:u)?$/ {
                sub(/:u$/, "", $3)
                if ($1 ~ /^[0-9]+(\.[0-9]+)?$/) count[$3] = $1
            }
            function average(event) {
                if (event in count) return sprintf("%.1f", count[event] / passes)
                return "N/A"
            }
            END {
                ipc = "N/A"
                if (("cycles" in count) && count["cycles"] > 0 && ("instructions" in count)) {
                    ipc = sprintf("%.3f", count["instructions"] / count["cycles"])
                }
                printf "%s | %s | %s | %s", average("cycles"), average("instructions"), ipc, average("cache-misses")
            }
        ' "$work_dir/counters")
        printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
            "$name" "$round" "$trades" "$buys" "$sells" "$elapsed" "$counters" >> "$work_dir/report.md"
        round=$((round + 1))
    done
done

if [ -n "$counter_note" ]; then
    printf '\n%s\n' "$counter_note" >> "$work_dir/report.md"
fi
mv -f -- "$work_dir/report.md" "$report"
cat "$report"
printf 'Saved %s\n' "$report"
