h61494
s 00012/00007/00098
d D 1.3 02/10/27 01:09:42 meem 3 2
c refactor for pluggable looks
e
s 00002/00000/00103
d D 1.2 02/08/01 02:41:33 meem 2 1
c fix ident string
e
s 00103/00000/00000
d D 1.1 02/08/01 02:40:05 meem 1 0
c add support for pluggable looks
e
u
U
f e 0
t
T
I 1
/*
 * Copyright (c) 2002 Peter Memishian (meem) <meem@gnu.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * wmnetload - A dockapp to monitor network interface usage.
 *	       Inspired by Seiichi SATO's nifty CPU usage monitor.
 *
 * Pixmaps and sizing information for the "classic" wmnetload look.
 */

I 2
#pragma ident "%Z%%M%	%I%	%E% meem"

E 2
#ifndef	WN_CLASSIC_PIXMAPS_H
#define	WN_CLASSIC_PIXMAPS_H

I 3
#include "../common/pixmaps.h"
E 3
#include "./parts.xpm"
#include "./backlight_down.xpm"
#include "./backlight_err.xpm"
#include "./backlight_on.xpm"
#include "./backlight_off.xpm"

/*
 * Sizing information for each graphical digit.
 */
enum {
	WN_DIG_WIDTH	= 12,	/* digit width */
	WN_DIG_HEIGHT	= 22,	/* digit height */
	WN_DIG_SPACE	= 16,	/* inter-digit spacing */
	WN_DIG_SXOFF	= 0,	/* x offset of first digit in source */
	WN_DIG_SYOFF	= 0,	/* y offset of first digit in source */
	WN_DIG_DXOFF	= 10,	/* x offset of first digit in destination */
D 3
	WN_DIG_DYOFF	= 5,	/* y offset of first digit in destination */
E 3
I 3
	WN_DIG_DYOFF	= 5	/* y offset of first digit in destination */
E 3
};

/*
 * Sizing information for the decimal point.
 */
enum {
	WN_DEC_WIDTH	= 2,	/* decimal point width */
	WN_DEC_HEIGHT	= 2,	/* decimal point height */
	WN_DEC_SPACE	= 16,	/* destination spacing */
	WN_DEC_SXOFF	= 120,	/* x offset in source */
	WN_DEC_SYOFF	= 0,	/* y offset in source */
	WN_DEC_DXOFF	= 8,	/* x offset in destination */
	WN_DEC_DYOFF	= 25	/* y offset in destination */
};

/*
 * Sizing information for each speed designator.
 */
enum {
	WN_SPD_WIDTH	= 4,	/* speed designator width */
	WN_SPD_HEIGHT	= 5,	/* speed designator height */
	WN_SPD_SPACE	= 6,	/* destination spacing */
	WN_SPD_DXOFF	= 4,	/* x offset in destination */
	WN_SPD_DYOFF	= 6,	/* y offset in destination */
	WN_SPD_SXOFF	= 124,	/* x offset in source */
	WN_SPD_SYOFF	= 0	/* y offset in source */
};

/*
 * Sizing information for the columns of the network activity graph.
 */
enum {
	WN_COL_WIDTH	= 2,	/* graph column width */
	WN_COL_HEIGHT	= 23,	/* graph column height */
	WN_COL_SPACE	= 3,	/* destination spacing */
	WN_COL_DXOFF	= 5,	/* x offset in of first column in destination */
	WN_COL_DYOFF	= 31,	/* y offset in of first column in destination */
	WN_COL_SXOFF	= 120,	/* x offset in source */
	WN_COL_SYOFF	= 0	/* y offset in source */
};

/*
 * Sizing information for the network activity graph.
 */
enum {
	WN_GR_COLS	= 17,	/* number of columns in graph */
D 3
	WN_GR_ROWS	= 16	/* number of rows in graph */
E 3
I 3
	WN_GR_ROWS	= 16,	/* number of rows in graph */
	WN_GR_WIDTH	= 50,	/* graph component width */
	WN_GR_HEIGHT	= 23,	/* graph component height */
	WN_GR_XOFF	= 5,	/* x offset of graph */
	WN_GR_YOFF	= 31	/* y offset of graph */
E 3
};

/*
D 3
 * Sizing information for each component of the dockapp.
E 3
I 3
 * Sizing information for the bps meter.
E 3
 */
enum {
D 3
	WN_DA_WIDTH	= 58,	/* dockapp width */
	WN_DA_HEIGHT	= 58,	/* dockapp height */
	WN_BPS_WIDTH	= 58,	/* bps component width */
	WN_BPS_HEIGHT	= 27	/* bps component height */
E 3
I 3
	WN_BPS_WIDTH	= 58,	/* bps meter width */
	WN_BPS_HEIGHT	= 27,	/* bps meter height */
	WN_BPS_XOFF	= 0,	/* x offset of bps meter */
	WN_BPS_YOFF	= 0	/* y offset of bps meter */
E 3
};

#endif	/* WN_CLASSIC_PIXMAPS_H */
E 1
