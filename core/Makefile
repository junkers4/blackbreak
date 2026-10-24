# The assembler cores and their tests.
#   make test          both cores against spec/*.json and the unit cases
#   make test-x86_64   the x86-64 core (Windows app) assembled for Linux
#   make test-aarch64  the AArch64 core (Android app) under qemu-aarch64
NDK ?= $(firstword $(wildcard $(HOME)/Android/Sdk/ndk/27*/toolchains/llvm/prebuilt/linux-x86_64/bin) $(dir $(shell command -v ld.lld)))
CLANG ?= clang
LLD ?= $(NDK)/ld.lld
QEMU ?= qemu-aarch64

.PHONY: test test-x86_64 test-aarch64 windows clean
test: test-x86_64 test-aarch64

# The x86-64 core for the Windows app: a COFF object linked into BlackBreak.exe,
# and the same code as a Linux shared library for the C# tests on Linux.
windows: build/blackbreak_core.obj build/libblackbreak_core.so

build/blackbreak_core.obj: x86_64/core.S x86_64/core.inc
	mkdir -p build
	$(CLANG) --target=x86_64-pc-windows-msvc -c x86_64/core.S -o $@

build/libblackbreak_core.so: x86_64/core.S x86_64/core.inc
	mkdir -p build
	$(CLANG) --target=x86_64-linux-gnu -fPIC -c x86_64/core.S -o build/core-x86_64-pic.o
	$(LLD) -shared -soname libblackbreak_core.so -o $@ build/core-x86_64-pic.o

build/driver-x86_64: x86_64/core.S x86_64/driver.S x86_64/core.inc
	mkdir -p build
	$(CLANG) --target=x86_64-linux-gnu -c x86_64/core.S -o build/core-x86_64.o
	$(CLANG) --target=x86_64-linux-gnu -c x86_64/driver.S -o build/driver-x86_64.o
	$(LLD) -static -o $@ build/core-x86_64.o build/driver-x86_64.o

build/driver-aarch64: aarch64/core.S aarch64/controller.S aarch64/driver.S aarch64/core.inc
	mkdir -p build
	$(CLANG) --target=aarch64-linux-gnu -c aarch64/core.S -o build/core-aarch64.o
	$(CLANG) --target=aarch64-linux-gnu -c aarch64/controller.S -o build/controller-aarch64.o
	$(CLANG) --target=aarch64-linux-gnu -c aarch64/driver.S -o build/driver-aarch64.o
	$(LLD) -static -o $@ build/core-aarch64.o build/controller-aarch64.o build/driver-aarch64.o

test-x86_64: build/driver-x86_64
	python3 test/run_core.py build/driver-x86_64

test-aarch64: build/driver-aarch64
	python3 test/run_core.py --controller $(QEMU) build/driver-aarch64

clean:
	rm -rf build
