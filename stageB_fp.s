	.arch armv8-a
	.file	"main_stageB_fixedpoint.c"
	.text
	.align	2
	.p2align 5,,15
	.global	sma_fp_init
	.type	sma_fp_init, %function
sma_fp_init:
.LFB13:
	.cfi_startproc
	add	x2, x0, 1024
	str	w1, [x0, 800]
	str	xzr, [x2, -220]
	str	xzr, [x0, 816]
	ret
	.cfi_endproc
.LFE13:
	.size	sma_fp_init, .-sma_fp_init
	.align	2
	.p2align 5,,15
	.global	sma_fp_update
	.type	sma_fp_update, %function
sma_fp_update:
.LFB14:
	.cfi_startproc
	ldr	w3, [x0, 800]
	ldr	w4, [x0, 804]
	ldr	x5, [x0, 816]
	ldr	w2, [x0, 808]
	cmp	w4, w3
	bge	.L4
	str	x1, [x0, w2, sxtw 3]
	add	w2, w2, 1
	add	x1, x1, x5
	str	x1, [x0, 816]
	add	w4, w4, 1
	str	w4, [x0, 804]
	sdiv	w1, w2, w3
	msub	w1, w1, w3, w2
	str	w1, [x0, 808]
	ret
	.p2align 2,,3
.L4:
	ldr	x4, [x0, w2, sxtw 3]
	str	x1, [x0, w2, sxtw 3]
	add	w2, w2, 1
	sub	x5, x5, x4
	add	x1, x5, x1
	str	x1, [x0, 816]
	sdiv	w1, w2, w3
	msub	w1, w1, w3, w2
	str	w1, [x0, 808]
	ret
	.cfi_endproc
.LFE14:
	.size	sma_fp_update, .-sma_fp_update
	.align	2
	.p2align 5,,15
	.global	sma_fp_is_full
	.type	sma_fp_is_full, %function
sma_fp_is_full:
.LFB15:
	.cfi_startproc
	ldr	w1, [x0, 800]
	ldr	w0, [x0, 804]
	cmp	w0, w1
	cset	w0, eq
	ret
	.cfi_endproc
.LFE15:
	.size	sma_fp_is_full, .-sma_fp_is_full
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"Error: Could not open DEV dataset.\n"
	.align	3
.LC1:
	.string	"Loaded %d trades into Fixed-Point RAM. Starting benchmark...\n"
	.align	3
.LC2:
	.string	"w"
	.align	3
.LC3:
	.string	"plots/signals_stageB_fp.dat"
	.align	3
.LC4:
	.string	"%d %.8f %.8f %.8f %d\n"
	.align	3
.LC5:
	.string	"\n==================== STAGE B (FIXED-POINT LONG LONG) ====================\n"
	.align	3
.LC6:
	.string	"Total Trades Processed : %d\n"
	.align	3
.LC7:
	.string	"BUY Signals Raised     : %d\n"
	.align	3
.LC8:
	.string	"SELL Signals Raised    : %d\n"
	.align	3
.LC9:
	.string	"Total Run Time         : %llu ns (%.3f ms)\n"
	.align	3
.LC10:
	.string	"Time Per Trade         : %.2f ns/trade\n"
	.align	3
.LC11:
	.string	"Throughput             : %.2f trades/sec\n"
	.align	3
.LC12:
	.string	"=========================================================================\n"
	.section	.text.startup,"ax",@progbits
	.align	2
	.p2align 5,,15
	.global	main
	.type	main, %function
main:
.LFB17:
	.cfi_startproc
	sub	sp, sp, #2048
	.cfi_def_cfa_offset 2048
	mov	w0, 2
	stp	x29, x30, [sp]
	.cfi_offset 29, -2048
	.cfi_offset 30, -2040
	mov	x29, sp
	bl	open_data
	cbz	w0, .L8
	adrp	x7, trades_fp
	mov	x0, 236961935654912
	stp	x23, x24, [sp, 48]
	.cfi_offset 24, -1992
	.cfi_offset 23, -2000
	mov	w24, 16960
	movk	x0, 0x4197, lsl 48
	stp	x25, x26, [sp, 64]
	.cfi_offset 26, -1976
	.cfi_offset 25, -1984
	add	x26, x7, :lo12:trades_fp
	add	x23, sp, 228
	movk	w24, 0xf, lsl 16
	stp	x19, x20, [sp, 16]
	.cfi_offset 20, -2024
	.cfi_offset 19, -2032
	mov	x19, x26
	add	x20, sp, 232
	stp	x21, x22, [sp, 32]
	.cfi_offset 22, -2008
	.cfi_offset 21, -2016
	add	x22, sp, 248
	add	x21, sp, 240
	stp	x27, x28, [sp, 80]
	.cfi_offset 28, -1960
	.cfi_offset 27, -1968
	mov	w28, 0
	stp	d13, d14, [sp, 96]
	.cfi_offset 78, -1944
	.cfi_offset 77, -1952
	fmov	d14, 5.0e-1
	str	d15, [sp, 112]
	.cfi_offset 79, -1936
	fmov	d15, x0
	b	.L9
	.p2align 2,,3
