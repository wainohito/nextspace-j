/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSColor.h>

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTBundle.h>

#import "PrefsController.h"

@implementation PrefsController

- (id)init
{
  self = [super init];
  prefsViews = [[NSMutableDictionary alloc] init];
  return self;
}

//
// Initialize stuff that can't be set in the nib/gorm file.
// 
- (void)awakeFromNib
{
  // Let the system keep track of where it belongs
  [window setFrameAutosaveName:@"PreferencesMainWindow"];
  [window setFrameUsingName:@"PreferencesMainWindow"];

  if (iconList)	{ // stop processing if we already have an icon list
    return;
  }

  iconList = [[NSMatrix alloc] initWithFrame:NSMakeRect(0,0,64*30,70)
                                        mode:NSRadioModeMatrix
                                   cellClass:[NSButtonCell class]
                                numberOfRows:1
                             numberOfColumns:0];
  [iconList setCellSize:NSMakeSize(70, 70)];
  [iconList setIntercellSpacing:NSZeroSize];
  [iconList setAllowsEmptySelection:NO];

  [iconScrollView setDocumentView:iconList];
  [iconScrollView setHasHorizontalScroller:YES];
  [iconScrollView setHasVerticalScroller:NO];
  [iconScrollView setBorderType:NSBezelBorder];
  [[iconScrollView horizontalScroller] setArrowsPosition:NSScrollerArrowsNone];

  [self loadBundles];

  [iconList selectCellAtRow:0 column:0];
  [iconList sendAction];
  [window makeKeyAndOrderFront:self];
}

- (void)dealloc
{
  NSLog(@"PrefsController: dealloc");

  [prefsViews release];
  [window close];
  [window release];

  [super dealloc];
}

- (id)currentModule
{
  return currentModule;
}

- (NSWindow *)window
{
  return window;
}

//
// Localized labels can be wider than the English ones the layout was made
// for.  To keep font sizes consistent with neighbours: first tighten the
// letter spacing (kerning, up to 1.5pt per gap), then widen centered labels
// symmetrically if that doesn't overlap a sibling's text; shrink the font
// only as a last resort.
//
static const CGFloat kMaxKern = 1.5;

// Rect occupied by the text of a label (frame narrowed by alignment).
static NSRect textRectOfLabel(NSTextField *tf)
{
  NSRect f = [tf frame];
  CGFloat w = MIN([[tf cell] cellSize].width, NSWidth(f));

  switch ([tf alignment]) {
    case NSCenterTextAlignment: f.origin.x += (NSWidth(f) - w) / 2; break;
    case NSRightTextAlignment:  f.origin.x += NSWidth(f) - w; break;
    default: break;
  }
  f.size.width = w;
  return f;
}

static BOOL widenCenteredLabel(NSTextField *tf, CGFloat extra)
{
  NSRect old = [tf frame];
  NSRect wide = NSInsetRect(old, -ceil(extra / 2) - 1, 0);

  if ([tf alignment] != NSCenterTextAlignment || NSMinX(wide) < 0 ||
      NSMaxX(wide) > NSWidth([[tf superview] bounds])) {
    return NO;
  }
  for (NSView *sib in [[tf superview] subviews]) {
    if (sib == tf || ![sib isKindOfClass:[NSTextField class]])
      continue;
    if (NSIntersectsRect(wide, textRectOfLabel((NSTextField *)sib)))
      return NO;
  }
  [tf setFrame:wide];
  [[tf superview] setNeedsDisplayInRect:wide];
  return YES;
}

static NSAttributedString *kernedString(NSString *text, NSFont *font, NSColor *color, CGFloat kern)
{
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  if (font) [attrs setObject:font forKey:NSFontAttributeName];
  if (color) [attrs setObject:color forKey:NSForegroundColorAttributeName];
  [attrs setObject:[NSNumber numberWithFloat:kern] forKey:NSKernAttributeName];
  return [[[NSAttributedString alloc] initWithString:text attributes:attrs] autorelease];
}

