#!/bin/sh
set -eu

export LC_ALL=C
stage_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$stage_dir")
report="$stage_dir/stage0_all_tsv_results_pi.md"

work_dir=$(mktemp -d "$stage_dir/.stage0-all-tsv.XXXXXX")
trap 'rm -f -- "$work_dir"/benchmark-O[0-3].out "$work_dir"/O[0-3].tsv "$work_dir"/O[0-3].perf "$work_dir/status" "$work_dir/report.md"; rmdir -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

have_perf=0
if command -v perf >/dev/null 2>&1; then
    have_perf=1
else
    printf '[Stage 0] Linux perf is unavailable. Running with elapsed timing.\n' >&2
fi

for level in 0 1 2 3; do
    benchmark="$work_dir/benchmark-O$level.out"
    printf '[Stage 0 -O%s] Compiling benchmark.\n' "$level" >&2
    gcc -std=c17 "-O$level" -Wall -Wextra -Werror -I"$project_dir/common" \
        "$stage_dir/stage0_all_tsv.c" -o "$benchmark"
    printf '[Stage 0 -O%s] Running the benchmark.\n' "$level" >&2
    counters="$work_dir/O$level.perf"
    summary="$work_dir/O$level.tsv"
    status="$work_dir/status"
    : > "$counters"
    if [ "$have_perf" -eq 1 ]; then
        rm -f -- "$status"
        if ! perf stat -x ';' -o "$counters" -e cycles:u,instructions:u,cache-misses:u -- \
            sh -c '
                printf "started\n" > "$1" || exit 1
                result=0
                "$2" || result=$?
                printf "%s\n" "$result" > "$1" || exit 1
                exit "$result"
            ' perf-benchmark "$status" "$benchmark" > "$summary"; then
            if [ ! -f "$status" ]; then
                have_perf=0
                printf '[Stage 0 -O%s] Continuing without hardware counters.\n' "$level" >&2
                : > "$counters"
                "$benchmark" > "$summary"
            elif [ "$(cat "$status")" = 0 ]; then
                printf '[Stage 0 -O%s] Counter collection failed. Using elapsed timing.\n' "$level" >&2
                : > "$counters"
            else
                printf '[Stage 0 -O%s] Benchmark failed during profiling.\n' "$level" >&2
                exit 1
            fi
        fi
    else
        "$benchmark" > "$summary"
    fi
    printf '[Stage 0 -O%s] Measurements complete.\n' "$level" >&2
done

if ! awk -F '\t' '
    { sub(/\r$/, "") }
    FNR == 1 {
        if (NF != 2 || $1 !~ /^[1-9][0-9]*$/ || $2 !~ /^[1-9][0-9]*$/ ||
            (NR > 1 && ($1 != rounds || $2 != runs))) {
            invalid = 1
            exit 1
        }
        rounds = $1
        runs = $2
        next
    }
    {
        round = FNR - 1
        if (NF != 3 || $1 != round || $2 == "" || $3 == "") {
            invalid = 1
            exit 1
        }
        timings[FILENAME, round] = $2 " / " $3
        row_count[FILENAME] = round
    }
    END {
        if (invalid || rounds < 1) {
            exit 1
        }
        for (level = 1; level < ARGC; level++) {
            if (row_count[ARGV[level]] != rounds) {
                exit 1
            }
        }

        print "Measurements per method in each round: " runs "."
        print "Each cell shows the iterative / recursive averages."
        print ""
        print "| Round | -O0 | -O1 | -O2 | -O3 |"
        print "| ---: | ---: | ---: | ---: | ---: |"
        for (round = 1; round <= rounds; round++) {
            printf "| %d |", round
            for (level = 1; level < ARGC; level++) {
                printf " %s |", timings[ARGV[level], round]
            }
            print ""
        }
    }
' "$work_dir/O0.tsv" "$work_dir/O1.tsv" "$work_dir/O2.tsv" "$work_dir/O3.tsv" \
    > "$work_dir/report.md"; then
    printf '%s\n' 'Benchmark results have invalid or inconsistent counts or rows.' >&2
    exit 1
fi

{
    printf '\n%s\n\n' 'Hardware counters cover each full benchmark invocation, including all rounds and both methods.'
    printf '%s\n' 'IPC is retired instructions divided by CPU cycles. N/A means the counter could not be collected.'
    printf '\n%s\n' '| Optimization | CPU cycles | Retired instructions | IPC | Cache misses |'
    printf '%s\n' '| :--- | ---: | ---: | ---: | ---: |'
    for level in 0 1 2 3; do
        awk -F ';' -v level="$level" '
            $3 ~ /^(cycles|instructions|cache-misses)(:u)?$/ &&
            $1 ~ /^[0-9]+(\.[0-9]+)?$/ {
                sub(/:u$/, "", $3)
                count[$3] = $1
            }
            function counter(event) {
                return event in count ? count[event] : "N/A"
            }
            END {
                ipc = "N/A"
                if (("cycles" in count) && count["cycles"] > 0 && ("instructions" in count)) {
                    ipc = sprintf("%.3f", count["instructions"] / count["cycles"])
                }
                printf "| -O%s | %s | %s | %s | %s |\n", level,
                    counter("cycles"), counter("instructions"), ipc, counter("cache-misses")
            }
        ' "$work_dir/O$level.perf"
    done
} >> "$work_dir/report.md"

printf '[Stage 0] Saving the Markdown report.\n' >&2
mv -f -- "$work_dir/report.md" "$report"
printf 'Saved %s\n' "$report"
