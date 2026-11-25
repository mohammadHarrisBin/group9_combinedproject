/*
 * led.h  -  PM Mini Project helper (works on Windows, macOS, and Raspberry Pi 5 breadboard)
 */
#ifndef LED_H
#define LED_H

#include <stdio.h>
#include <stdlib.h>

#define LED_GREEN 0
#define LED_RED   1

// Physical GPIO BCM Pins wired on breadboard
#define GPIO_GREEN 17
#define GPIO_RED   27

static const char *led_name[2] = { "GREEN", "RED" };

#if defined(__linux__)
static int led_hw = 0;

static inline int exec_cmd(const char *cmd) {
    return system(cmd) == 0;
}
#endif

static inline void led_init(void) {
#if defined(__linux__)
    char cmd[128];
    // Configure GPIO 27 and 17 as output and drive them low (OFF) initially
    snprintf(cmd, sizeof(cmd), "pinctrl set %d op dl > /dev/null 2>&1 && pinctrl set %d op dl > /dev/null 2>&1", GPIO_GREEN, GPIO_RED);
    if (system(cmd) == 0) {
        led_hw = 1;
        return;
    }
    printf("[led.h] Breadboard GPIOs not available. Printing instead.\n");
#else
    printf("[led.h] No hardware LED on this computer. Printing instead.\n");
#endif
}

static inline void led_set(int led, int on) {
#if defined(__linux__)
    if (led_hw) {
        int pin = (led == LED_GREEN) ? GPIO_GREEN : GPIO_RED;
        char cmd[64];
        // dh = drive high (ON), dl = drive low (OFF)
        snprintf(cmd, sizeof(cmd), "pinctrl set %d %s > /dev/null 2>&1", pin, on ? "dh" : "dl");
        system(cmd);
        return;
    }
#endif
    printf("[LED %s %s]\n", led_name[led], on ? "ON" : "OFF");
}

static inline void led_on(int led)  { led_set(led, 1); }
static inline void led_off(int led) { led_set(led, 0); }

static inline void led_cleanup(void) {
#if defined(__linux__)
    if (led_hw) {
        char cmd[128];
        // Turn off both breadboard LEDs on exit
        snprintf(cmd, sizeof(cmd), "pinctrl set %d dl > /dev/null 2>&1 && pinctrl set %d dl > /dev/null 2>&1", GPIO_GREEN, GPIO_RED);
        system(cmd);
    }
#endif
}

#endif /* LED_H */