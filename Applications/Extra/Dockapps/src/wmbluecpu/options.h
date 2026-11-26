/*
 *  options.h
 *
 *  Copyright (C) 2003 Draghicioiu Mihai <misuceldestept@go.ro>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Street #330, Boston, MA 02111-1307, USA.
 */

#ifndef __OPTIONS_H__
#define __OPTIONS_H__

#include <stdio.h>

#define OPT_VERSION "0.4" /* Version number */

/* Default display to connect to */
#ifndef OPT_DISPLAY
#define OPT_DISPLAY NULL
#endif /* OPT_DISPLAY */

/* Class hint name */
#ifndef OPT_CLASS_NAME
#define OPT_CLASS_NAME "wmbluecpu"
#endif /* OPT_CLASS_NAME */

/* Class hint class name */
#ifndef OPT_CLASS_CLASS
#define OPT_CLASS_CLASS "WMBlueCPU"
#endif /* OPT_CLASS_CLASS */

/* Window title */
#ifndef OPT_WINDOW_NAME
#define OPT_WINDOW_NAME "WMBlueCPU"
#endif /* OPT_WINDOW_NAME */

/* Number of miliseconds between updates */
#ifndef OPT_TIMER_MILISECONDS
#define OPT_TIMER_MILISECONDS 1000
#endif /* OPT_TIMER_MILISECONDS */

/* Run in a window */
#ifndef OPT_WINDOW
#define OPT_WINDOW 0
#endif /* OPT_WINDOW */

/* Use the XShape extension */
#ifndef OPT_SHAPE
#define OPT_SHAPE 1
#endif /* OPT_SHAPE */

extern char *opt_display;
extern int   opt_timer_miliseconds;
extern int   opt_window;
extern int   opt_shape;

void parse_arguments();

#endif /* __OPTIONS_H__ */
