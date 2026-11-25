# Optimized Stage C performance on Windows

Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -Wall -Wextra -Werror -DSTAGEC_SCALED_SIGNAL=1`. Optimization levels `-O2 -O3`.

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 8928944 | 13494 | 13345 | 29.48 | 6783200 | 86406712600 |
| -O3 | 1 | 1000 | 8928944 | 13494 | 13345 | 29.42 | 7740600 | 86399132800 |

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 0.1 | 114369.34 | 25760 | 223 |
| -O2 | 1 | 1000 | 0.5 | 114386.62 | 25961 | 22 |
| -O2 | 1 | 1000 | 1.0 | 114387.95 | 25972 | 11 |
| -O2 | 1 | 1000 | 2.0 | 114387.95 | 25973 | 10 |
| -O2 | 1 | 1000 | 5.0 | 114387.95 | 25974 | 9 |
| -O2 | 1 | 1000 | 10.0 | 114387.95 | 25976 | 7 |
| -O2 | 1 | 1000 | 20.0 | 114387.95 | 25979 | 4 |
| -O2 | 1 | 1000 | 50.0 | 114388.64 | 25982 | 1 |
| -O2 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 0.1 | 114366.09 | 25758 | 225 |
| -O3 | 1 | 1000 | 0.5 | 114386.99 | 25971 | 12 |
| -O3 | 1 | 1000 | 1.0 | 114388.64 | 25977 | 6 |
| -O3 | 1 | 1000 | 2.0 | 114388.64 | 25978 | 5 |
| -O3 | 1 | 1000 | 5.0 | 114388.64 | 25978 | 5 |
| -O3 | 1 | 1000 | 10.0 | 114388.64 | 25979 | 4 |
| -O3 | 1 | 1000 | 20.0 | 114388.64 | 25981 | 2 |
| -O3 | 1 | 1000 | 50.0 | 114388.64 | 25982 | 1 |
| -O3 | 1 | 1000 | 100.0 | 114388.64 | 25982 | 1 |
