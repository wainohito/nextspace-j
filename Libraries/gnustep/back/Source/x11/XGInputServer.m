/* XIMInputServer - XIM Keyboard input handling

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Christian Gillot <cgillot@neo-rousseaux.org>
   Date: Nov 2001
   Author: Adam Fedor <fedor@gnu.org>
   Date: Jan 2002

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#include "config.h"

#include <AppKit/NSApplication.h>
#include <AppKit/NSTextInputClient.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUserDefaults.h>
#include <GNUstepBase/Unicode.h>

#include <X11/Xlocale.h>
#include "x11/XGInputServer.h"

#define NoneStyle (XIMPreeditNone | XIMStatusNone)
#define RootWindowStyle (XIMPreeditNothing | XIMStatusNothing)
#define OffTheSpotStyle (XIMPreeditArea | XIMStatusArea)
#define OverTheSpotStyle (XIMPreeditPosition | XIMStatusArea)
#define OnTheSpotStyle (XIMPreeditCallbacks | XIMStatusCallbacks)

@interface XGInputServer (XIMPrivate)
- (BOOL)ximInit:(Display *)dpy;
- (void)ximClose;
- (XIC)currentIC;
- (int)ximStyleInit;
- (XIC)ximCreateIC:(Window)w;
- (unsigned long)ximXicGetMask:(XIC)xic;
@end

#define BUF_LEN 255


/* ----------------------------------------------------------------------
   On-the-spot (XIMPreeditCallbacks) support: the composition text is shown
   inside the focused text view as marked text (NSTextInput protocol).
*/
static NSMutableString *preeditBuffer = nil;
static NSUInteger preeditCaret = 0;

static id preeditTarget(void)
{
  id target = [[NSApp keyWindow] firstResponder];

  if ([target respondsToSelector:@selector(setMarkedText:selectedRange:)])
    return target;
  return nil;
}

static void preeditDeliver(void)
{
  id target = preeditTarget();

  if (target == nil)
    return;
  if (preeditCaret > [preeditBuffer length])
    preeditCaret = [preeditBuffer length];
  [target setMarkedText:[NSString stringWithString:preeditBuffer]
          selectedRange:NSMakeRange(preeditCaret, 0)];
}

static NSString *stringFromXIMText(XIMText *text)
{
  if (text == NULL || text->length == 0)
    return @"";
  if (text->encoding_is_wchar) {
    if (text->string.wide_char == NULL)
      return nil;
    {
      NSMutableString *str = [NSMutableString string];
      unsigned short i;
      for (i = 0; i < text->length; i++) {
        wchar_t wc = text->string.wide_char[i];
        if (wc > 0xFFFF) {
          unichar pair[2] = {0xD800 + ((wc - 0x10000) >> 10), 0xDC00 + ((wc - 0x10000) & 0x3FF)};
          [str appendString:[NSString stringWithCharacters:pair length:2]];
        } else {
          unichar c = (unichar)wc;
          [str appendString:[NSString stringWithCharacters:&c length:1]];
        }
      }
      return str;
    }
  }
  if (text->string.multi_byte == NULL)
    return nil;  // feedback-only change
  {
    NSString *str = [NSString stringWithUTF8String:text->string.multi_byte];
    if (str == nil)
      str = [NSString stringWithCString:text->string.multi_byte];
    return str;
  }
}

static int preeditStartCallback(XIC ic, XPointer client_data, XPointer call_data)
{
  if (preeditBuffer == nil)
    preeditBuffer = [NSMutableString new];
  [preeditBuffer setString:@""];
  preeditCaret = 0;
  return -1;  // no length limit
}

static void preeditDoneCallback(XIC ic, XPointer client_data, XPointer call_data)
{
  if ([preeditBuffer length] > 0) {
    [preeditBuffer setString:@""];
    preeditCaret = 0;
    preeditDeliver();
  }
}

static void preeditDrawCallback(XIC ic, XPointer client_data,
                                XIMPreeditDrawCallbackStruct *call_data)
{
  NSUInteger first, length, total;
  NSString *inserted;

  if (preeditBuffer == nil)
    preeditBuffer = [NSMutableString new];

  total = [preeditBuffer length];
  first = MIN((NSUInteger)MAX(call_data->chg_first, 0), total);
  length = MIN((NSUInteger)MAX(call_data->chg_length, 0), total - first);
  inserted = stringFromXIMText(call_data->text);

  if (inserted == nil) {
    // Only the feedback (highlight) changed: keep the text.
    inserted = [preeditBuffer substringWithRange:NSMakeRange(first, length)];
  }
  [preeditBuffer replaceCharactersInRange:NSMakeRange(first, length) withString:inserted];
  preeditCaret = (NSUInteger)MAX(call_data->caret, 0);

  if (getenv("GS_XIM_DEBUG"))
    NSLog(@"XIM: preedit draw first=%d len=%d caret=%d -> '%@'", call_data->chg_first,
          call_data->chg_length, call_data->caret, preeditBuffer);
  preeditDeliver();
}

