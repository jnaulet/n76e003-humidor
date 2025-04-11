# OpenPicoRTOS basic makefile template
# 'target' is the binary OpenPicoRTOS build system will create
target := n76e003-humidor.ihx

# All your sources can be put insinde 'c_src-y' for c and 'a_src-y' for assembly
c_src-y += main.c
c_src-y += n76e003.c

# This makefile will be included by OpenPicoRTOS during build, it is safer to use
# the 'skip-makefile' keyword to avoid local targets inclusion
ifneq ($(skip-makefile),1)
PWD := $(shell pwd)
# 'PICORTOS_SRC' is the directory containing the OpenPicoRTOS original sources
PICORTOS_SRC := ../OpenPicoRTOS-dev
NUVOPROG := ~/go/bin/nuvoprog

all: $(target)
	@

$(target): FORCE
	$(Q)$(MAKE) -C $(PICORTOS_SRC) O=$(PWD)

%:
	$(Q)$(MAKE) -C $(PICORTOS_SRC) O=$(PWD) $@

upload: $(target)
	$(NUVOPROG) program -i $< -t n76e003 -c @config.json

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)
endif
