/*
 *  timing.c - timing part
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
#include <sys/time.h>
#include <signal.h>

#include "draw.h"
#include "options.h"
#include "cpu_linux.h"

void handle_timer(int sig)
{
 if(sig == SIGALRM)
 {
  cpu_getusage();
  draw_window();
 }
}

void start_timer()
{
 struct itimerval itv;

 signal(SIGALRM, handle_timer);
 itv.it_value.tv_sec = 2;
 itv.it_value.tv_usec = 0;
 itv.it_interval.tv_sec = 0;
 itv.it_interval.tv_usec = opt_timer_miliseconds * 1000;
 setitimer(ITIMER_REAL, &itv, NULL);
}

void stop_timer()
{
 struct itimerval itv;

 signal(SIGALRM, SIG_IGN);
 itv.it_value.tv_sec = 0;
 itv.it_value.tv_usec = 0;
 itv.it_interval.tv_sec = 0;
 itv.it_interval.tv_usec = 0;
 setitimer(ITIMER_REAL, &itv, NULL);
}
