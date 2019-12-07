# Check to make sure that the required variables are set
ifndef DEVICE
    $(error Please set the required DEVICE variable in your makefile.)
endif

ifndef FLASH
    $(error Please set the required FLASH variable in your makefile.)
endif

# Standard values for (linked) STM32-base folders
STM32_BASE_PATH   ?= ./STM32-base
STM32_CUBE_PATH   ?= ./STM32-base-STM32Cube

# STM32-base sub-folders
BASE_LINKER   = $(STM32_BASE_PATH)/linker
BASE_MAKE     = $(STM32_BASE_PATH)/make
BASE_STARTUP  = $(STM32_BASE_PATH)/startup

# Standard values for project folders
BIN_FOLDER ?= ./bin
OBJ_FOLDER ?= ./obj
SRC_FOLDER ?= ./src
INC_FOLDER ?= ./inc

# Determine the series folder name
include $(BASE_MAKE)/series-folder-name.mk

# Include the series-specific makefile
include $(BASE_MAKE)/$(SERIES_FOLDER)/common.mk
MAPPED_DEVICE ?= $(DEVICE)

# The toolchain path, defaults to using the globally installed toolchain
ifdef TOOLCHAIN_PATH
    TOOLCHAIN_SEPARATOR = /
endif

TOOLCHAIN_PATH      ?= ../../tools/
TOOLCHAIN_SEPARATOR ?=

CC              = arm-none-eabi-gcc
CXX             = arm-none-eabi-g++
LD              = arm-none-eabi-ld -v
AR              = arm-none-eabi-ar
AS              = arm-none-eabi-gcc
OBJCOPY         = arm-none-eabi-objcopy
OBJDUMP         = arm-none-eabi-objdump
SIZE            = arm-none-eabi-size
FLASH_TOOL      = $(TOOLCHAIN_PATH)$(TOOLCHAIN_SEPARATOR)st-flash

# Default for flags
GCC_FLAGS ?=

# Flags - Overall Options
GCC_FLAGS += -specs=nosys.specs

# Flags - C Language Options
GCC_FLAGS += -ffreestanding
# GCC_FLAGS += -std=c11

# Flags - C++ Language Options
GCC_FLAGS += -fno-threadsafe-statics
GCC_FLAGS += -fno-rtti
GCC_FLAGS += -fno-exceptions
GCC_FLAGS += -fno-unwind-tables

# Flags - Warning Options
GCC_FLAGS += -Wall
GCC_FLAGS += -Wextra

# Flags - Debugging Options
GCC_FLAGS += -g

# Flags - Optimization Options
GCC_FLAGS += -ffunction-sections
GCC_FLAGS += -fdata-sections

# Flags - Preprocessor options
GCC_FLAGS += -D $(MAPPED_DEVICE)

# Flags - Assembler Options

# Flags - Linker Options
# GCC_FLAGS += -nostdlib
GCC_FLAGS += -Wl,-L$(BASE_LINKER),-T$(BASE_LINKER)/$(SERIES_FOLDER)/$(DEVICE).ld

# Flags - Directory Options
GCC_FLAGS += -I./inc
GCC_FLAGS += -I$(BASE_STARTUP)

# Flags - Machine-dependant options
GCC_FLAGS += -mcpu=$(SERIES_CPU)
GCC_FLAGS += -march=$(SERIES_ARCH)
GCC_FLAGS += -mlittle-endian
GCC_FLAGS += -mthumb
GCC_FLAGS += -masm-syntax-unified

# Output files
ELF_FILE_NAME ?= stm32_executable.elf
BIN_FILE_NAME ?= stm32_bin_image.bin
OBJ_FILE_NAME ?= startup_$(MAPPED_DEVICE).o

ELF_FILE_PATH = $(BIN_FOLDER)/$(ELF_FILE_NAME)
BIN_FILE_PATH = $(BIN_FOLDER)/$(BIN_FILE_NAME)
OBJ_FILE_PATH = $(OBJ_FOLDER)/$(OBJ_FILE_NAME)

# Input files
SRC ?=
SRC += $(SRC_FOLDER)/*.c

# Startup file
DEVICE_STARTUP = $(BASE_STARTUP)/$(SERIES_FOLDER)/$(MAPPED_DEVICE).s

# Include the CMSIS files, using the HAL implies using the CMSIS
ifneq (,$(or USE_ST_CMSIS, USE_ST_HAL))
    GCC_FLAGS += -D CALL_ARM_SYSTEM_INIT
    GCC_FLAGS += -I$(STM32_CUBE_PATH)/CMSIS/ARM/inc
    GCC_FLAGS += -I$(STM32_CUBE_PATH)/CMSIS/$(SERIES_FOLDER)/inc

    SRC += $(STM32_CUBE_PATH)/CMSIS/$(SERIES_FOLDER)/src/*.c
endif

# Include the HAL files
ifdef USE_ST_HAL
    GCC_FLAGS += -D USE_HAL_DRIVER
    GCC_FLAGS += -I$(STM32_CUBE_PATH)/HAL/$(SERIES_FOLDER)/inc

    # A simply expanded variable is used here to perform the find command only once.
    HAL_SRC := $(shell find $(STM32_CUBE_PATH)/HAL/$(SERIES_FOLDER)/src/*.c ! -name '*_template.c')
    SRC += $(HAL_SRC)
endif

# Make all
all:$(BIN_FILE_PATH)

$(BIN_FILE_PATH): $(ELF_FILE_PATH)
	$(OBJCOPY) -O binary $^ $@

$(ELF_FILE_PATH): $(SRC) $(OBJ_FILE_PATH) | $(BIN_FOLDER)
	$(CXX) $(GCC_FLAGS) $^ -o $@

$(OBJ_FILE_PATH): $(DEVICE_STARTUP) | $(OBJ_FOLDER)
	$(CXX) $(GCC_FLAGS) $^ -c -o $@

$(BIN_FOLDER):
	mkdir $(BIN_FOLDER)

$(OBJ_FOLDER):
	mkdir $(OBJ_FOLDER)

# Make clean
clean:
	rm -f $(ELF_FILE_PATH)
	rm -f $(BIN_FILE_PATH)
	rm -f $(OBJ_FILE_PATH)

# Make flash
flash:
	$(FLASH_TOOL) write $(BIN_FOLDER)/$(BIN_FILE_NAME) $(FLASH)

.PHONY: all clean flash
