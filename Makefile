CC = gcc
CFLAGS = -Wall -Wextra -Icommon -Iindicators -Istage0
BIN_DIR = bin
PLOTS_DIR = plots

# Default target: build everything (including Stage B Naive, Running-Sum, Fixed-Point, Malloc, and Stage C)
all: directories stage0 test_tradeio test_vwap test_ohlc test_sma test_signal stageA stageA_plus stageB stageB_naive stageB_running stageB_fp stageB_malloc stageC

directories:
	@mkdir -p $(BIN_DIR) $(PLOTS_DIR)

# ==============================================================================
# --- Stage 0 Targets ---
# ==============================================================================
stage0: directories $(BIN_DIR)/parta_O0 $(BIN_DIR)/parta_O1 $(BIN_DIR)/parta_O2 $(BIN_DIR)/parta_O3 $(BIN_DIR)/partb_O0 $(BIN_DIR)/partb_O2

$(BIN_DIR)/parta_O0: stage0/stage0_parta.c
	$(CC) $(CFLAGS) -O0 $< -o $@

$(BIN_DIR)/parta_O1: stage0/stage0_parta.c
	$(CC) $(CFLAGS) -O1 $< -o $@

$(BIN_DIR)/parta_O2: stage0/stage0_parta.c
	$(CC) $(CFLAGS) -O2 $< -o $@

$(BIN_DIR)/parta_O3: stage0/stage0_parta.c
	$(CC) $(CFLAGS) -O3 $< -o $@

# Makefile targets for Stage 0 Part B
$(BIN_DIR)/partb_O0: stage0/stage0_partb.c
	$(CC) $(CFLAGS) -O0 $< -o $@

$(BIN_DIR)/partb_O2: stage0/stage0_partb.c
	$(CC) $(CFLAGS) -O2 $< -o $@

# ==============================================================================
# --- Stage A & Indicator Test Targets ---
# ==============================================================================

# Standalone trade_io reader test
test_tradeio: directories $(BIN_DIR)/test_tradeio

$(BIN_DIR)/test_tradeio: stageA/test_tradeio.c common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Standalone VWAP indicator test
test_vwap: directories $(BIN_DIR)/test_vwap

$(BIN_DIR)/test_vwap: stageA/test_vwap.c indicators/vwap.c common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Standalone OHLC indicator test
test_ohlc: directories $(BIN_DIR)/test_ohlc

$(BIN_DIR)/test_ohlc: stageA/test_ohlc.c indicators/ohlc.c common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Standalone SMA indicator test
test_sma: directories $(BIN_DIR)/test_sma

$(BIN_DIR)/test_sma: stageA/test_sma.c indicators/sma.c common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Standalone Signal Test
test_signal: directories $(BIN_DIR)/test_signal

$(BIN_DIR)/test_signal: stageA/test_signal.c indicators/signal.c indicators/sma.c common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Full Stage A Streaming Engine (linking ALL modules with trade_io)
stageA: directories $(BIN_DIR)/stageA_engine

$(BIN_DIR)/stageA_engine: stageA/main_stageA.c \
                          indicators/vwap.c \
                          indicators/ohlc.c \
                          indicators/sma.c \
                          indicators/signal.c \
                          common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Stage A Test Runner (TEST20 Correctness Check - Short=3, Long=5)
test20: directories $(BIN_DIR)/test20_stageA_engine

$(BIN_DIR)/test20_stageA_engine: stageA/test20_stageA.c \
                          indicators/vwap.c \
                          indicators/ohlc.c \
                          indicators/sma.c \
                          indicators/signal.c \
                          common/trade_io.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# ==============================================================================
# --- Stage A+ Targets ---
# ==============================================================================

# Full Stage A+ Engine (linking ALL modules with fast_reader instead of trade_io)
stageA_plus: directories $(BIN_DIR)/stageA_plus_engine

$(BIN_DIR)/stageA_plus_engine: stageA+/main_stageA+.c \
                               indicators/vwap.c \
                               indicators/ohlc.c \
                               indicators/sma.c \
                               indicators/signal.c \
                               common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# ==============================================================================
