#ifndef VWAP_H // ifndef=if not define
#define VWAP_H

// --- VWAP State Structure ---
typedef struct {
    double sum_price_qty; // Running sum of (price * quantity)
    double sum_qty;       // Running sum of quantity
} VWAPState;

// Function Prototypes
void vwap_init(VWAPState *state);
void vwap_update(VWAPState *state, double price, double qty);
double vwap_get(const VWAPState *state);

#endif /* VWAP_H */