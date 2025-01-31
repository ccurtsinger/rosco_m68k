# Common makefile for software
#
# Copyright (c) 2020-2022 Ross Bamford and contributors
# See LICENSE

ifndef ROSCO_M68K_DIR
$(error ROSCO_M68K_DIR is not set)
endif

-include $(ROSCO_M68K_DIR)/user.mk

CPU?=68000
ARCH?=$(CPU)
TUNE?=$(CPU)

SYSINCDIR?=$(ROSCO_M68K_DIR)/code/software/libs/build/include
SYSLIBDIR?=$(ROSCO_M68K_DIR)/code/software/libs/build/lib

ifneq ($(ROSCO_M68K_HUGEROM),false)
LDSCRIPT?=$(SYSLIBDIR)/ld/serial/hugerom_rosco_m68k_program.ld
else
LDSCRIPT?=$(SYSLIBDIR)/ld/serial/rosco_m68k_program.ld
endif

DEFINES=-DROSCO_M68K
FLAGS=-ffreestanding -ffunction-sections -fdata-sections -fomit-frame-pointer	\
      -Wall -Wextra -Werror -Wno-unused-function -pedantic -I$(SYSINCDIR)			\
      -mcpu=$(CPU) -march=$(ARCH) -mtune=$(TUNE) -g -O2 $(DEFINES)
CFLAGS=-std=c11 $(FLAGS)
CXXFLAGS=-std=c++20 -fno-exceptions -fno-rtti $(FLAGS)
GCC_LIBS?=$(shell $(CC) --print-search-dirs \
          | grep libraries:\ = \
          | sed 's/libraries: =/-L/g' \
          | sed 's/:/\/ -L/g')
LIBS=$(EXTRA_LIBS) -lprintf -lcstdlib -lmachine -lstart_serial -lgcc
ASFLAGS=-mcpu=$(CPU) -march=$(ARCH)
VASMFLAGS=-Felf -m$(CPU) -quiet -Lnf $(DEFINES)
LDFLAGS=-T $(LDSCRIPT) -L $(SYSLIBDIR) -Map=$(MAP) --gc-sections --oformat=elf32-m68k $(EXTRA_LDFLAGS)

CC=m68k-elf-rosco-gcc
CXX=m68k-elf-rosco-g++
AS=m68k-elf-rosco-as
LD=m68k-elf-rosco-ld
NM=m68k-elf-rosco-nm
LD=m68k-elf-rosco-ld
OBJDUMP=m68k-elf-rosco-objdump
OBJCOPY=m68k-elf-rosco-objcopy
SIZE=m68k-elf-rosco-size
VASM=vasmm68k_mot
RM=rm -f
CP=cp
LSOF=lsof
KERMIT=kermit
SERIAL?=/dev/modem
BAUD?=9600

# GCC-version-specific settings
ifneq ($(findstring GCC,$(shell $(CC) --version 2>/dev/null)),)
CC_VERSION:=$(shell $(CC) -dumpfullversion)
CC_MAJOR:=$(firstword $(subst ., ,$(CC_VERSION)))
# If this is GCC 12, 13, or 14, add flag --param=min-pagesize=0 to CFLAGS
ifeq ($(CC_MAJOR),12)
CFLAGS+=--param=min-pagesize=0
endif
ifeq ($(CC_MAJOR),13)
CFLAGS+=--param=min-pagesize=0
endif
ifeq ($(CC_MAJOR),14)
CFLAGS+=--param=min-pagesize=0
endif
endif

# For systems without MMU support, aligning LOAD segments with pages is not needed
# In those cases, provide fake page sizes to both save space and remove RWX warnings
ifeq ($(CPU),68030)
LD_SUPPORT_MMU?=true
endif
ifeq ($(CPU),68040)
LD_SUPPORT_MMU?=true
endif
ifeq ($(CPU),68060)
LD_SUPPORT_MMU?=true
endif
LD_SUPPORT_MMU?=false
ifneq ($(LD_SUPPORT_MMU),true)
# Saves space in binaries, but will break MMU use
LDFLAGS+=-z max-page-size=16 -z common-page-size=16
endif

# Output config (assume name of directory)
PROGRAM_BASENAME=$(shell basename $(CURDIR))

# Set other output files using output basname
ELF=$(PROGRAM_BASENAME).elf
BINARY=$(PROGRAM_BASENAME).bin
DISASM=$(PROGRAM_BASENAME).dis
MAP=$(PROGRAM_BASENAME).map
SYM=$(PROGRAM_BASENAME).sym

