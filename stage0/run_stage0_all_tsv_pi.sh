#!/bin/sh
set -eu

export LC_ALL=C
stage_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$stage_dir")
report="$stage_dir/stage0_all_tsv_results_pi.md"

work_dir=$(mktemp -d "$stage_dir/.stage0-all-tsv.XXXXXX")
trap 'rm -f -- "$work_dir"/benchmark-O[0-3].out "$work_dir"/O[0-3].tsv "$work_dir/report.md"; rmdir -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

for level in 0 1 2 3; do
    benchmark="$work_dir/benchmark-O$level.out"
    gcc -std=c17 "-O$level" -Wall -Wextra -Werror -I"$project_dir/common" \
        "$stage_dir/stage0_all_tsv.c" -o "$benchmark"
    "$benchmark" > "$work_dir/O$level.tsv"
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

mv -f -- "$work_dir/report.md" "$report"
printf 'Saved %s\n' "$report"
