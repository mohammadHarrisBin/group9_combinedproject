#include "fast_reader.h"
#include <stdlib.h>
#include <string.h>

static FILE *trades_file = NULL;

static void expand_home(const char *folder, char *out, int size) {
    const char *home;
    if (folder[0] == '~') {
        home = getenv("HOME");
        if (home == NULL) home = getenv("USERPROFILE");
        if (home == NULL) home = "";
        snprintf(out, size, "%s%s", home, folder + 1);
    } else {
        snprintf(out, size, "%s", folder);
    }
}

static int open_path(const char *path) {
    trades_file = fopen(path, "r");
    if (trades_file == NULL) {
        printf("fast_reader: cannot open %s\n", path);
        return 0;
    }

    // Skip CSV header line ONCE at file open so trade alignment matches trade_io
    char line[256];
    if (fgets(line, sizeof(line), trades_file)) {
        if (line[0] >= '0' && line[0] <= '9') {
            fseek(trades_file, 0, SEEK_SET); // Rewind if no header line present
        }
    }
    return 1;
}

int open_data(int which) {
    char folder[400], path[512];
    expand_home(DATA_FOLDER, folder, sizeof folder);

    if (which == TEST20)      snprintf(path, sizeof path, "%s/%s/test20.csv", folder, GROUP_FOLDER);
    else if (which == DEV)    snprintf(path, sizeof path, "%s/%s/dev_1M.csv", folder, GROUP_FOLDER);
    else if (which == STRESS) snprintf(path, sizeof path, "%s/stress_full.csv", folder);
    else {
        printf("fast_reader: open_data() needs TEST20, DEV or STRESS\n");
        return 0;
    }
    return open_path(path);
}

int open_trades(const char *filename) {
    return open_path(filename);
}

void close_trades(void) {
    if (trades_file != NULL) {
        fclose(trades_file);
        trades_file = NULL;
    }
}

// Fast Integer Parser
static inline long long parse_long_long(const char **ptr) {
    long long val = 0;
    while (**ptr >= '0' && **ptr <= '9') {
        val = val * 10 + (**ptr - '0');
        (*ptr)++;
    }
    return val;
}

// Fast Fixed-to-Double Parser (Parses integers first, divides ONCE at the end)
static inline double parse_double(const char **ptr) {
    long long int_part = 0;
    while (**ptr >= '0' && **ptr <= '9') {
        int_part = int_part * 10 + (**ptr - '0');
        (*ptr)++;
    }
    if (**ptr == '.') {
        (*ptr)++;
        long long frac_part = 0;
        long long divisor = 1;
        while (**ptr >= '0' && **ptr <= '9') {
            frac_part = frac_part * 10 + (**ptr - '0');
            divisor *= 10;
            (*ptr)++;
        }
        return (double)int_part + ((double)frac_part / divisor);
    }
    return (double)int_part;
}

int read_trade(long long *ts, double *price, double *qty, int *is_buy) {
    if (trades_file == NULL) return 0;

    char line[256];
    if (!fgets(line, sizeof(line), trades_file)) {
        return 0;
    }

    const char *ptr = line;

    // Field 1: tradeId (skip)
    while (*ptr != ',' && *ptr != '\0') ptr++;
    if (*ptr == ',') ptr++;

    // Field 2: price
    *price = parse_double(&ptr);
    if (*ptr == ',') ptr++;

    // Field 3: qty
    *qty = parse_double(&ptr);
    if (*ptr == ',') ptr++;

    // Field 4: quoteQty (skip)
    while (*ptr != ',' && *ptr != '\0') ptr++;
    if (*ptr == ',') ptr++;

    // Field 5: time
    *ts = parse_long_long(&ptr);
    if (*ptr == ',') ptr++;

    // Field 6: isBuyerMaker ('True'/'true' = 0/SELL, 'False'/'false' = 1/BUY)
    if (*ptr == 'T' || *ptr == 't') {
        *is_buy = 0;
    } else {
        *is_buy = 1;
    }

    return 1;
}