# Assume source files in Makefile directory are source files for project
CSOURCES=$(wildcard *.c)
CXXSOURCES=$(wildcard *.cpp)
CINCLUDES=$(wildcard *.h)
SSOURCES=$(wildcard *.S)
ASMSOURCES=$(wildcard *.asm)
SOURCES=$(CSOURCES) $(CXXSOURCES) $(SSOURCES) $(ASMSOURCES)

# Assume each source files makes an object file
OBJECTS=$(addsuffix .o,$(basename $(SOURCES)))

TO_CLEAN=$(OBJECTS) $(ELF) $(BINARY) $(MAP) $(SYM) $(DISASM) $(addsuffix .lst,$(basename $(SSOURCES) $(ASMSOURCES)))

all: $(BINARY) $(DISASM)

$(ELF) : $(OBJECTS) $(ROM_OBJ)
	$(LD) $(LDFLAGS) $(GCC_LIBS) $^ $(LIBS) -o $@
	$(NM) --numeric-sort $@ >$(SYM)
	$(SIZE) $@
	-chmod a-x $@

$(BINARY) : $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(BINARY)

$(DISASM) : $(ELF)
	$(OBJDUMP) --disassemble -S $(ELF) >$(DISASM)

$(OBJECTS): Makefile

%.o : %.c $(CINCLUDES)
	$(CC) -c $(CFLAGS) $(EXTRA_CFLAGS) -o $@ $<

%.o : %.cpp
	$(CXX) -c $(CXXFLAGS) $(EXTRA_CXXFLAGS) -o $@ $<

%.o : %.asm
	$(VASM) $(VASMFLAGS) $(EXTRA_VASMFLAGS) -L $(basename $@).lst -o $@ $<

# remove targets that can be generated by this Makefile
clean:
	$(RM) $(TO_CLEAN)

disasm: $(DISASM)

# hexdump of program binary
dump: $(BINARY)
	hexdump -C $(BINARY)

# upload binary to rosco (if ready and kermit present)
load: $(BINARY)
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)

# Linux (gnome): Upload binary with kermit, connect with "screen" terminal
# (NOTE: kills existing "screen", opens new screen serial in new shell window/tab)
linuxtest: $(BINARY) $(DISASM)
	-$(LSOF) -t $(SERIAL) | (read oldscreen ; [ ! -z "$$oldscreen" ] && kill -3 $$oldscreen ; sleep 1)
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)
	gnome-terminal --geometry=80x25 --title="rosco_m68k $(SERIAL)" -- screen $(SERIAL) $(BAUD)

# Linux (gnome): Connect with "screen" terminal
linuxterm:
	-$(LSOF) -t $(SERIAL) | (read oldscreen ; [ ! -z "$$oldscreen" ] && kill -3 $$oldscreen ; sleep 1)
	gnome-terminal --geometry=80x25 --title="rosco_m68k $(SERIAL)" -- screen $(SERIAL) $(BAUD)

# macOS: Upload binary with kermit, connect with "screen" terminal
# (NOTE: kills existing "screen", opens new screen serial in new shell window/tab)
mactest: $(BINARY) $(DISASM)
	-$(LSOF) -t $(SERIAL) | (read oldscreen ; [ ! -z "$$oldscreen" ] && kill -3 $$oldscreen ; sleep 1)
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)
	echo "#! /bin/sh" > $(TMPDIR)/rosco_screen.sh
	echo "/usr/bin/screen $(SERIAL) $(BAUD)" >> $(TMPDIR)/rosco_screen.sh
	-chmod +x $(TMPDIR)/rosco_screen.sh
	sleep 1
	open -b com.apple.terminal $(TMPDIR)/rosco_screen.sh

macterm:
	-$(LSOF) -t $(SERIAL) | (read oldscreen ; [ ! -z "$$oldscreen" ] && kill -3 $$oldscreen ; sleep 1)
	echo "#! /bin/sh" > $(TMPDIR)/rosco_screen.sh
	echo "/usr/bin/screen $(SERIAL) $(BAUD)" >> $(TMPDIR)/rosco_screen.sh
	-chmod +x $(TMPDIR)/rosco_screen.sh
	sleep 1
	open -b com.apple.terminal $(TMPDIR)/rosco_screen.sh

# Makefile magic (for "phony" targets that are not real files)
.PHONY: all clean disasm dump load linuxtest linuxterm mactest macterm