.L12:
	ldp	d30, d31, [sp, 240]
	add	w28, w28, 1
	ldr	w0, [sp, 228]
	add	x19, x19, 32
	str	w0, [x19, -8]
	fmadd	d30, d30, d15, d14
	fmadd	d31, d31, d15, d14
	ldr	x0, [sp, 232]
	fcvtzs	d30, d30
	fcvtzs	d31, d31
	fmov	x1, d30
	str	d31, [x19, -16]
	stp	x0, x1, [x19, -32]
	cmp	w28, w24
	beq	.L11
.L9:
	mov	x3, x23
	mov	x2, x22
	mov	x1, x21
	mov	x0, x20
	bl	read_trade
	cbnz	w0, .L12
	adrp	x22, :got:stderr;ldr	x22, [x22, :got_lo12:stderr]
	bl	close_trades
	mov	w2, w28
	adrp	x1, .LC1
	add	x1, x1, :lo12:.LC1
	add	x27, sp, 1224
	ldr	x0, [x22]
	bl	fprintf
	add	x0, sp, 256
	str	x0, [sp, 160]
	bl	vwap_init
	add	x0, sp, 304
	str	x0, [sp, 152]
	bl	ohlc_init
	add	x0, sp, 272
	bl	signal_init
	adrp	x1, .LC2
	adrp	x0, .LC3
	add	x1, x1, :lo12:.LC2
	add	x0, x0, :lo12:.LC3
	bl	fopen
	str	x0, [sp, 184]
	mov	x1, x27
	mov	w0, 1
	bl	clock_gettime
	ldr	x1, [sp, 1224]
	mov	x0, 51712
	movk	x0, 0x3b9a, lsl 16
	ldr	x2, [sp, 1232]
	mul	x0, x1, x0
	stp	x2, x0, [sp, 200]
	cbz	w28, .L28
	str	w28, [sp, 168]
.L27:
	ldr	x0, [sp, 184]
	add	x20, sp, 400
	mov	x19, 0
	mov	w21, 0
	cmp	x0, 0
	mov	x25, x19
	cset	w0, ne
	str	w0, [sp, 172]
	add	x0, sp, 352
	mov	x11, x20
	mov	x9, 0
	mov	x20, x27
	mov	w5, 0
	mov	w12, 0
	mov	w19, w5
	mov	x27, x9
	str	x0, [sp, 176]
	mov	x0, 236961935654912
	str	x22, [sp, 216]
	mov	w22, w21
	mov	x21, x26
	mov	w26, w12
	mov	w28, 0
	movk	x0, 0x4197, lsl 48
	mov	w23, 0
	mov	w24, 100
	fmov	d13, x0
	stp	wzr, w28, [sp, 192]
	.p2align 5,,15
.L25:
	str	x11, [sp, 144]
	ldr	d1, [x21, 16]
	ldp	x1, x2, [x21]
	str	x1, [sp, 136]
	scvtf	d1, d1
	ldr	x0, [sp, 160]
	fdiv	d1, d1, d13
	fmov	d15, x2
	scvtf	d14, d15
	fdiv	d14, d14, d13
	fmov	d0, d14
	bl	vwap_update
	fmov	d0, d14
	ldr	x1, [sp, 136]
	ldr	x0, [sp, 152]
	ldr	x2, [sp, 176]
	bl	ohlc_update
	ldr	x11, [sp, 144]
	cmp	w23, 14
	bgt	.L14
	fmov	x0, d15
	add	w23, w23, 1
	add	x25, x25, x0
	sxtw	x0, w28
.L15:
	add	w4, w28, 1
	str	d15, [x11, x0, lsl 3]
	mov	w0, 15
	sdiv	w1, w4, w0
	lsl	w0, w1, 4
	sub	w0, w0, w1
	sub	w28, w4, w0
	cmp	w26, 99
	bgt	.L16
	fmov	x0, d15
	add	w26, w26, 1
	add	x27, x27, x0
	sxtw	x0, w19
.L17:
	add	w19, w19, 1
	str	d15, [x20, x0, lsl 3]
	cmp	w26, 100
	ccmp	w23, 15, 0, eq
	sdiv	w0, w19, w24
	msub	w19, w0, w24, w19
	beq	.L18
.L23:
	mov	w3, 0