static void preeditCaretCallback(XIC ic, XPointer client_data,
                                 XIMPreeditCaretCallbackStruct *call_data)
{
  if (call_data->direction == XIMAbsolutePosition) {
    preeditCaret = (NSUInteger)MAX(call_data->position, 0);
    preeditDeliver();
  }
  call_data->position = (int)preeditCaret;
}

static void statusNoopCallback(XIC ic, XPointer client_data, XPointer call_data)
{
}

@implementation XGInputServer

- (id)initWithDelegate:(id)aDelegate name:(NSString *)name
{
  Display *dpy = [XGServer xDisplay];
  return [self initWithDelegate:aDelegate display:dpy name:name];
}

- (id)initWithDelegate:(id)aDelegate display:(Display *)dpy name:(NSString *)name
{
  char *locale;
  delegate = aDelegate;
  ASSIGN(server_name, name);

  locale = setlocale(LC_CTYPE, "");

  if (XSupportsLocale() != True) {
    NSLog(@"Xlib does not support locale setting %s", locale);
    /* FIXME: Should we reset the locale or just hope that X
       can deal with it? */
  }

#ifdef USE_XIM
  if ([self ximInit:dpy] == NO) {
    NSLog(@"Unable to initialize XIM, using standard keyboard events");
  }
#endif
  return self;
}

- (void)dealloc
{
  DESTROY(server_name);
  [self ximClose];
  [super dealloc];
}

/* ----------------------------------------------------------------------
   XInputFiltering protocol methods
*/
- (BOOL)filterEvent:(XEvent *)event
{
  if (XFilterEvent(event, None)) {
    NSDebugLLog(@"NSKeyEvent", @"Event filtered by XIM\n");
    return YES;
  }
  return NO;
}

- (NSString *)lookupStringForEvent:(XKeyEvent *)event
                            window:(gswindow_device_t *)windev
                            keysym:(KeySym *)keysymptr
{
  int count = 0;
  NSString *keys = nil;
  KeySym keysym = 0;
  char buf[BUF_LEN];

  /* Process characters */

  /* N.B. The Xutf8LookupString manpage says this macro will be defined
     in the X headers if that function is available. */
#if defined(X_HAVE_UTF8_STRING)
  if (windev->ic && event->type == KeyPress) {
    Status status = 0;
    count = Xutf8LookupString(windev->ic, event, buf, BUF_LEN, &keysym, &status);

    if (status == XBufferOverflow)
      NSDebugLLog(@"NSKeyEvent", @"XmbLookupString buffer overflow\n");
    if (count) {
      keys = [[[NSString alloc] initWithBytes:buf length:count
                                     encoding:NSUTF8StringEncoding] autorelease];
    }
    if (status == XLookupKeySym || status == XLookupBoth) {
      if (keysymptr)
        *keysymptr = keysym;
    }
  } else
#endif
  {
    /* Always returns a Latin-1 string according to the manpage */
    count = XLookupString(event, buf, BUF_LEN, &keysym, NULL);
    if (count) {
      keys = [[[NSString alloc] initWithBytes:buf length:count
                                     encoding:NSISOLatin1StringEncoding] autorelease];
    }

    if (keysymptr)
      *keysymptr = keysym;
  }

  return keys;
}

/* ----------------------------------------------------------------------
   NSInputServiceProvider protocol methods
*/
- (void)activeConversationChanged:(id)sender toNewConversation:(long)newConversation
{
  NSWindow *window;
  gswindow_device_t *windev;

  [super activeConversationChanged:sender toNewConversation:newConversation];

  if ([sender respondsToSelector:@selector(window)] == NO) {
    [NSException raise:NSInvalidArgumentException
                format:@"NSTextInput sender does not respond to window"];
  }
  window = [sender window];
  windev = [XGServer _windowWithTag:[window windowNumber]];
  if (windev == NULL) {
    [NSException raise:NSInvalidArgumentException format:@"NSTextInput sender has invalid window"];
  }

  [self ximFocusICWindow:windev];
}

