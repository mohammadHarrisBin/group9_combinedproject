# Stage B performance on Windows

Dataset STRESS, SMA windows 15/100, GCC -O2. Elapsed time is averaged over 3 passes per round and covers only in-memory processing. Trade and signal counts are per pass.

| Variant | Round | Trades | BUY | SELL | Average elapsed (ns) |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Static naive | 1 | 8928944 | 13494 | 13345 | 1037244466.7 |
| Static naive | 2 | 8928944 | 13494 | 13345 | 984510033.3 |
| Static naive | 3 | 8928944 | 13494 | 13345 | 997427000.0 |
| Static naive | 4 | 8928944 | 13494 | 13345 | 992838766.7 |
| Static naive | 5 | 8928944 | 13494 | 13345 | 985815366.7 |
| Static running sum | 1 | 8928944 | 13494 | 13345 | 196779633.3 |
| Static running sum | 2 | 8928944 | 13494 | 13345 | 196004166.7 |
| Static running sum | 3 | 8928944 | 13494 | 13345 | 198972566.7 |
| Static running sum | 4 | 8928944 | 13494 | 13345 | 196404766.7 |
| Static running sum | 5 | 8928944 | 13494 | 13345 | 196233000.0 |
| Fixed-point running sum | 1 | 8928944 | 13494 | 13345 | 135741333.3 |
| Fixed-point running sum | 2 | 8928944 | 13494 | 13345 | 133509866.7 |
| Fixed-point running sum | 3 | 8928944 | 13494 | 13345 | 136033100.0 |
| Fixed-point running sum | 4 | 8928944 | 13494 | 13345 | 176039600.0 |
| Fixed-point running sum | 5 | 8928944 | 13494 | 13345 | 156858566.7 |
| Heap naive | 1 | 8928944 | 13494 | 13345 | 1171478733.3 |
| Heap naive | 2 | 8928944 | 13494 | 13345 | 1101635866.7 |
| Heap naive | 3 | 8928944 | 13494 | 13345 | 1050551500.0 |
| Heap naive | 4 | 8928944 | 13494 | 13345 | 1106828833.3 |
| Heap naive | 5 | 8928944 | 13494 | 13345 | 1058714600.0 |