# --- Stage B Targets ---
# ==============================================================================

# Meta-target to build both Stage B SMA variants
stageB: stageB_naive stageB_running

# Stage B Naive SMA Engine (O(N) Re-adding window each trade)
stageB_naive: directories $(BIN_DIR)/stageB_naive_engine

$(BIN_DIR)/stageB_naive_engine: stageB/main_stageB.c \
                               indicators/vwap.c \
                               indicators/ohlc.c \
                               indicators/sma.c \
                               indicators/signal.c \
                               common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Stage B Running-Sum SMA Engine (O(1) Constant Time sliding window)
stageB_running: directories $(BIN_DIR)/stageB_running_engine

$(BIN_DIR)/stageB_running_engine: stageB/main_stageB_running.c \
                                 indicators/vwap.c \
                                 indicators/ohlc.c \
                                 indicators/sma.c \
                                 indicators/signal.c \
                                 common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Fixed-Point Integer Stage B Engine (long long arithmetic)
stageB_fp: directories $(BIN_DIR)/stageB_fp_engine

$(BIN_DIR)/stageB_fp_engine: stageB/main_stageB_fixedpoint.c \
                            indicators/vwap.c \
                            indicators/ohlc.c \
                            indicators/signal.c \
                            common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Dynamic Memory Stage B Engine (malloc)
stageB_malloc: directories $(BIN_DIR)/stageB_malloc_engine

$(BIN_DIR)/stageB_malloc_engine: stageB/main_stageB_malloc.c \
                                indicators/vwap.c \
                                indicators/ohlc.c \
                                indicators/sma.c \
                                indicators/signal.c \
                                common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# Helper targets for quickly running Stage B benchmarks individually
run_stageB_naive: stageB_naive
	./$(BIN_DIR)/stageB_naive_engine

run_stageB_running: stageB_running
	./$(BIN_DIR)/stageB_running_engine

# ==============================================================================
# --- Stage C Targets ---
# ==============================================================================

# Stage C Real-Time Replay Engine & Rival Bot Simulator
stageC: directories $(BIN_DIR)/stageC_engine

$(BIN_DIR)/stageC_engine: stageC/main_stageC.c \
                        indicators/vwap.c \
                        indicators/ohlc.c \
                        indicators/sma.c \
                        indicators/signal.c \
                        common/fast_reader.c
	$(CC) $(CFLAGS) -O2 $^ -o $@

# ==============================================================================
# --- Plot Targets (Outputs to plots/ directory with BUY/SELL markers) ---
# ==============================================================================

# Plot using Stage A Engine (trade_io)
plot_stageA: stageA directories
	@echo "Running Stage A Engine to write $(PLOTS_DIR)/signals_stageA.dat..."
	./$(BIN_DIR)/stageA_engine
	@echo "Rendering $(PLOTS_DIR)/signals_stageA.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals_stageA.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage A)'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals_stageA.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals_stageA.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals_stageA.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals_stageA.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals_stageA.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals_stageA.png"

# Plot using Stage A+ Engine (fast_reader)
plot_stageA_plus: stageA_plus directories
	@echo "Running Stage A+ Engine to write $(PLOTS_DIR)/signals.dat..."
	./$(BIN_DIR)/stageA_plus_engine
	@echo "Rendering $(PLOTS_DIR)/signals.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage A+)'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals.png"

# Plot using Stage B Naive Engine
plot_stageB_naive: stageB_naive directories
	@echo "Running Stage B Naive Engine to write $(PLOTS_DIR)/signals_stageB_naive.dat..."
	./$(BIN_DIR)/stageB_naive_engine
	@echo "Rendering $(PLOTS_DIR)/signals_stageB_naive.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals_stageB_naive.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage B Naive O(N))'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals_stageB_naive.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals_stageB_naive.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals_stageB_naive.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals_stageB_naive.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals_stageB_naive.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals_stageB_naive.png"

