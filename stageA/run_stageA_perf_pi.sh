#!/bin/sh
levels='0 2'

set -eu

export LC_ALL=C
stage_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$stage_dir")
report="$stage_dir/stageA_perf_results_pi.md"

work_dir=$(mktemp -d "$stage_dir/.stageA-perf.XXXXXX")
trap 'rm -f -- "$work_dir/benchmark.out" "$work_dir/O0.txt" "$work_dir/O1.txt" "$work_dir/O2.txt" "$work_dir/O3.txt" "$work_dir/report.md" "$work_dir/stdout" "$work_dir/status" "$work_dir/counters" "$work_dir/errors" "$work_dir/notes"; rmdir -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

cd "$project_dir"
benchmark="$work_dir/benchmark.out"
have_perf=0
if command -v perf >/dev/null 2>&1; then
    have_perf=1
else
    printf '%s\n' '- Linux perf is unavailable on this host.' > "$work_dir/notes"
    printf '[Stage A] Linux perf is unavailable. Running with elapsed timing.\n' >&2
fi

for level in $levels; do
    printf '[Stage A -O%s] Compiling benchmark.\n' "$level" >&2
    gcc -std=c17 "-O$level" -Wall -Wextra -Werror -DBENCHMARK_PROGRESS -Icommon -Iindicators \
        "$stage_dir/main_stageA_perf.c" common/trade_io.c \
        indicators/vwap.c indicators/ohlc.c indicators/sma.c indicators/signal.c \
        -o "$benchmark"

    config=$("$benchmark" --config)
    if ! counts=$(printf '%s\n' "$config" | awk -F '\t' '
        NR == 1 && NF == 2 && $1 ~ /^[1-9][0-9]*$/ && $2 ~ /^[1-9][0-9]*$/ {
            print $1, $2
            next
        }
        { exit 1 }
        END { if (NR != 1) exit 1 }
    '); then
        printf '%s\n' "Invalid benchmark configuration at -O$level." >&2
        exit 1
    fi
    rounds=${counts% *}
    runs=${counts#* }
    if [ -z "${expected_config+x}" ]; then
        expected_config=$config
    elif [ "$config" != "$expected_config" ]; then
        printf '%s\n' 'Inconsistent benchmark configuration across optimization levels.' >&2
        exit 1
    fi

    printf '[Stage A -O%s] Running the benchmark on the STRESS dataset.\n' "$level" >&2
    round=1
    while [ "$round" -le "$rounds" ]; do
        : > "$work_dir/counters"
        if [ "$have_perf" -eq 1 ]; then
            rm -f -- "$work_dir/status"
            # Keep benchmark progress on the terminal while capturing perf diagnostics.
            # The status file tells us whether perf launched the benchmark.
            if ! perf stat -x ';' -o "$work_dir/counters" -e cycles:u,instructions:u,cache-misses:u -- \
                sh -c 'printf "started\n" > "$1"; result=0; "$2" --round "$3" 2>&3 3>&- || result=$?; printf "%s\n" "$result" > "$1"; exit "$result"' \
                perf-benchmark "$work_dir/status" "$benchmark" "$round" \
                3>&2 > "$work_dir/stdout" 2> "$work_dir/errors"; then
                cat "$work_dir/errors" >&2
            fi
            if [ ! -e "$work_dir/status" ]; then
                # A missing perf installation or permission failure did not run a trial.
                have_perf=0
                printf '[Stage A -O%s] Continuing without hardware counters.\n' "$level" >&2
                if grep -Eiq 'permission|not permitted|perf_event_paranoid|access denied' "$work_dir/errors" "$work_dir/counters"; then
                    printf '%s\n' '- Linux perf was denied permission to record hardware counters.' >> "$work_dir/notes"
                else
                    printf '%s\n' '- Linux perf could not start hardware counter recording.' >> "$work_dir/notes"
                fi
                : > "$work_dir/counters"
            elif [ "$(cat "$work_dir/status")" != 0 ]; then
                cat "$work_dir/stdout" >&2
                printf 'Benchmark failed at -O%s, round %s.\n' "$level" "$round" >&2
                exit 1
            fi
        fi
        if [ "$have_perf" -eq 0 ] && ! "$benchmark" --round "$round" > "$work_dir/stdout"; then
            cat "$work_dir/stdout" >&2
            printf 'Benchmark failed at -O%s, round %s.\n' "$level" "$round" >&2
            exit 1
        fi

        if ! elapsed=$(awk -F '\t' -v round="$round" '
            { sub(/\r$/, "", $0) }
            $1 == "stageA_perf" {
                if (++rows != 1 || NF != 3 || $2 != round ||
                    $3 !~ /^[0-9]+\.[0-9]+ ns \([0-9]+\.[0-9]+ ms\)$/) exit 1
                print $3
            }
            END { if (rows != 1) exit 1 }
        ' "$work_dir/stdout"); then
            printf 'Invalid benchmark output at -O%s, round %s.\n' "$level" "$round" >&2
            exit 1
        fi

        awk -F ';' -v round="$round" -v elapsed="$elapsed" -v runs="$runs" '
            $3 ~ /^(cycles|instructions|cache-misses)(:u)?$/ && $1 ~ /^[0-9]+(\.[0-9]+)?$/ {
                sub(/:u$/, "", $3)
                count[$3] = $1
            }
            function average(event) {
                return event in count ? sprintf("%.1f", count[event] / runs) : "N/A"
            }
            END {
                ipc = "N/A"
                if (("cycles" in count) && count["cycles"] > 0 && ("instructions" in count)) {
                    ipc = sprintf("%.3f", count["instructions"] / count["cycles"])
                }
                printf "%s\t%s\t%s\t%s\t%s\t%s\n", round, elapsed,
                    average("cycles"), average("instructions"), ipc, average("cache-misses")
            }
        ' "$work_dir/counters" >> "$work_dir/O$level.txt"
        round=$((round + 1))
    done
    printf '[Stage A -O%s] Measurements complete.\n' "$level" >&2
done

printf '[Stage A] Saving the Markdown report.\n' >&2
set --
for level in $levels; do
    set -- "$@" "$work_dir/O$level.txt"
done

awk -F '\t' -v levels="$levels" -v rounds="$rounds" -v runs="$runs" '
    BEGIN {
        columns = split(levels, flags, " ")
        metrics[1] = "Elapsed time"
        metrics[2] = "CPU cycles"
        metrics[3] = "Retired instructions"
        metrics[4] = "IPC"
        metrics[5] = "Cache misses"

        print "Elapsed time and event counts are averages per pass over " runs " passes per round."
        print "IPC is total retired instructions divided by total cycles. Counts cover user-space execution of the profiled command."
        print ""
        printf "| Round | Metric |"
        for (i = 1; i <= columns; i++) printf " -O%s |", flags[i]
        printf "\n| ---: | :--- |"
        for (i = 1; i <= columns; i++) printf " ---: |"
        printf "\n"
    }
    FNR == 1 { column++ }
    {
        for (metric = 1; metric <= 5; metric++) {
            timing[column, $1, metric] = $(metric + 1)
        }
    }
    END {
        for (round = 1; round <= rounds; round++) {
            for (metric = 1; metric <= 5; metric++) {
                printf "| %d | %s |", round, metrics[metric]
                for (i = 1; i <= columns; i++) {
                    value = timing[i, round, metric]
                    printf " %s |", value
                    if (value == "N/A") missing = 1
                }
                printf "\n"
            }
        }
        if (missing) {
            print ""
            print "N/A indicates an unavailable or uncounted event."
        }
    }
' "$@" > "$work_dir/report.md"

if [ -s "$work_dir/notes" ]; then
    printf '\nCounter availability\n\n' >> "$work_dir/report.md"
    cat "$work_dir/notes" >> "$work_dir/report.md"
fi
mv -f -- "$work_dir/report.md" "$report"
cat "$report"
printf 'Saved %s\n' "$report"
