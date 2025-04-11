#include "picoRTOS.h"
#include "picoRTOS_device.h"

#include "n76e003.h"

static bool needs_misting = false;

static void led_main(void *priv)
{
    picoRTOS_assert_fatal(priv != NULL, return );

    struct gpio *L = (struct gpio*)priv;
    picoRTOS_tick_t ref = picoRTOS_get_tick();

    for (;;) {
        gpio_write(L, false);
        picoRTOS_sleep(PICORTOS_DELAY_MSEC(60ul));
        gpio_write(L, true);
        picoRTOS_sleep(PICORTOS_DELAY_MSEC(60ul));
        gpio_write(L, false);
        picoRTOS_sleep(PICORTOS_DELAY_MSEC(120ul));
        gpio_write(L, true);

        /* until next second */
        picoRTOS_sleep_until(&ref, PICORTOS_DELAY_SEC(1));
    }
}

static void mist_main(void *priv)
{
#define MIST_RUNTIME PICORTOS_DELAY_SEC(10)
    picoRTOS_assert_fatal(priv != NULL, return );

    struct pwm *MIST = (struct pwm*)priv;

    /* default value */
    (void)pwm_set_duty_cycle(MIST, PWM_DUTY_CYCLE_PCENT(0));

    for (;;) {
        if (!needs_misting) {
            picoRTOS_schedule();
            continue;
        }

        (void)pwm_set_duty_cycle(MIST, PWM_DUTY_CYCLE_PCENT(50));
        picoRTOS_sleep(MIST_RUNTIME);
        (void)pwm_set_duty_cycle(MIST, PWM_DUTY_CYCLE_PCENT(0));
    }
}

static void uart_send(struct uart *UART, char *buf, size_t n)
{
    int deadlock = 100;

    for (int i = 0; i < n; ) {
        int res;
        if ((res = uart_write(UART, &buf[i], n - i)) < 0 &&  deadlock-- != 0) {
            picoRTOS_postpone();
            continue;
        }

        /* inc */
        picoRTOS_assert(deadlock != -1, return );
        i += res;
    }
}

static void uart_send_hex_c(struct uart *UART, char c)
{
#define HEX_DIGIT(x) ('0' + (((x) > 9) ? (x) + 7 : (x)))
    int i = 0;
    static char digit[2];

    digit[i++] = (char)HEX_DIGIT(0xf & (c >> 4));
    digit[i++] = (char)HEX_DIGIT(0xf & c);
    /* safe send */
    uart_send(UART, digit, sizeof(digit));
#undef HEX_DIGIT
}

static void uart_send_hex(struct uart *UART, char *buf, size_t n)
{
    while (n-- != 0)
        uart_send_hex_c(UART, *buf++);
}

static int twi_send(struct twi *TWI, char *buf, size_t n, int flags)
{
    int deadlock = 100;

    for (int i = 0; i < n; ) {
        int res;
        if ((res = twi_write(TWI, &buf[i], sizeof(buf) - i, flags)) < 0 &&
            deadlock-- != 0) {
            picoRTOS_postpone();
            continue;
        }

        /* inc */
        picoRTOS_assert(deadlock != -1, return -EIO);
        i += res;
    }

    return (int)n;
}

static int twi_recv(struct twi *TWI, char *buf, size_t n, int flags)
{
    int deadlock = 100;

    for (int i = 0; i < n; ) {
        int res;
        if ((res = twi_read(TWI, &buf[i], n - (size_t)i, flags)) < 0 &&
            deadlock-- != 0) {
            picoRTOS_postpone();
            continue;
        }

        /* inc */
        picoRTOS_assert(deadlock != -1, return -EIO);
        i += res;
    }

    return (int)n;
}

