/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 * $Id$
 *
 * Copyright (C) 2011 Amaury Pouly
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
#ifndef __DBPARSER__
#define __DBPARSER__

/**
 * Command file parsing
 */
#include "sb.h"
#include "elf.h"

enum cmd_source_type_t
{
    CMD_SRC_UNK,
    CMD_SRC_ELF,
    CMD_SRC_BIN
};

struct bin_param_t
{
    uint32_t size;
    void *data;
};

struct cmd_source_t
{
    char *identifier;
    bool is_extern;
    // <union>
    int extern_nr;
    char *filename;
    // </union>
    struct cmd_source_t *next;
    /* for later use */
    enum cmd_source_type_t type;
    bool loaded;
    struct elf_params_t elf;
    struct bin_param_t bin;
};

enum cmd_inst_type_t
{
    CMD_LOAD, /* load image */
    CMD_JUMP, /* jump at image */
    CMD_CALL, /* call image */
    CMD_LOAD_AT, /* load binary at */
    CMD_CALL_AT, /* call at address */
    CMD_JUMP_AT, /* jump at address */
    CMD_MODE, /* change boot mode */
};

struct cmd_inst_t
{
    enum cmd_inst_type_t type;
    char *identifier;
    uint32_t argument; // for jump, call, mode
    uint32_t addr; // for 'at'
    struct cmd_inst_t *next;
};

struct cmd_option_t
{
    char *name;
    bool is_string;
    /* <union> */
        uint32_t val;
        char *str;
    /* </union> */
    struct cmd_option_t *next;
};

struct cmd_section_t
{
    uint32_t identifier;
    bool is_data;
    // <union>
        struct cmd_inst_t *inst_list;
        char *source_id;
    // </union>
    struct cmd_section_t *next;
    struct cmd_option_t *opt_list;
};

struct cmd_file_t
{
    struct cmd_option_t *opt_list;
    struct cmd_option_t *constant_list; /* constant are always integers */
    struct cmd_source_t *source_list;
    struct cmd_section_t *section_list;
};

typedef void (*db_color_printf)(void *u, bool err, color_t c, const char *f, ...);

struct cmd_source_t *db_find_source_by_id(struct cmd_file_t *cmd_file, const char *id);
struct cmd_option_t *db_find_option_by_id(struct cmd_option_t *opt, const char *name);
bool db_parse_sb_version(struct sb_version_t *ver, const char *str);
bool db_generate_sb_version(struct sb_version_t *ver, char *str, int size);
void db_generate_default_sb_version(struct sb_version_t *ver);
struct cmd_file_t *db_parse_file(const char *file);
/* NOTE: db_add_{str_opt,int_opt,source,extern_source} add at the beginning of the list */
void db_add_str_opt(struct cmd_option_t **opt, const char *name, const char *str);
void db_add_int_opt(struct cmd_option_t **opt, const char *name, uint32_t value);
void db_add_source(struct cmd_file_t *cmd_file, const char *identifier, const char *filename);
void db_add_inst_id(struct cmd_section_t *cmd_section, enum cmd_inst_type_t type,
    const char *identifier, uint32_t argument);
void db_add_inst_addr(struct cmd_section_t *cmd_section, enum cmd_inst_type_t type,
    uint32_t addr, uint32_t argument);
struct cmd_section_t *db_add_section(struct cmd_file_t *cmd_file, uint32_t identifier, bool data);
void db_add_extern_source(struct cmd_file_t *cmd_file, const char *identifier, int extern_nr);
bool db_generate_file(struct cmd_file_t *file, const char *filename, void *user, db_color_printf printf);
void db_free_option_list(struct cmd_option_t *opt_list);
void db_free(struct cmd_file_t *file);

/* standard implementation: user is unused*/
void db_std_printf(void *user, bool error, color_t c, const char *fmt, ...);

#endif /* __DBPARSER__ */