- (void)activeConversationWillChange:(id)sender fromOldConversation:(long)oldConversation
{
  [super activeConversationWillChange:sender fromOldConversation:oldConversation];
}

/* ----------------------------------------------------------------------
   XIM private methods
*/
- (BOOL)ximInit:(Display *)dpy
{
  XClassHint class_hints;

  if (!XSetLocaleModifiers(""))
    NSDebugLLog(@"XIM", @"can not set locale modifiers\n");

  /* FIXME: Get these */
  class_hints.res_name = class_hints.res_class = NULL;
  xim = XOpenIM(dpy, NULL, class_hints.res_name, class_hints.res_class);
  if (xim == NULL) {
    NSDebugLLog(@"XIM", @"Can't open XIM.\n");
    return NO;
  }

  if (![self ximStyleInit]) {
    [self ximClose];
    return NO;
  }

  NSDebugLLog(@"XIM", @"Initialized XIM\n");
  return YES;
}

/* Score an input style offered by the input method server for the style
   requested by the user (GSXIMInputMethodStyle).  The preedit part matters
   most; any status part we can handle is accepted (we draw no status). */
static int styleScore(XIMStyle style, XIMStyle requested)
{
  XIMStyle pre = style & (XIMPreeditArea | XIMPreeditCallbacks | XIMPreeditPosition |
                          XIMPreeditNothing | XIMPreeditNone);
  XIMStyle st = style & (XIMStatusArea | XIMStatusCallbacks | XIMStatusNothing | XIMStatusNone);
  int score;

  if (pre == (requested & (XIMPreeditArea | XIMPreeditCallbacks | XIMPreeditPosition |
                           XIMPreeditNothing | XIMPreeditNone)))
    score = 100;
  else if (pre == XIMPreeditPosition)
    score = 60;
  else if (pre == XIMPreeditCallbacks)
    score = 50;
  else if (pre == XIMPreeditArea)
    score = 40;
  else if (pre == XIMPreeditNothing)
    score = 20;
  else if (pre == XIMPreeditNone)
    score = 10;
  else
    return 0;

  if (st == XIMStatusNothing)
    score += 5;
  else if (st == XIMStatusNone)
    score += 4;
  else if (st == XIMStatusArea)
    score += 3;
  else if (st == XIMStatusCallbacks)
    score += 2;
  else
    return 0;
  return score;
}

- (int)ximStyleInit
{
  NSUserDefaults *uds;
  NSString *request;
  XIMStyle xim_requested_style;
  XIMStyles *styles;
  char *failed_arg;
  int i;

  uds = [NSUserDefaults standardUserDefaults];
  if ((request = [uds stringForKey:@"GSXIMInputMethodStyle"]) == nil) {
    xim_requested_style = RootWindowStyle;
  } else if ([request isEqual:@"RootWindow"]) {
    xim_requested_style = RootWindowStyle;
  } else if ([request isEqual:@"OffTheSpot"]) {
    xim_requested_style = OffTheSpotStyle;
  } else if ([request isEqual:@"OverTheSpot"]) {
    xim_requested_style = OverTheSpotStyle;
  } else if ([request isEqual:@"OnTheSpot"]) {
    xim_requested_style = OnTheSpotStyle;
  } else {
    NSLog(@"XIM: Unknown style '%@'.\n"
          @"Fallback to RootWindow style.",
          request);
    xim_requested_style = RootWindowStyle;
  }

  failed_arg = XGetIMValues(xim, XNQueryInputStyle, &styles, NULL);
  if (failed_arg != NULL) {
    NSDebugLLog(@"XIM", @"Can't getting the following IM value :%s", failed_arg);
    return 0;
  }

  {
    int best = 0;
    for (i = 0; i < styles->count_styles; i++) {
      int score = styleScore(styles->supported_styles[i], xim_requested_style);
      if (score > best) {
        best = score;
        xim_style = styles->supported_styles[i];
      }
    }
  }
  NSDebugLLog(@"XIM", @"XIM: using input style 0x%lx", xim_style);
  XFree(styles);

  if (xim_style == 0) {
    NSLog(@"XIM: no supported styles found");
    return 0;
  }

  return 1;
}

/* The IC that preedit/status values apply to: the focused one if known,
   otherwise the most recently created one (old behaviour). */