# Plot using Stage B Running-Sum Engine
plot_stageB_running: stageB_running directories
	@echo "Running Stage B Running-Sum Engine to write $(PLOTS_DIR)/signals_stageB_running.dat..."
	./$(BIN_DIR)/stageB_running_engine
	@echo "Rendering $(PLOTS_DIR)/signals_stageB_running.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals_stageB_running.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage B Running-Sum O(1))'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals_stageB_running.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals_stageB_running.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals_stageB_running.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals_stageB_running.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals_stageB_running.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals_stageB_running.png"

# Plot using Stage B Fixed-Point Engine
plot_stageB_fp: stageB_fp directories
	@echo "Running Stage B Fixed-Point Engine to write $(PLOTS_DIR)/signals_stageB_fp.dat..."
	./$(BIN_DIR)/stageB_fp_engine
	@echo "Rendering $(PLOTS_DIR)/signals_stageB_fp.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals_stageB_fp.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage B Fixed-Point long long)'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals_stageB_fp.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals_stageB_fp.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals_stageB_fp.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals_stageB_fp.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals_stageB_fp.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals_stageB_fp.png"

# Plot using Stage B Malloc Engine
plot_stageB_malloc: stageB_malloc directories
	@echo "Running Stage B Malloc Engine to write $(PLOTS_DIR)/signals_stageB_malloc.dat..."
	./$(BIN_DIR)/stageB_malloc_engine
	@echo "Rendering $(PLOTS_DIR)/signals_stageB_malloc.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/signals_stageB_malloc.png'; \
	            set title 'Trade Price and SMA Crossovers (Stage B Malloc)'; \
	            set xlabel 'Trade Number'; \
	            set ylabel 'Price (USDT)'; \
	            set grid; \
	            plot '$(PLOTS_DIR)/signals_stageB_malloc.dat' using 1:2 title 'Price' with lines linecolor rgb '#888888', \
	                 '$(PLOTS_DIR)/signals_stageB_malloc.dat' using 1:3 title 'Short SMA' with lines linecolor rgb '#ff0000', \
	                 '$(PLOTS_DIR)/signals_stageB_malloc.dat' using 1:4 title 'Long SMA' with lines linecolor rgb '#0000ff', \
	                 '$(PLOTS_DIR)/signals_stageB_malloc.dat' using 1:(\$$5==1?\$$2:NaN) title 'BUY' with points pt 7 ps 1.5 linecolor rgb '#00cc00', \
	                 '$(PLOTS_DIR)/signals_stageB_malloc.dat' using 1:(\$$5==-1?\$$2:NaN) title 'SELL' with points pt 7 ps 1.5 linecolor rgb '#ff0000'"
	@echo "Done! Saved to $(PLOTS_DIR)/signals_stageB_malloc.png"

# Plot using Stage C Rival Bot Sweep
plot_stageC: stageC directories
	@echo "Running Stage C Engine to write $(PLOTS_DIR)/rival_sweep.dat..."
	./$(BIN_DIR)/stageC_engine 1000
	@echo "Rendering $(PLOTS_DIR)/rival_sweep.png with gnuplot..."
	gnuplot -e "set terminal png size 1200,600; \
	            set output '$(PLOTS_DIR)/rival_sweep.png'; \
	            set title 'Rival Bot Simulation: P&L vs Rival Reaction Time (R)'; \
	            set xlabel 'Rival Reaction Time R (microseconds)'; \
	            set ylabel 'Realized P&L (USDT)'; \
	            set logscale x; \
	            set grid; \
	            plot '$(PLOTS_DIR)/rival_sweep.dat' using 1:2 title 'Engine P&L' with linespoints pt 7 ps 1.5 linecolor rgb '#00aa00'"
	@echo "Done! Saved to $(PLOTS_DIR)/rival_sweep.png"

# ==============================================================================
# --- Clean Rule ---
# ==============================================================================
clean:
	rm -rf $(BIN_DIR) $(PLOTS_DIR)