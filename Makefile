include picoRTOS/Makefile.in

SDCC := sdcc
SDAS := sdas8051

target := n76e003-humidor.ihx

CFLAGS := --std-c99 --fomit-frame-pointer --opt-code-size
CFLAGS += -mmcs51 --model-large --stack-auto --int-long-reent
CFLAGS += --xram-size 768 --code-size 18432
CFLAGS += -D"__ATTRIBUTE_ALIGNED__(x)="
CFLAGS +=-D"__ATTRIBUTE_UNUSED__="
CFLAGS +=-D"__ATTRIBUTE_NAKED__=__naked"
CFLAGS +=-D"__ATTRIBUTE_PACKED__="
CFLAGS += -Iinclude $(include-y)

AFLAGS := -Iinclude $(include-y) -los

c_src-y += main.c
c_src-y += n76e003.c

OBJ := $(c_src-y:%.c=%.rel)
OBJ += $(a_src-y:%.S=%.rel)

all: $(target)
	@

$(target): $(OBJ)
	$(SDCC) $(CFLAGS) $< -o $@

%.rel: %.c
	$(SDCC) $(CFLAGS) -o $@ -c $<

%.rel: %.S
	$(SDAS) $(AFLAGS) -o $@ $<

clean:
	@rm -f $(OBJ) $(OBJ:%.rel=%.sym) $(OBJ:%.rel=%.lk)
	@rm -f $(OBJ:%.rel=%.lst) $(OBJ:%.rel=%.rst) 
