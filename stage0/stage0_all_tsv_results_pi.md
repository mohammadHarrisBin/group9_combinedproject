Measurements per method in each round: 25.
Each cell shows the iterative / recursive averages.

| Round | -O0 | -O1 | -O2 | -O3 |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 279188614.0 ns (279.189 ms) / 390945840.8 ns (390.946 ms) | 83459819.5 ns (83.460 ms) / 250215703.0 ns (250.216 ms) | 46872721.1 ns (46.873 ms) / 62599621.4 ns (62.600 ms) | 52141349.5 ns (52.141 ms) / 52147769.8 ns (52.148 ms) |
| 2 | 279047654.8 ns (279.048 ms) / 390946827.3 ns (390.947 ms) | 83448586.5 ns (83.449 ms) / 250221791.1 ns (250.222 ms) | 46824238.8 ns (46.824 ms) / 62602705.8 ns (62.603 ms) | 52137848.8 ns (52.138 ms) / 52150930.0 ns (52.151 ms) |
| 3 | 278872763.2 ns (278.873 ms) / 390934301.4 ns (390.934 ms) | 83461505.6 ns (83.462 ms) / 250204779.4 ns (250.205 ms) | 46880070.0 ns (46.880 ms) / 62603892.5 ns (62.604 ms) | 52139326.7 ns (52.139 ms) / 52149763.6 ns (52.150 ms) |
| 4 | 278930403.6 ns (278.930 ms) / 390933159.1 ns (390.933 ms) | 83448043.5 ns (83.448 ms) / 250221368.0 ns (250.221 ms) | 46852852.6 ns (46.853 ms) / 62601945.2 ns (62.602 ms) | 52137516.8 ns (52.138 ms) / 52147052.2 ns (52.147 ms) |
| 5 | 278987724.1 ns (278.988 ms) / 390953614.8 ns (390.954 ms) | 83446261.8 ns (83.446 ms) / 250166607.4 ns (250.167 ms) | 46839427.5 ns (46.839 ms) / 62598326.3 ns (62.598 ms) | 52138875.0 ns (52.139 ms) / 52149596.0 ns (52.150 ms) |

Hardware counters cover each full benchmark invocation, including all rounds and both methods.

IPC is retired instructions divided by CPU cycles. N/A means the counter could not be collected.

| Optimization | CPU cycles | Retired instructions | IPC | Cache misses |
| :--- | ---: | ---: | ---: | ---: |
| -O0 | 200826794818 | 312536669645 | 1.556 | 599039785 |
| -O1 | 100042348475 | 200015408993 | 1.999 | 5278850737 |
| -O2 | 32823628672 | 112514156334 | 3.428 | 4299 |
| -O3 | 31272988109 | 75050406699 | 2.400 | 5286 |
