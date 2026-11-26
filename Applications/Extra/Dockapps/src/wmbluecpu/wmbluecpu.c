/*
 *  wmbluecpu - a dockapp which shows cpu usage
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

#include "options.h"
#include "dockapp.h"
#include "timing.h"

int    argc;
char **argv;
int    exitloop = 0;

int main(int carg, char **varg)
{
 argc = carg;
 argv = varg;
 parse_arguments();
 make_window();
 start_timer();
 while(!exitloop)
 {
  process_events();
 }
 stop_timer();
 free_stuff();
 return 0;
}
