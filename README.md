# n76e003-humidor

This is the source code for the Ultrasonic Humidor project on Thingiverse: https://www.thingiverse.com/thing:7033608

# How to build

You will need SDCC in order to build this project. Once it's installed,
just type:

```
 $ make
```

# How to program

Use a Nuvoton Nu-Link1 probe to program the firmware.

If you're under windows you can use the tools provided by Nuvoton.

If you're under linux, try nuvoprog by Erin Shepherd : https://github.com/erincandescent/nuvoprog

Or my EXPERIMENTAL port of her software (in C): https://github.com/jnaulet/nuvoprog-c
