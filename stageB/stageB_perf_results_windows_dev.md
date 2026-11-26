# Stage B performance on Windows

Dataset DEV, SMA windows 15/100, GCC -O2. Elapsed time is averaged over 3 passes per round and covers only in-memory processing. Trade and signal counts are per pass.

| Variant | Round | Trades | BUY | SELL | Average elapsed (ns) |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Static naive | 1 | 1000000 | 2292 | 2286 | 121138733.3 |
| Static naive | 2 | 1000000 | 2292 | 2286 | 117569800.0 |
| Static naive | 3 | 1000000 | 2292 | 2286 | 137368000.0 |
| Static naive | 4 | 1000000 | 2292 | 2286 | 117619833.3 |
| Static naive | 5 | 1000000 | 2292 | 2286 | 117232166.7 |
| Static running sum | 1 | 1000000 | 2292 | 2286 | 24223833.3 |
| Static running sum | 2 | 1000000 | 2292 | 2286 | 24422166.7 |
| Static running sum | 3 | 1000000 | 2292 | 2286 | 27343166.7 |
| Static running sum | 4 | 1000000 | 2292 | 2286 | 22955700.0 |
| Static running sum | 5 | 1000000 | 2292 | 2286 | 25853733.3 |
| Fixed-point running sum | 1 | 1000000 | 2292 | 2286 | 15922166.7 |
| Fixed-point running sum | 2 | 1000000 | 2292 | 2286 | 18964633.3 |
| Fixed-point running sum | 3 | 1000000 | 2292 | 2286 | 17190466.7 |
| Fixed-point running sum | 4 | 1000000 | 2292 | 2286 | 19075800.0 |
| Fixed-point running sum | 5 | 1000000 | 2292 | 2286 | 15678000.0 |
| Heap naive | 1 | 1000000 | 2292 | 2286 | 118981266.7 |
| Heap naive | 2 | 1000000 | 2292 | 2286 | 121565200.0 |
| Heap naive | 3 | 1000000 | 2292 | 2286 | 130856433.3 |
| Heap naive | 4 | 1000000 | 2292 | 2286 | 113766033.3 |
| Heap naive | 5 | 1000000 | 2292 | 2286 | 116910833.3 |
