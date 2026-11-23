@echo off
setlocal

set OUT=02-median_wsl

wsl bash -c "set -u; OUT='%OUT%'; : > \"\$OUT\"; ENGINES=(stageA_engine stageA_plus_engine stageB_naive_engine stageB_running_engine stageB_fp_engine stageB_malloc_engine stageC_engine); DATA='Datasets/Group09/stress_full.csv'; run_suite() { local opt=\"\$1\"; make clean && make OPT=\"\$opt\" stageA stageA_plus stageB stageC; for bin in \"\${ENGINES[@]}\"; do echo '=========================================='; echo \"=== WSL (\$opt): \$bin ===\"; echo '=========================================='; for i in 1 2 3 4 5; do echo \"--- Trial \$i (\$opt, \$bin) ---\"; taskset -c 0 ./bin/\"\$bin\" \"\$DATA\"; done; if command -v perf >/dev/null 2>&1; then echo \"--- perf stat (\$opt, \$bin) ---\"; perf stat -r 5 -e task-clock,context-switches,cpu-migrations,page-faults taskset -c 0 ./bin/\"\$bin\" \"\$DATA\" 2>&1 || true; fi; echo \"--- Disassembly (\$opt, \$bin) ---\"; objdump -d -S -C -M intel ./bin/\"\$bin\" | awk '/<main>|<(stage|calc|sma|vwap|ohlc|signal|parse|med|alloc|init|step|run)[a-zA-Z0-9_]*>:/ { printing=1; print \"\"; print \$0; next } /^$/ { if (printing) { print \"\"; printing=0 }; next } { if (printing) print \$0 }' | head -n 160; done; }; { echo \"Host: \$(uname -a)\"; echo \"\"; run_suite '-O0'; run_suite '-O2'; } 2>&1 | tee -a \"\$OUT\""

endlocal