- (XIC)currentIC
{
  if (focused_xic != NULL)
    return focused_xic;
  if (num_xics > 0)
    return xics[num_xics - 1];
  return NULL;
}

- (void)ximClose
{
  int i;
  for (i = 0; i < num_xics; i++) {
    XDestroyIC(xics[i]);
  }
  free(xics);
  num_xics = 0;
  xics = NULL;
  focused_xic = NULL;

  NSDebugLLog(@"XIM", @"Closed XIM\n");

  if (xim)
    XCloseIM(xim);
  xim = NULL;
}

- (void)ximFocusICWindow:(gswindow_device_t *)windev
{
  if (xim == NULL)
    return;

    /* Make sure we have an ic for this window */
#ifdef USE_XIM
  if (windev->ic == NULL) {
    windev->ic = [self ximCreateIC:windev->ident];
    if (windev->ic == NULL) {
      [self ximClose];
    }
  }
#endif

  /* Now set focus to this window */
  if (windev->ic) {
    NSDebugLLog(@"XIM", @"XSetICFocus to window %lu", windev->ident);
    XSetICFocus(windev->ic);
    focused_xic = windev->ic;
    if (getenv("GS_XIM_DEBUG"))
      NSLog(@"XIM: focus IC %p window %lu", windev->ic, windev->ident);
  }
}

- (XIC)ximCreateIC:(Window)w
{
  XIC xic = NULL;

  if (xim_style & XIMPreeditCallbacks) {
    static XIMCallback startCB = {NULL, (XIMProc)preeditStartCallback};
    static XIMCallback doneCB = {NULL, (XIMProc)preeditDoneCallback};
    static XIMCallback drawCB = {NULL, (XIMProc)preeditDrawCallback};
    static XIMCallback caretCB = {NULL, (XIMProc)preeditCaretCallback};
    static XIMCallback statusCB = {NULL, (XIMProc)statusNoopCallback};
    XPoint spot = {0, 0};
    XVaNestedList preedit_args;
    XVaNestedList status_args = NULL;

    preedit_args = XVaCreateNestedList(0, XNPreeditStartCallback, &startCB,
                                       XNPreeditDoneCallback, &doneCB,
                                       XNPreeditDrawCallback, &drawCB,
                                       XNPreeditCaretCallback, &caretCB,
                                       XNSpotLocation, &spot, NULL);
    if (xim_style & XIMStatusCallbacks) {
      status_args = XVaCreateNestedList(0, XNStatusStartCallback, &statusCB,
                                        XNStatusDoneCallback, &statusCB,
                                        XNStatusDrawCallback, &statusCB, NULL);
      xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, XNFocusWindow, w,
                      XNPreeditAttributes, preedit_args, XNStatusAttributes, status_args, NULL);
    } else {
      xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, XNFocusWindow, w,
                      XNPreeditAttributes, preedit_args, NULL);
    }
    if (xic == NULL) {
      // Some servers reject XNSpotLocation for callbacks: retry without it.
      XFree(preedit_args);
      preedit_args = XVaCreateNestedList(0, XNPreeditStartCallback, &startCB,
                                         XNPreeditDoneCallback, &doneCB,
                                         XNPreeditDrawCallback, &drawCB,
                                         XNPreeditCaretCallback, &caretCB, NULL);
      xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, XNFocusWindow, w,
                      XNPreeditAttributes, preedit_args,
                      status_args ? XNStatusAttributes : NULL, status_args, NULL);
    }
    XFree(preedit_args);
    if (status_args)
      XFree(status_args);
  } else if (!(xim_style & (XIMPreeditArea | XIMPreeditPosition))) {
    xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, NULL);
  } else {
    Display *dpy = [XGServer xDisplay];
    XFontSet font_set;
    char **missing_charset;
    int num_missing_charset;
    int dummy = 0;
    XVaNestedList preedit_args = NULL;
    XVaNestedList status_args = NULL;
    XRectangle status_area;
    XRectangle preedit_area;
    XPoint preedit_spot;
    NSString *ns_font_size;
    int font_size;
    char base_font_name[64];

    //
    // Create a FontSet
    //

    // N.B. Because some input methods fail to provide a default font set,
    // we have to do it by ourselves.
    ns_font_size = [self fontSize:&font_size];
    // Trailing ",*" lets Xlib pick any font for charsets (e.g. JIS X 0208)
    // not covered by the first pattern; fcitx5/ibus draw preedit themselves.
    snprintf(base_font_name, sizeof(base_font_name),
             "-*-*-medium-r-normal--%s-*-*-*-*-*-*-*,*", [ns_font_size cString]);
    font_set = XCreateFontSet(dpy, base_font_name, &missing_charset, &num_missing_charset, NULL);
    if (!font_set) {
      goto finish;
    }
    if (missing_charset) {
      int i;
      NSLog(@"XIM: missing charset: ");
      for (i = 0; i < num_missing_charset; ++i)
        NSLog(@"%s", missing_charset[i]);
      XFreeStringList(missing_charset);
    }

    //
    // Create XIC.
    //
    // At least, XNFontSet and XNPreeditSpotLocation must be specified
    // at initialization time.
    //
    status_area.width = font_size * 2;
    status_area.height = font_size + 2;
    status_area.x = 0;
    status_area.y = 0;

    status_args = XVaCreateNestedList(dummy, XNArea, &status_area, XNFontSet, font_set, NULL);

    preedit_area.width = 120;
    preedit_area.height = status_area.height;
    preedit_area.x = 0;
    preedit_area.y = 0;

    preedit_spot.x = 0;
    preedit_spot.y = 0;

    // For OverTheSpot only the spot location matters.  Sending XNArea makes
    // some servers (fcitx5) anchor the preedit to the area origin (0,0),
    // i.e. the window's top-left corner, ignoring the spot.
    if (xim_style & XIMPreeditPosition)
      preedit_args = XVaCreateNestedList(dummy, XNSpotLocation, &preedit_spot,
                                         XNFontSet, font_set, NULL);
    else
      preedit_args = XVaCreateNestedList(dummy, XNArea, &preedit_area, XNSpotLocation,
                                         &preedit_spot, XNFontSet, font_set, NULL);

    if (xim_style & XIMStatusArea)
      xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, XNPreeditAttributes,
                      preedit_args, XNStatusAttributes, status_args, NULL);
    else
      xic = XCreateIC(xim, XNInputStyle, xim_style, XNClientWindow, w, XNPreeditAttributes,
                      preedit_args, NULL);

    if (preedit_args) {
      XFree(preedit_args);
      preedit_args = NULL;
    }
    if (status_args) {
      XFree(status_args);
      status_args = NULL;
    }
    if (font_set)
      XFreeFontSet(dpy, font_set);
  }

