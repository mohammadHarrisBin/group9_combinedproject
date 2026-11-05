#ifndef SIGNAL_H
#define SIGNAL_H

// Signal Types
#define SIGNAL_NONE 0
#define SIGNAL_BUY  1
#define SIGNAL_SELL -1

// Signal State Structure
typedef struct {
    double prev_diff; // Short SMA - Long SMA from previous trade
    int initialized;  // 1 after the first valid SMA comparison
} SignalState;

// Function Prototypes
void signal_init(SignalState *st);
int signal_update(SignalState *st, double short_sma, double long_sma);

#endif /* SIGNAL_H */