h20930
s 00002/00002/00050
d D 1.2 02/10/27 01:08:48 meem 2 1
c fix cstyle glitches
e
s 00052/00000/00000
d D 1.1 02/08/04 01:29:45 meem 1 0
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
 * Pixmaps and sizing information that's common across looks.
 */

#pragma ident "%Z%%M%	%I%	%E% meem"

#ifndef	WN_COMMON_PIXMAPS_H
#define	WN_COMMON_PIXMAPS_H

#include "./font.xpm"

/*
 * Sizing information for each glyph in our font.
 */
enum {
	WN_FONT_WIDTH	= 4,	/* font width */
	WN_FONT_HEIGHT	= 5,	/* font height */
	WN_FONT_YOFF	= 0,	/* y offset of first glyph */
	WN_FONT_LETXOFF	= 0,	/* x offset of first letter */
	WN_FONT_DIGXOFF	= 104,	/* x offset of first digit */
	WN_FONT_SPCXOFF	= 144,	/* x offset of space */
	WN_FONT_ERRXOFF = 148	/* x offset of error */
};

/*
D 2
 * Sizing information for the dockapp as a whole
E 2
I 2
 * Sizing information for the dockapp as a whole.
E 2
 */
enum {
	WN_DA_WIDTH	= 58,	/* dockapp width */
D 2
	WN_DA_HEIGHT	= 58,	/* dockapp height */
E 2
I 2
	WN_DA_HEIGHT	= 58	/* dockapp height */
E 2
};

#endif	/* WN_COMMON_PIXMAPS_H */
E 1