.L19:
	mov	w0, -9999
	add	w0, w22, w0
	cmp	w0, 2000
	ldr	w0, [sp, 172]
	add	w22, w22, 1
	ccmp	w0, 0, 4, ls
	bne	.L37
.L24:
	ldr	w0, [sp, 168]
	add	x21, x21, 32
	cmp	w22, w0
	bne	.L25
	ldr	x22, [sp, 216]
	ldr	w28, [sp, 196]
.L13:
	add	x1, sp, 288
	mov	w0, 1
	bl	clock_gettime
	ldp	x21, x20, [sp, 288]
	mov	x0, 51712
	movk	x0, 0x3b9a, lsl 16
	mul	x21, x21, x0
	ldr	x0, [sp, 200]
	sub	x21, x21, x0
	ldr	x0, [sp, 184]
	cbz	x0, .L26
	bl	fclose
.L26:
	ldr	x0, [sp, 208]
	mov	x2, 75
	ldr	w19, [sp, 168]
	mov	x1, 1
	sub	x20, x20, x0
	adrp	x0, .LC5
	add	x20, x20, x21
	add	x0, x0, :lo12:.LC5
	ldr	x3, [x22]
	ucvtf	d15, x20
	scvtf	d14, w19
	bl	fwrite
	ldr	x0, [x22]
	mov	w2, w19
	adrp	x1, .LC6
	add	x1, x1, :lo12:.LC6
	bl	fprintf
	ldr	x0, [x22]
	mov	w2, w28
	adrp	x1, .LC7
	add	x1, x1, :lo12:.LC7
	bl	fprintf
	ldr	x0, [x22]
	adrp	x1, .LC8
	ldr	w2, [sp, 192]
	add	x1, x1, :lo12:.LC8
	bl	fprintf
	mov	x0, 145685290680320
	mov	x2, x20
	movk	x0, 0x412e, lsl 48
	fmov	d0, x0
	ldr	x0, [x22]
	adrp	x1, .LC9
	fdiv	d0, d15, d0
	add	x1, x1, :lo12:.LC9
	bl	fprintf
	fdiv	d0, d15, d14
	adrp	x1, .LC10
	ldr	x0, [x22]
	add	x1, x1, :lo12:.LC10
	bl	fprintf
	mov	x0, 225833675390976
	adrp	x1, .LC11
	movk	x0, 0x41cd, lsl 48
	fmov	d31, x0
	ldr	x0, [x22]
	add	x1, x1, :lo12:.LC11
	fdiv	d0, d15, d31
	fdiv	d0, d14, d0
	bl	fprintf
	ldr	x3, [x22]
	adrp	x0, .LC12
	mov	x2, 74
	add	x0, x0, :lo12:.LC12
	mov	x1, 1
	bl	fwrite
	ldp	x19, x20, [sp, 16]
	.cfi_restore 20
	.cfi_restore 19
	mov	w0, 0
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	ldp	x23, x24, [sp, 48]
	.cfi_restore 24
	.cfi_restore 23
	ldp	x25, x26, [sp, 64]
	.cfi_restore 26
	.cfi_restore 25
	ldp	x27, x28, [sp, 80]
	.cfi_restore 28
	.cfi_restore 27
	ldp	d13, d14, [sp, 96]
	.cfi_restore 78
	.cfi_restore 77
	ldr	d15, [sp, 112]
	.cfi_restore 79
.L7:
	ldp	x29, x30, [sp]
	add	sp, sp, 2048
	.cfi_restore 29
	.cfi_restore 30
	.cfi_def_cfa_offset 0
	ret
	.p2align 2,,3
.L18:
	.cfi_def_cfa_offset 2048
	.cfi_offset 19, -2032
	.cfi_offset 20, -2024
	.cfi_offset 21, -2016
	.cfi_offset 22, -2008
	.cfi_offset 23, -2000
	.cfi_offset 24, -1992
	.cfi_offset 25, -1984
	.cfi_offset 26, -1976
	.cfi_offset 27, -1968
	.cfi_offset 28, -1960
	.cfi_offset 29, -2048
	.cfi_offset 30, -2040
	.cfi_offset 77, -1952
	.cfi_offset 78, -1944
	.cfi_offset 79, -1936
	add	x0, x25, x25, lsl 2
	ldr	w3, [sp, 280]
	sub	x1, x27, x27, lsl 4
	add	x0, x0, x0, lsl 2
	add	x0, x1, x0, lsl 2
	scvtf	d31, x0
	cbz	w3, .L38
	ldr	d30, [sp, 272]
	fcmpe	d30, #0.0
	ccmp	x0, 0, 4, ls
	bgt	.L21
	fcmpe	d30, #0.0
	ccmp	x0, 0, 0, ge
	blt	.L39
	str	d31, [sp, 272]
	b	.L23
	.p2align 2,,3