finish:
  if (xic == NULL)
    NSDebugLLog(@"XIM", @"Can't create the input context.\n");

  xics = realloc(xics, sizeof(XIC) * (num_xics + 1));
  xics[num_xics++] = xic;
  return xic;
}

- (unsigned long)ximXicGetMask:(XIC)xic
{
  unsigned long xic_xmask = 0;
  if (XGetICValues(xic, XNFilterEvents, &xic_xmask, NULL) != NULL)
    NSDebugLLog(@"XIM", @"Can't get the event mask for that input context");

  return xic_xmask;
}

- (void)ximCloseIC:(XIC)xic
{
  int i;
  for (i = 0; i < num_xics; i++) {
    if (xics[i] == xic)
      break;
  }
  if (i == num_xics) {
    NSLog(@"internal error in ximCloseIC: can't find XIC in list");
    abort();
  }
  for (i++; i < num_xics; i++)
    xics[i - 1] = xics[i];
  num_xics--;

  if (focused_xic == xic)
    focused_xic = NULL;
  XDestroyIC(xic);
}

@end

@implementation XGInputServer (InputMethod)
- (NSString *)inputMethodStyle
{
  if (num_xics > 0) {
    if (xim_style & XIMPreeditCallbacks)
      return @"OnTheSpot";
    else if (xim_style & XIMPreeditPosition)
      return @"OverTheSpot";
    else if (xim_style & XIMPreeditArea)
      return @"OffTheSpot";
    else if (xim_style & XIMPreeditNothing)
      return @"RootWindow";
  }
  return nil;
}

- (NSString *)fontSize:(int *)size
{
  NSString *str;

  str = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSFontSize"];
  if (!str)
    str = @"12";
  *size = (int)strtol([str cString], NULL, 10);
  return str;
}

