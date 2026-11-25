# Optimized Stage C performance on Windows

Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -Wall -Wextra -Werror -DSTAGEC_SCALED_SIGNAL=1`. Optimization levels `-O2 -O3`.

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 8928944 | 13494 | 13345 | 30.89 | 490900 | 86411849300 |
| -O3 | 1 | 1000 | 8928944 | 13494 | 13345 | 28.38 | 1185800 | 86411792100 |

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 0.1 | 114389.65 | 25853 | 130 |
| -O2 | 1 | 1000 | 0.5 | 114388.65 | 25962 | 21 |
| -O2 | 1 | 1000 | 1.0 | 114388.64 | 25977 | 6 |
| -O2 | 1 | 1000 | 2.0 | 114388.64 | 25978 | 5 |
| -O2 | 1 | 1000 | 5.0 | 114388.64 | 25978 | 5 |
| -O2 | 1 | 1000 | 10.0 | 114388.64 | 25978 | 5 |
| -O2 | 1 | 1000 | 20.0 | 114388.64 | 25980 | 3 |
| -O2 | 1 | 1000 | 50.0 | 114388.64 | 25982 | 1 |
| -O2 | 1 | 1000 | 100.0 | 114388.64 | 25982 | 1 |
| -O3 | 1 | 1000 | 0.1 | 114386.33 | 25881 | 102 |
| -O3 | 1 | 1000 | 0.5 | 114388.59 | 25969 | 14 |
| -O3 | 1 | 1000 | 1.0 | 114388.59 | 25978 | 5 |
| -O3 | 1 | 1000 | 2.0 | 114388.59 | 25978 | 5 |
| -O3 | 1 | 1000 | 5.0 | 114388.59 | 25978 | 5 |
| -O3 | 1 | 1000 | 10.0 | 114388.59 | 25980 | 3 |
| -O3 | 1 | 1000 | 20.0 | 114388.60 | 25981 | 2 |
| -O3 | 1 | 1000 | 50.0 | 114388.60 | 25981 | 2 |
| -O3 | 1 | 1000 | 100.0 | 114388.64 | 25982 | 1 |
