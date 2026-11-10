#include "fast_reader.h"
#include <stdlib.h>
#include <string.h>

// global state file 
static FILE *trades_file = NULL;

/*

cur_id,cur_time,cur_price,
cur_qty, cur_quote,cur_is_buy

all is handled by read_trade()

*/


/* Copy a folder name into out, replacing a leading "~" with your home folder */
static void expand_home(const char *folder, char *out, int size) {
    const char *home;
    if (folder[0] == '~') {
        home = getenv("HOME"); /* Mac, Linux, Pi */
        if (home == NULL) home = getenv("USERPROFILE"); // for windows
        if (home == NULL) home = "";
        // why snprintf & folder + 1
        /*
            folder = "~/Datasets"
            folder[0] = '~'
            folder+1 = /Datasets

            home=/home/{user}

            snprintf result = /home/{user}/Datasets

        */
        snprintf(out, size, "%s%s", home, folder + 1);
    } else {
        snprintf(out, size, "%s", folder);
    }
}

static int open_path(const char *path) {
    // e.g., opening the file path = "~/Datasets/Group09/Test20.csv" 
    trades_file = fopen(path, "r");

    if (trades_file == NULL) {
        printf("fast_reader: cannot open %s\n", path);
        return 0;
    }

    // Skip CSV header line ONCE at file open so trade alignment matches trade_io
    
    // read the file per line, max characters is 256 per line.
    char line[256];
    if (fgets(line, sizeof(line), trades_file)) {
        if (line[0] >= '0' && line[0] <= '9') {

            /* 
                why fseek?
                Lets say we have read mid file
                and we want to restart.

                Instead of opening a closing
                the current and open a new file

                we can use: 
                - SEEK SET // go back to the start of File
                - SEEK END // go back to the End of File(EOF)
                - long file_size = ftell(trades_file);  (We have to use for stageB and C later)
            */

            fseek(trades_file, 0, SEEK_SET); // Rewind if no header line present
        }
    }
    return 1;
}


// complete file open and read
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

    // file is saved to out global variable called
    // trades_file
    return open_path(path);
}



int open_trades(const char *filename) {
    return open_path(filename);
}

// close the file
// reset trades_file = NULL
void close_trades(void) {
    if (trades_file != NULL) {
        // always close the file
        fclose(trades_file);
        trades_file = NULL;
    }
}

// Fast Integer Parser
// Converting Ascii character to 64bit integer (long long)
// why **ptr
static inline long long parse_long_long(const char **ptr) {
    long long val = 0;
    while (**ptr >= '0' && **ptr <= '9') {
        // **ptr - '0' = '0' - '0' = 48 - 48 = 0
        // **ptr - '0' = '5' - '0' = 53 - 48 = 0
        
        /*
         why *10? e.g., 529
            '5': val = (0 * 10) + 5 = 5
            '2': val = (5 * 10) + 2 = 52
            '9': val = (52 * 10) + 9 = 529
        */
        val = val * 10 + (**ptr - '0');

        // dereference the pointer and increment by 1 to 
        // move the the next char
        (*ptr)++;
    }
    return val;
}

// Fast Fixed-to-Double Parser (Parses integers first, divides ONCE at the end)
static inline double parse_double(const char **ptr) {
    
    // parse the integer first -> before the decimal point(.)
    long long int_part = 0;
    while (**ptr >= '0' && **ptr <= '9') {
        int_part = int_part * 10 + (**ptr - '0');
        (*ptr)++;
    }

    // parse the decimal points -> after the decimal point(.)
    if (**ptr == '.') {
        (*ptr)++;
        long long frac_part = 0;
        long long divisor = 1;
        while (**ptr >= '0' && **ptr <= '9') {
            frac_part = frac_part * 10 + (**ptr - '0');
            // Scale divisor by 10 for each fractional place (tenths, hundredths, thousandths)
            divisor *= 10;
            (*ptr)++;
        }

        // Perform a single double division to convert frac_part back to decimal form, then combine
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