#ifndef SIGNAL_OPT_H
#define SIGNAL_OPT_H

// Signal Types
#define SIGNAL_NONE 0
#define SIGNAL_BUY  1
#define SIGNAL_SELL -1
#define SIGNAL_TOLERANCE 1e-6

// Signal State Structure
typedef struct {
    double prev_diff; // dₜ₋₁ Previous difference in the current comparison scale
    int initialized;  // 1 after the first valid SMA comparison
} SignalState;

// Function Prototypes
void signal_init(SignalState *st);
int signal_update(SignalState *st, double short_sma, double long_sma);

int signal_update_difference(SignalState *st, double curr_diff, double tolerance);

#endif /* SIGNAL_OPT_H */