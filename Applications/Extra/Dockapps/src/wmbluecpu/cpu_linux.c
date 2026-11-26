/*
 *  cpu_linux.c - get cpu usage
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

long cpu_used;
long oldused;
long oldtotal;

int history[17];

void cpu_getusage()
{
 FILE *file;
 long cpu, nice, system, idle, used, total;

 file = fopen("/proc/stat", "r");
 if(!file)
 {
  perror("/proc/stat");
  exit(1);
 }
 fscanf(file, "%*s %ld %ld %ld %ld", &cpu, &nice, &system, &idle);
 fclose(file);
 used =  cpu+nice+system;
 total = cpu+nice+system+idle;
 if((total-oldtotal) != 0) cpu_used = (100*(double)(used-oldused))/(double)(total-oldtotal);
 else cpu_used = 0;
 oldused = used;
 oldtotal = total;
 memmove(history+1, history, 16*sizeof(int));
 history[0] = (double)cpu_used*16/100;
}