static void fitControl(NSControl *c, BOOL isButton)
{
  NSCell *cell = [c cell];
  NSString *text = isButton ? [(NSButton *)c title] : [c stringValue];
  NSFont *font = [c font];
  NSColor *color = isButton ? nil : [(NSTextField *)c textColor];
  CGFloat available = NSWidth([c bounds]);
  CGFloat excess = [cell cellSize].width - available;
  NSUInteger gaps = ([text length] > 1) ? [text length] - 1 : 1;

  if (excess <= 0 || [text length] == 0) {
    return;
  }
  {
    CGFloat kern = MIN(excess / gaps + 0.1, kMaxKern);
    NSAttributedString *as = kernedString(text, font, color, -kern);
    CGFloat rest;

    if (isButton)
      [(NSButton *)c setAttributedTitle:as];
    else
      [c setAttributedStringValue:as];
    rest = [cell cellSize].width - available;
    if (rest <= 0) {
      return;
    }
    if (!isButton && widenCenteredLabel((NSTextField *)c, rest)) {
      return;
    }
    // Undo kerning before shrinking the font.
    if (isButton)
      [(NSButton *)c setTitle:text];
    else
      [c setStringValue:text];
  }
  while (font && [cell cellSize].width > available && [font pointSize] > 8) {
    font = [NSFont fontWithName:[font fontName] size:[font pointSize] - 1];
    [c setFont:font];
  }
}

static void fitTextInView(NSView *view)
{
  for (NSView *v in [view subviews]) {
    if ([v isKindOfClass:[NSTextField class]] && ![(NSTextField *)v isEditable]) {
      fitControl((NSControl *)v, NO);
    } else if ([v isKindOfClass:[NSButton class]] && [[(NSButton *)v title] length] > 0 &&
               [(NSButton *)v imagePosition] != NSImageOnly) {
      fitControl((NSControl *)v, YES);
    }
    fitTextInView(v);
  }
}

//
// Button matrix
//
- (void)buttonClicked:(id)sender
{
  NSString        *buttonCaption = [[sender selectedCell] title];
  id<PrefsModule> module;
  NSView          *view;
  NSRect          buttonRect;

  module = [prefsViews objectForKey:buttonCaption];
  view = [module view];

  buttonRect = [sender cellFrameAtRow:0 column:[sender selectedColumn]];
  [iconList scrollRectToVisible:buttonRect];
  
  [prefsViewBox setContentView:view];
  fitTextInView(view);
  [view setNeedsDisplay:YES];
  [window setTitle:NSLocalizedString(buttonCaption, @"")];
       
  currentModule = module;
}

//
// Modules
//
- (BOOL)registerPrefsModule:(id)aPrefsModule
{
  NSButtonCell	*button;
  NSString	*caption;

  caption = [aPrefsModule buttonCaption];
  if (!caption) {
    return NO;
  }
  
  if ([prefsViews objectForKey:caption] != aPrefsModule) {
    [prefsViews setObject:aPrefsModule forKey:caption];
  }

  button = [[NSButtonCell alloc] init];
  [button setTitle:caption];
  [button setFont:[NSFont systemFontOfSize:9]];
  [button setImage:[aPrefsModule buttonImage]];
  [button setImagePosition:NSImageOnly];
  [button setButtonType:NSOnOffButton];
  [button setRefusesFirstResponder:YES];

  [button setTarget:self];
  [button setAction:@selector(buttonClicked:)];

  [iconList addColumnWithCells:[NSArray arrayWithObject:button]];
  [iconList sizeToCells];
  [button release];

  return YES;
}

- (void)loadBundles
{
  NSDictionary *bRegistry;
  NSArray      *modules;

  bRegistry = [[NXTBundle shared] registerBundlesOfType:@"preferences"
                                                atPath:nil];
  modules = [[NXTBundle shared] loadRegisteredBundles:bRegistry
                                                type:@"Preferences"
                                            protocol:@protocol(PrefsModule)];
  for (id b in modules) {
    [self registerPrefsModule:b];
  }
}

@end
