/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 * $Id$
 *
 * Copyright (C) 2010 Amaury Pouly
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ****************************************************************************/
#ifndef __MISC_H__
#define __MISC_H__

#include <stdbool.h>
#include <stdio.h>

#define _STR(a) #a
#define STR(a) _STR(a)

#define bug(...) do { fprintf(stderr,"["__FILE__":"STR(__LINE__)"]ERROR: "__VA_ARGS__); exit(1); } while(0)
#define bugp(...) do { fprintf(stderr, __VA_ARGS__); perror(" "); exit(1); } while(0)

#define ROUND_UP(val, round) ((((val) + (round) - 1) / (round)) * (round))

typedef char color_t[];

extern color_t OFF, GREY, RED, GREEN, YELLOW, BLUE;
void *xmalloc(size_t s);
void color(color_t c);
void enable_color(bool enable);

#ifndef MIN
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#endif

#define cprintf(col, ...) do {color(col); printf(__VA_ARGS__); }while(0)

#define cprintf_field(str1, ...) do{ cprintf(GREEN, str1); cprintf(YELLOW, __VA_ARGS__); }while(0)
#define cprintf_field2(str1, ...) do{ cprintf(BLUE, str1); cprintf(RED, __VA_ARGS__); }while(0)

#endif /* __MISC_H__ */
