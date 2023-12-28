/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 * $Id$
 *
 * Copyright (C) 2014 by Amaury Pouly
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
#ifndef __RB_SCSI_H__
#define __RB_SCSI_H__

#ifdef __cplusplus
extern "C" {
#endif

struct rb_scsi_device_t;
typedef struct rb_scsi_device_t *rb_scsi_device_t;

typedef void (*rb_scsi_printf_t)(void *user, const char *fmt, ...);

/* flags for rb_scsi_open */
#define RB_SCSI_READ_ONLY   (1 << 0)
#define RB_SCSI_DEBUG       (1 << 1)

/* transfer direction */
#define RB_SCSI_NONE        0
#define RB_SCSI_READ        1
#define RB_SCSI_WRITE       2

/* most common status */
#define RB_SCSI_GOOD                0
#define RB_SCSI_CHECK_CONDITION     2
#define RB_SCSI_COMMAND_TERMINATED  0x22

/* return codes */
#define RB_SCSI_OK          0 /* Everything worked */
#define RB_SCSI_STATUS      1 /* Device returned an error in status */
#define RB_SCSI_SENSE       2 /* Device returned sense data */
#define RB_SCSI_OS_ERROR    3 /* Transfer failed, got OS error */
#define RB_SCSI_ERROR       4 /* Transfer failed, got transfer/host error */

/* structure for raw transfers */
struct rb_scsi_raw_cmd_t
{
    int dir; /* direction: none, read or write */
    int cdb_len; /* command buffer length */
    void *cdb; /* command buffer */
    int buf_len; /* data buffer length (will be overwritten with actual count) */
    void *buf; /* buffer */
    int sense_len; /* sense buffer length (will be overwritten with actual count) */
    void *sense; /* sense buffer */
    int tmo; /* timeout (in seconds) */
    int status; /* status returned by device (STATUS) or errno (OS_ERROR) or other error (ERROR) */
};

/* open a device, returns a handle or NULL on error
 * the caller can optionally provide an error printing function
 *
 * Linux:
 *   Path must be the block device, typically /dev/sdX and the program
 *   must have the permission to open it in read/write mode.
 *
 * Windows:
 *   If the path starts with '\', it will be use as-is. This allows to use
 *   paths such as \\.\PhysicalDriveX or \\.\ScsiX
 *   Alternatively, the code will try to map a logical drive (such as 'C:') to
 *   the correspoding physical drive.
 *   In any case, on recent windows, the program needs to be started with
 *   Administrator privileges.
 */
rb_scsi_device_t rb_scsi_open(const char *path, unsigned flags, void *user,
    rb_scsi_printf_t printf);
/* performs a raw transfer, returns !=0 on error */
int rb_scsi_raw_xfer(rb_scsi_device_t dev, struct rb_scsi_raw_cmd_t *raw);
/* decode sense and print information if debug flag is set */
void rb_scsi_decode_sense(rb_scsi_device_t dev, void *sense, int sense_len);
/* close a device */
void rb_scsi_close(rb_scsi_device_t dev);

/* SCSI device reported by rb_scsi_list() */
struct rb_scsi_devent_t
{
    /* device path to the raw SCSI device, typically:
     * - Linux: /dev/sgX
     * - Windows: C:
     * This path can be used directly with scsi_rb_open(), and is guaranteed to
     * be valid. */
    char *scsi_path;
    /* device path to the corresponding block device, if it exists, typically:
     * - Linux: /dev/sdX
     * - Windows: C:
     * If this path is not-NULL, then it can used directly with scsi_rb_open() */
    char *block_path;
    /* various information about the device, can be NULL on error */
    char *vendor;
    char *model;
    char *rev;
};
/* try to list all SCSI devices, returns a list of devices or NULL on error
 * the list is terminated by an entry with scsi_path=NULL */
struct rb_scsi_devent_t *rb_scsi_list(void);
/* free the list returned by rb_scsi_list */
void rb_scsi_free_list(struct rb_scsi_devent_t *list);

#ifdef __cplusplus
}
#endif

#endif /* __RB_SCSI_H__ */
