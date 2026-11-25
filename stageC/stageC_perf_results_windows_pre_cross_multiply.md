# Stage C performance on Windows

Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -Wall -Wextra -Werror`. Optimization levels `-O2 -O3`.

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 8928944 | 13494 | 13345 | 80.66 | 1044600 | 86410176200 |
| -O3 | 1 | 1000 | 8928944 | 13494 | 13345 | 74.73 | 3005900 | 86405371100 |

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 0.1 | 114098.76 | 21100 | 4883 |
| -O2 | 1 | 1000 | 0.5 | 114388.63 | 25953 | 30 |
| -O2 | 1 | 1000 | 1.0 | 114388.65 | 25973 | 10 |
| -O2 | 1 | 1000 | 2.0 | 114388.64 | 25981 | 2 |
| -O2 | 1 | 1000 | 5.0 | 114388.64 | 25981 | 2 |
| -O2 | 1 | 1000 | 10.0 | 114388.64 | 25981 | 2 |
| -O2 | 1 | 1000 | 20.0 | 114388.64 | 25981 | 2 |
| -O2 | 1 | 1000 | 50.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 0.1 | 114216.12 | 22927 | 3056 |
| -O3 | 1 | 1000 | 0.5 | 114386.15 | 25962 | 21 |
| -O3 | 1 | 1000 | 1.0 | 114387.76 | 25973 | 10 |
| -O3 | 1 | 1000 | 2.0 | 114387.76 | 25973 | 10 |
| -O3 | 1 | 1000 | 5.0 | 114387.76 | 25973 | 10 |
| -O3 | 1 | 1000 | 10.0 | 114387.76 | 25973 | 10 |
| -O3 | 1 | 1000 | 20.0 | 114388.64 | 25978 | 5 |
| -O3 | 1 | 1000 | 50.0 | 114388.64 | 25982 | 1 |
| -O3 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