- (BOOL)clientWindowRect:(NSRect *)rect
{
  Window win;
  Window dummy;
  Display *dpy;
  int abs_x, abs_y;
  int x, y;
  unsigned int w, h;
  unsigned int bw, d;

  if ([self currentIC] == NULL || !rect)
    return NO;

  *rect = NSMakeRect(0, 0, 0, 0);

  if (XGetICValues([self currentIC], XNClientWindow, &win, NULL))
    return NO;
  dpy = [XGServer xDisplay];
  if (XTranslateCoordinates(dpy, win, DefaultRootWindow(dpy), 0, 0, &abs_x, &abs_y, &dummy) == 0)
    return NO;
  XGetGeometry(dpy, win, &dummy, &x, &y, &w, &h, &bw, &d);

  // X Window Coordinates to GNUstep Coordinates
  x = abs_x;
  y = XDisplayHeight(dpy, 0) - (abs_y + h);

  *rect = NSMakeRect((float)x, (float)y, (float)w, (float)h);

  return YES;
}

- (BOOL)statusArea:(NSRect *)rect
{
  if ([self currentIC] != NULL && (xim_style & XIMStatusArea)) {
    XRectangle area;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    if (!(arglist = XVaCreateNestedList(dummy, XNArea, &area, NULL))) {
      return NO;
    }
    XGetICValues([self currentIC], XNStatusAttributes, arglist, NULL);

    rect->origin.x = area.x;
    rect->origin.y = area.y;
    rect->size.width = area.width;
    rect->size.height = area.height;

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  return NO;
}

- (BOOL)preeditArea:(NSRect *)rect
{
  if ([self currentIC] != NULL && ((xim_style & XIMPreeditArea) || (xim_style & XIMPreeditPosition))) {
    XRectangle area;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    if (!(arglist = XVaCreateNestedList(dummy, XNArea, &area, NULL))) {
      return NO;
    }
    XGetICValues([self currentIC], XNPreeditAttributes, arglist, NULL);

    rect->origin.x = area.x;
    rect->origin.y = area.y;
    rect->size.width = area.width;
    rect->size.height = area.height;

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  return NO;
}

- (BOOL)preeditSpot:(NSPoint *)p
{
  if ([self currentIC] != NULL && (xim_style & (XIMPreeditPosition | XIMPreeditCallbacks))) {
    XPoint spot;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    if (!(arglist = XVaCreateNestedList(dummy, XNSpotLocation, &spot, NULL))) {
      return NO;
    }
    XGetICValues([self currentIC], XNPreeditAttributes, arglist, NULL);

    p->x = spot.x;
    p->y = spot.y;

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  return NO;
}

- (BOOL)setStatusArea:(NSRect *)rect
{
  if ([self currentIC] != NULL && (xim_style & XIMStatusArea)) {
    XRectangle area;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    area.x = rect->origin.x;
    area.y = rect->origin.y;
    area.width = rect->size.width;
    area.height = rect->size.height;

    if (!(arglist = XVaCreateNestedList(dummy, XNArea, &area, NULL))) {
      return NO;
    }
    XSetICValues([self currentIC], XNStatusAttributes, arglist, NULL);

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  return NO;
}

- (BOOL)setPreeditArea:(NSRect *)rect
{
  if ([self currentIC] != NULL && ((xim_style & XIMPreeditArea) || (xim_style & XIMPreeditPosition))) {
    XRectangle area;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    area.x = rect->origin.x;
    area.y = rect->origin.y;
    area.width = rect->size.width;
    area.height = rect->size.height;

    if (!(arglist = XVaCreateNestedList(dummy, XNArea, &area, NULL))) {
      return NO;
    }
    XSetICValues([self currentIC], XNPreeditAttributes, arglist, NULL);

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  return NO;
}

- (BOOL)setPreeditSpot:(NSPoint *)p
{
  if ([self currentIC] != NULL && (xim_style & (XIMPreeditPosition | XIMPreeditCallbacks))) {
    XPoint spot;
    int dummy = 0;
    XVaNestedList arglist = NULL;

    spot.x = p->x;
    spot.y = p->y;

    if (!(arglist = XVaCreateNestedList(dummy, XNSpotLocation, &spot, NULL))) {
      return NO;
    }
    {
      char *r = XSetICValues([self currentIC], XNPreeditAttributes, arglist, NULL);
      if (getenv("GS_XIM_DEBUG"))
        NSLog(@"XIM: setPreeditSpot %d,%d IC %p -> %s", spot.x, spot.y, [self currentIC], r ? r : "ok");
    }

    if (arglist) {
      XFree(arglist);
      arglist = NULL;
    }

    return YES;
  }
  if (getenv("GS_XIM_DEBUG"))
    NSLog(@"XIM: setPreeditSpot skipped (IC %p style %lx)", [self currentIC], xim_style);
  return NO;
}

@end  // XIMInputServer (InputMethod)