.L16:
	ldr	x1, [x20, w19, sxtw 3]
	fmov	x2, d15
	sxtw	x0, w19
	sub	x1, x27, x1
	add	x27, x1, x2
	b	.L17
	.p2align 2,,3
.L14:
	ldr	x1, [x11, w28, sxtw 3]
	fmov	x2, d15
	sxtw	x0, w28
	sub	x1, x25, x1
	add	x25, x1, x2
	b	.L15
	.p2align 2,,3
.L39:
	ldr	w0, [sp, 192]
	mov	w3, -1
	str	d31, [sp, 272]
	add	w0, w0, 1
	str	w0, [sp, 192]
	mov	w0, -9999
	add	w0, w22, w0
	cmp	w0, 2000
	ldr	w0, [sp, 172]
	add	w22, w22, 1
	ccmp	w0, 0, 4, ls
	beq	.L24
.L37:
	adrp	x0, .LC13
	scvtf	d31, x27
	fmov	d0, d14
	mov	w2, w22
	ldr	d2, [x0, #:lo12:.LC13]
	adrp	x0, .LC14
	adrp	x1, .LC4
	add	x1, x1, :lo12:.LC4
	ldr	d1, [x0, #:lo12:.LC14]
	fdiv	d2, d31, d2
	scvtf	d31, x25
	ldr	x0, [sp, 184]
	str	x11, [sp, 136]
	fdiv	d1, d31, d1
	bl	fprintf
	ldr	x11, [sp, 136]
	b	.L24
	.p2align 2,,3
.L38:
	mov	w0, 1
	str	d31, [sp, 272]
	str	w0, [sp, 280]
	b	.L19
	.p2align 2,,3
.L21:
	ldr	w0, [sp, 196]
	mov	w3, 1
	str	d31, [sp, 272]
	add	w0, w0, 1
	str	w0, [sp, 196]
	b	.L19
.L8:
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 27
	.cfi_restore 28
	.cfi_restore 77
	.cfi_restore 78
	.cfi_restore 79
	adrp	x3, :got:stderr;ldr	x3, [x3, :got_lo12:stderr]
	adrp	x0, .LC0
	mov	x2, 35
	add	x0, x0, :lo12:.LC0
	mov	x1, 1
	ldr	x3, [x3]
	bl	fwrite
	mov	w0, 1
	b	.L7
.L11:
	.cfi_offset 19, -2032
	.cfi_offset 20, -2024
	.cfi_offset 21, -2016
	.cfi_offset 22, -2008
	.cfi_offset 23, -2000
	.cfi_offset 24, -1992
	.cfi_offset 25, -1984
	.cfi_offset 26, -1976
	.cfi_offset 27, -1968
	.cfi_offset 28, -1960
	.cfi_offset 77, -1952
	.cfi_offset 78, -1944
	.cfi_offset 79, -1936
	adrp	x22, :got:stderr;ldr	x22, [x22, :got_lo12:stderr]
	bl	close_trades
	mov	w2, w28
	adrp	x1, .LC1
	add	x1, x1, :lo12:.LC1
	add	x27, sp, 1224
	ldr	x0, [x22]
	bl	fprintf
	add	x0, sp, 256
	str	x0, [sp, 160]
	bl	vwap_init
	add	x0, sp, 304
	str	x0, [sp, 152]
	bl	ohlc_init
	add	x0, sp, 272
	bl	signal_init
	adrp	x1, .LC2
	adrp	x0, .LC3
	add	x1, x1, :lo12:.LC2
	add	x0, x0, :lo12:.LC3
	bl	fopen
	str	x0, [sp, 184]
	mov	x1, x27
	mov	w0, 1
	bl	clock_gettime
	str	w28, [sp, 168]
	ldr	x1, [sp, 1224]
	mov	x0, 51712
	movk	x0, 0x3b9a, lsl 16
	ldr	x2, [sp, 1232]
	mul	x0, x1, x0
	stp	x2, x0, [sp, 200]
	b	.L27
.L28:
	str	wzr, [sp, 168]
	str	wzr, [sp, 192]
	b	.L13
	.cfi_endproc
.LFE17:
	.size	main, .-main
	.section	.rodata.cst8,"aM",@progbits,8
	.align	3
.LC13:
	.word	536870912
	.word	1107468383
	.align	3
.LC14:
	.word	-1073741824
	.word	1104566795
	.bss
	.align	4
	.type	trades_fp, %object
	.size	trades_fp, 32000000
trades_fp:
	.zero	32000000
	.ident	"GCC: (Debian 14.2.0-19) 14.2.0"
	.section	.note.GNU-stack,"",@progbits
