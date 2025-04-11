#ifndef N76E003_H
#define N76E003_H

#include "gpio-n76e003.h"
#include "uart-n76e003.h"
#include "pwm-n76e003.h"
#include "twi-n76e003.h"

struct n76e003 {
    struct gpio L;
    struct uart UART0;
    struct pwm MIST;
    struct twi I2C;
};

int n76e003_init(/*@out@*/ struct n76e003 *ctx);

#endif
