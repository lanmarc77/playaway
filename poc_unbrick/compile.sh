#!/bin/bash

arm-none-eabi-as -mcpu=arm926ej-s -march=armv5te  startup.s -o startup.o
arm-none-eabi-gcc -c -mcpu=arm926ej-s -c test.c -o test.o
arm-none-eabi-ld -s -T test.ld test.o startup.o -o test.elf --no-dynamic-linker
