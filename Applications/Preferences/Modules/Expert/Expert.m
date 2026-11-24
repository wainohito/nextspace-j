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

#import <AppKit/AppKit.h>
#import <SystemKit/OSEFileManager.h>

#import "Expert.h"

@implementation Expert

- (id)init
{
  self = [super init];
  
  defaults = [OSEDefaults globalUserDefaults];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Expert" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Expert -dealloc");
  [image release];
  if (view) {
    [view release];
  }
  [super dealloc];
}

// The Owner/Group/Others column titles in Expert.gorm are laid out with a
// 41pt pitch while the permission grid below has 43pt columns, so titles
// drift left.  Center them on the grid columns (x = 81, 124, 167).
static void collectHeaderLabels(NSView *v, NSMutableArray *out)
{
  for (NSView *s in [v subviews]) {
    if ([s isKindOfClass:[NSTextField class]] && NSMinY([s frame]) == 94 &&
        [(NSTextField *)s alignment] == NSCenterTextAlignment) {
      [out addObject:s];
    }
    collectHeaderLabels(s, out);
  }
}

- (void)_alignPermissionTitles
{
  NSMutableArray *labels = [NSMutableArray array];
  const CGFloat centers[3] = {81, 124, 167};

  collectHeaderLabels(view, labels);
  if ([labels count] != 3) {
    return;
  }
  [labels sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
    return (NSMinX([a frame]) < NSMinX([b frame])) ? NSOrderedAscending : NSOrderedDescending;
  }];
  for (int i = 0; i < 3; i++) {
    NSView *l = labels[i];
    NSRect f = [l frame];
    f.origin.x = centers[i] - NSWidth(f) / 2;
    [l setFrame:f];
  }
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [self _alignPermissionTitles];

  [sortByBtn setRefusesFirstResponder:YES];
  [showHiddenFilesBtn setRefusesFirstResponder:YES];
  [privateWindowServerBtn setRefusesFirstResponder:YES];
  [privateSoundServerBtn setRefusesFirstResponder:YES];

  [sortByBtn
    selectItemWithTag:[[OSEFileManager defaultManager] sortFilesBy]];
  [showHiddenFilesBtn
    setState:[[OSEFileManager defaultManager] isShowHiddenFiles]];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Expert" owner:self])
        {
          NSLog (@"Expert.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Expert Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//

- (void)setSortBy:(id)sender
{
  [[OSEFileManager defaultManager] setSortFilesBy:[[sender selectedItem] tag]];
}

- (void)setShowHiddenFiles:(id)sender
{
  [[OSEFileManager defaultManager] setShowHiddenFiles:[sender state]];
}

@end

