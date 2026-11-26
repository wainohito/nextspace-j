/*
 *  draw.c
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

#include <string.h>
#include <X11/Xlib.h>

#include "cpu_linux.h"
#include "dockapp.h"
#include "options.h"

void draw_window()
{
 int x, y;

 for(x = 0; x < 17; x++)
 {
  for(y = 0; y < 16; y++)
  {
   if(history[16 - x] > y)
    XCopyArea(display, on, buffer, gc, 0, 0, 2, 2, 7 + x * 3, 57 - y * 2);
   else
    XCopyArea(display, off, buffer, gc, 0, 0, 2, 2, 7 + x * 3, 57 - y * 2);
  }
 }
 if(cpu_used == 100) XCopyArea(display, numbers, buffer, gc,
                               5, 0, 5, 6, 33, 20);
 else  XCopyArea(display, numbers, buffer, gc, 50, 0, 5, 6, 33, 20);
 if(cpu_used > 9) XCopyArea(display, numbers, buffer, gc,
                            5 * ((cpu_used % 100) / 10),
			    0, 5, 6, 39, 20);
 else XCopyArea(display, numbers, buffer, gc, 50, 0, 5, 6, 39, 20);
 XCopyArea(display, numbers, buffer, gc,
           5 * (cpu_used % 10),
	   0, 5, 6, 45, 20);
 update_window();
 XSync(display, False);
}
