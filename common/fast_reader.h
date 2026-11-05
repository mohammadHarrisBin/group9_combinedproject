#ifndef FAST_READER_H
#define FAST_READER_H

#include <stdio.h>

/* Match trade_io enum constants for dataset selection */
#define TEST20 1
#define DEV    2
#define STRESS 3

#ifndef DATA_FOLDER
#define DATA_FOLDER  "Datasets"
#endif

#ifndef GROUP_FOLDER
#define GROUP_FOLDER "Group09"
#endif

/**
 * Open standard dataset file (TEST20, DEV, or STRESS)
 * Automatically resolves home directory ~ pathing across OS.
 * @return 1 on success, 0 on failure
 */
int open_data(int which);

/**
 * Open explicit file path
 * @return 1 on success, 0 on failure
 */
int open_trades(const char *filename);

/**
 * Close currently open dataset file stream
 */
void close_trades(void);

/**
 * Fast trade reader using pointers and manual integer/double parsing
 * @return 1 if trade read successfully, 0 on EOF or error
 */
int read_trade(long long *ts, double *price, double *qty, int *is_buy);

#endif // FAST_READER_H