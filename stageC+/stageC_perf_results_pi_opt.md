# Optimized Stage C performance on Raspberry Pi

Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -mcpu=cortex-a76 -Wall -Wextra -Werror -D_POSIX_C_SOURCE=200809L -DSTAGEC_SCALED_SIGNAL=1`. Optimization levels `-O2 -O3`.

Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.

`perf stat` measures the whole user-space command, including CSV loading. IPC is instructions divided by cycles.

## Replay

| Optimization | Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) | Cycles | Instructions | IPC | Cache misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 8928944 | 13494 | 13345 | 58.19 | 26256 | 86399027635 | 6576943943 | 10371679943 | 1.577 | 6888001 |
| -O3 | 1 | 1000 | 8928944 | 13494 | 13345 | 58.01 | 28572 | 86399386394 | 6577969459 | 10321793775 | 1.569 | 8684457 |

## Rival bot

| Optimization | Round | Speed | Rival reaction time (µs) | P&L (USDT) | Bot wins | Rival wins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -O2 | 1 | 1000 | 0.1 | 114388.50 | 25975 | 8 |
| -O2 | 1 | 1000 | 0.5 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 1.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 2.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 5.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 10.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 20.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 50.0 | 114388.64 | 25983 | 0 |
| -O2 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 0.1 | 114385.89 | 25951 | 32 |
| -O3 | 1 | 1000 | 0.5 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 1.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 2.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 5.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 10.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 20.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 50.0 | 114388.64 | 25983 | 0 |
| -O3 | 1 | 1000 | 100.0 | 114388.64 | 25983 | 0 |
