# Stage C performance on Windows

Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -Wall -Wextra -Werror`. Optimization levels `-O2 -O3`.

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 8928944 | 13494 | 13345 | 40.58 | 6016400 | 86402879800 |
| -O3 | 1 | 1000 | 8928944 | 13494 | 13345 | 39.78 | 1937200 | 86410483100 |

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 0.1 | 114389.10 | 25897 | 86 |
| -O2 | 1 | 1000 | 0.5 | 114394.06 | 25973 | 10 |
| -O2 | 1 | 1000 | 1.0 | 114394.05 | 25979 | 4 |
| -O2 | 1 | 1000 | 2.0 | 114394.05 | 25980 | 3 |
| -O2 | 1 | 1000 | 5.0 | 114394.05 | 25980 | 3 |
| -O2 | 1 | 1000 | 10.0 | 114394.05 | 25980 | 3 |
| -O2 | 1 | 1000 | 20.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 50.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 0.1 | 114383.68 | 25884 | 99 |
| -O3 | 1 | 1000 | 0.5 | 114388.63 | 25974 | 9 |
| -O3 | 1 | 1000 | 1.0 | 114388.63 | 25980 | 3 |
| -O3 | 1 | 1000 | 2.0 | 114388.63 | 25980 | 3 |
| -O3 | 1 | 1000 | 5.0 | 114388.63 | 25980 | 3 |
| -O3 | 1 | 1000 | 10.0 | 114388.63 | 25980 | 3 |
| -O3 | 1 | 1000 | 20.0 | 114388.64 | 25982 | 1 |
| -O3 | 1 | 1000 | 50.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