#define HR_TEMP_TABLE_COUNT 50
static const int hr_temp_table[HR_TEMP_TABLE_COUNT] = {
    97, 97, 97, 97, 97, 97, 97, 97, 97, 97, /* 0-10°C */
    97, 97, 97, 97, 95, 90, 85, 80, 75, 70, /* 11-20°C */
    67, 62, 56, 52, 50, 47, 44, 42, 40, 38, /* 21-30°C */
    36, 34, 32, 31, 29, 26, 25, 24, 23, 22, /* 31-40°C */
    21, 20, 19, 18, 17, 16, 15, 14, 13, 12  /* 41-50°C */
};

static void sensors_main(void *priv)
{
#define TEMP_CORRECTION -5 /* The chip is very optimistic */
    picoRTOS_assert_fatal(priv != NULL, return );

    struct n76e003 *ctx = (struct n76e003*)priv;
    picoRTOS_tick_t ref = picoRTOS_get_tick();

    /* sensor needs a >= 100ms delay */
    picoRTOS_sleep(PICORTOS_DELAY_MSEC(120l));

    for (;;) {

        int res;
        static char buf[8];

        /* send mesurement command */
        if ((res = twi_send(&ctx->I2C, "\xac\x33\x00", (size_t)3, TWI_F_START | TWI_F_STOP)) < 0) {
            uart_send(&ctx->UART0, ":write error\r\n", (size_t)14);
            goto next;
        }

        /* wait until measurement is done */
        picoRTOS_sleep(PICORTOS_DELAY_MSEC(80l));

        if ((res = twi_recv(&ctx->I2C, buf, (size_t)7, TWI_F_START | TWI_F_STOP)) < 0) {
            uart_send(&ctx->UART0, ":read error\r\n", (size_t)13);
            goto next;
        }

        int rh = (int)((((unsigned long)buf[1] << 12 |
                         (unsigned long)buf[2] << 4 |
                         (unsigned long)buf[3] >> 4) * 100ul) >> 20);
        int t = (int)((((unsigned long)(buf[3] & 0xf) << 16 |
                        (unsigned long)buf[4] << 8 |
                        (unsigned long)buf[5]) * 200ul) >> 20) - 50 + TEMP_CORRECTION;

        /* display result (hopefully) */
        uart_send(&ctx->UART0, ": 0x", (size_t)5);
        uart_send_hex_c(&ctx->UART0, rh);
        uart_send(&ctx->UART0, " % - 0x", (size_t)8);
        uart_send_hex_c(&ctx->UART0, t);
        uart_send(&ctx->UART0, " °C", (size_t)4);

        /* produce mist */
        if (rh < hr_temp_table[t]) {
            needs_misting = true;
            uart_send(&ctx->UART0, " - X", (size_t)4);
        }else
            needs_misting = false;

        uart_send(&ctx->UART0, "\r\n", (size_t)2);
next:
        picoRTOS_sleep_until(&ref, PICORTOS_DELAY_SEC(5));
    }
}

int main(void)
{
    static struct n76e003 n76e003;

    struct picoRTOS_task task;
    static picoRTOS_stack_t stack0[CONFIG_DEFAULT_STACK_COUNT];
    static picoRTOS_stack_t stack1[CONFIG_DEFAULT_STACK_COUNT];
    static picoRTOS_stack_t stack2[CONFIG_DEFAULT_STACK_COUNT * 2];

    picoRTOS_init();
    (void)n76e003_init(&n76e003);

    /* led */
    picoRTOS_task_init(&task, led_main, &n76e003.L, stack0, PICORTOS_STACK_COUNT(stack0));
    picoRTOS_add_task(&task, picoRTOS_get_next_available_priority());
    /* mist */
    picoRTOS_task_init(&task, mist_main, &n76e003.MIST, stack1, PICORTOS_STACK_COUNT(stack1));
    picoRTOS_add_task(&task, picoRTOS_get_next_available_priority());
    /* sensors */
    picoRTOS_task_init(&task, sensors_main, &n76e003, stack2, PICORTOS_STACK_COUNT(stack2));
    picoRTOS_add_task(&task, picoRTOS_get_next_available_priority());

    picoRTOS_start();

    /* not supposed to end there */
    picoRTOS_assert_void(false);
    return 1;
}
