## @file
#
# The makefile can be invoked with
# HOST_ARCH = x86_64 or x64 for EM64T build
# HOST_ARCH = ia32 or IA32 for IA32 build
# HOST_ARCH = ia64 or IA64 for IA64 build
# HOST_ARCH = Arm or ARM for ARM build
#
# Copyright (c) 2007 - 2018, Intel Corporation. All rights reserved.<BR>
# This program and the accompanying materials
# are licensed and made available under the terms and conditions of the BSD License
# which accompanies this distribution.    The full text of the license may be found at
# http://opensource.org/licenses/bsd-license.php
#
# THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
# WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
##

##
#  Modified for RefindPlus
#  Copyright (c) 2025 Dayo Akanji (sf.net/u/dakanji/profile)
#
#  Modifications distributed under the preceding terms.
##

ifndef HOST_ARCH
  #
  # If HOST_ARCH is not defined, try to figure this out with 'uname -m'
  #
  uname_m = $(shell uname -m)
  ifneq (,$(strip $(filter $(uname_m), x86_64 amd64)))
    HOST_ARCH=X64
  endif
  ifeq ($(patsubst i%86,IA32,$(uname_m)),IA32)
    HOST_ARCH=IA32
  endif
  ifneq (,$(findstring aarch64,$(uname_m)))
    HOST_ARCH=AARCH64
  endif
  ifneq (,$(findstring arm,$(uname_m)))
    HOST_ARCH=ARM
    ifneq (,$(findstring arm64,$(uname_m)))
      HOST_ARCH=AARCH64
    endif
  endif
  ifndef HOST_ARCH
    $(info Could not detect HOST_ARCH from uname results)
    $(error HOST_ARCH is not defined!)
  endif
endif

CYGWIN:=$(findstring CYGWIN, $(shell uname -s))
LINUX:=$(findstring Linux, $(shell uname -s))
DARWIN:=$(findstring Darwin, $(shell uname -s))

BUILD_CC ?= gcc
BUILD_CXX ?= g++
BUILD_AS ?= gcc
BUILD_AR ?= ar
BUILD_LD ?= ld
LINKER ?= $(BUILD_CC)
ifeq ($(HOST_ARCH), IA32)
ARCH_INCLUDE = -I $(MAKEROOT)/Include/Ia32/

else ifeq ($(HOST_ARCH), X64)
ARCH_INCLUDE = -I $(MAKEROOT)/Include/X64/

else ifeq ($(HOST_ARCH), ARM)
ARCH_INCLUDE = -I $(MAKEROOT)/Include/Arm/

else ifeq ($(HOST_ARCH), AARCH64)
ARCH_INCLUDE = -I $(MAKEROOT)/Include/AArch64/

else
$(error Bad HOST_ARCH)
endif

INCLUDE = $(TOOL_INCLUDE) -I $(MAKEROOT) -I $(MAKEROOT)/Include/Common -I \
          $(MAKEROOT)/Include/ -I $(MAKEROOT)/Include/IndustryStandard -I \
		  $(MAKEROOT)/Common/ -I .. -I . $(ARCH_INCLUDE)
BUILD_CPPFLAGS = $(INCLUDE) -O2

###############################################################################
# UDK2018 / RefindPlusUDK modern GCC/Clang compatibility flags
# Force C11 for C, C++14 for C++, and disable misc warnings/errors
###############################################################################
CORE_FLAGS    = -Wno-unknown-warning-option -Wno-deprecated-register \
                -Wno-deprecated-non-prototype -Wno-deprecated-declarations \
				-Wno-pointer-to-int-cast -Wno-unused-result -Wno-error

UDK_CFLAGS   := -std=c11 $(CORE_FLAGS)
UDK_CXXFLAGS := -std=c++14 $(CORE_FLAGS)

BUILD_CFLAGS  = $(UDK_CFLAGS)
BUILD_CFLAGS += -MD -fshort-wchar -fno-strict-aliasing -Wall \
                -Wno-int-to-pointer-cast -nostdlib -c -g

ifeq ($(DARWIN),Darwin)
  # Assume clang or clang compatible flags on Mac OS
  BUILD_CFLAGS += -Wno-self-assign
endif

BUILD_CXXFLAGS  = $(UDK_CXXFLAGS)
###############################################################################

BUILD_LFLAGS =
ifeq ($(HOST_ARCH), IA32)
  #
  # Snow Leopard is a 32-bit and 64-bit environment. uname -m returns i386,
  #  but gcc defaults to x86_64. So make sure tools match uname -m.
  # A 64-bit kernel can be manually defined for Snow Leopard,
  #  so only proceed here if uname -m returns i386.
  #
  ifeq ($(DARWIN),Darwin)
    BUILD_CFLAGS   += -arch i386
    BUILD_CPPFLAGS += -arch i386
    BUILD_LFLAGS   += -arch i386
  endif
endif


.PHONY: all
.PHONY: install
.PHONY: clean

all:

$(MAKEROOT)/libs:
	mkdir $(MAKEROOT)/libs

$(MAKEROOT)/bin:
	mkdir $(MAKEROOT)/bin
