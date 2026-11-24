/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
// Copyright (C) 2022-2023 Andres Morales
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

#import "Date.h"

@implementation Date

- (id)init
{
  NSString *imagePath;
  NSBundle *bundle;

  self = [super init];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"Date" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  defaults = [OSEDefaults globalUserDefaults];

  return self;
}

- (void)dealloc
{
  NSLog(@"Date -dealloc");
  [image release];

  if (view) {
    [view release];
  }

  [super dealloc];
}

- (void)awakeFromNib
{
  NSDictionary *cvdisplayRects;
  NSCalendarDate *nowDate = [NSCalendarDate now];

  [view retain];
  [window release];

  // Clock view
  cvdisplayRects = @{
    @"DayOfWeek" : NSStringFromRect(NSMakeRect(14, 33, 33, 6)),
    @"Day" : NSStringFromRect(NSMakeRect(14, 15, 33, 17)),
    @"Month" : NSStringFromRect(NSMakeRect(14, 9, 31, 6)),
    @"Time" : NSStringFromRect(NSMakeRect(5, 46, 53, 11))
  };
  [clockView setTileImage:[NSImage imageNamed:@"ClockViewTile"]];
  [clockView setDisplayRects:cvdisplayRects];
  [clockView setYearVisible:NO];
  [clockView setCalendarDate:nowDate];

  [hour24Button setIntValue:[clockView is24HourFormat] ? 1 : 0];

  [timeField
      setStringValue:[NSString stringWithFormat:@"%lu:%lu:%lu", nowDate.hourOfDay,
                                                nowDate.minuteOfHour, nowDate.secondOfMinute]];
  [monthField setStringValue:[nowDate descriptionWithCalendarFormat:@"%B"]];
  [yearField setStringValue:[nowDate descriptionWithCalendarFormat:@"%Y"]];

  [calendarView setDate:nowDate];

  [self _fillTimeZonePopUp];
}

//
// Time zone
//
// GNUstep pop-up menus don't scroll, so offer one well-known zone per UTC
// offset (plus the current system zone) instead of the full tz database.
static NSString *timeZoneNames[] = {
  @"Pacific/Pago_Pago", @"Pacific/Honolulu", @"America/Anchorage", @"America/Los_Angeles",
  @"America/Denver", @"America/Chicago", @"America/Mexico_City", @"America/New_York",
  @"America/Halifax", @"America/St_Johns", @"America/Sao_Paulo",
  @"America/Argentina/Buenos_Aires", @"Atlantic/South_Georgia", @"Atlantic/Azores",
  @"UTC", @"Europe/London", @"Europe/Paris", @"Europe/Berlin", @"Africa/Cairo",
  @"Europe/Helsinki", @"Europe/Istanbul", @"Europe/Moscow", @"Asia/Tehran", @"Asia/Dubai",
  @"Asia/Kabul", @"Asia/Karachi", @"Asia/Kolkata", @"Asia/Kathmandu", @"Asia/Dhaka",
  @"Asia/Yangon", @"Asia/Bangkok", @"Asia/Shanghai", @"Asia/Singapore", @"Australia/Perth",
  @"Asia/Seoul", @"Asia/Tokyo", @"Australia/Adelaide", @"Australia/Sydney",
  @"Pacific/Noumea", @"Pacific/Auckland", @"Pacific/Tongatapu", @"Pacific/Kiritimati", nil};

- (NSString *)_currentTimeZoneName
{
  NSString *link = [[NSFileManager defaultManager]
      pathContentOfSymbolicLinkAtPath:@"/etc/localtime"];
  NSRange r = [link rangeOfString:@"zoneinfo/"];

  if (r.location != NSNotFound) {
    return [link substringFromIndex:NSMaxRange(r)];
  }
  return [[NSTimeZone systemTimeZone] name];
}

- (NSString *)_titleForTimeZoneName:(NSString *)name
{
  NSTimeZone *tz = [NSTimeZone timeZoneWithName:name];
  NSInteger secs = [tz secondsFromGMT];
  NSInteger mins = labs(secs) / 60;

  return [NSString stringWithFormat:@"UTC%c%02ld:%02ld  %@", (secs < 0) ? '-' : '+',
                                    (long)(mins / 60), (long)(mins % 60), name];
}

- (void)_fillTimeZonePopUp
{
  NSPopUpButton *popup = timeZoneRegionSelectorPopUpButton;
  NSMutableArray *names = [NSMutableArray array];
  NSString *current = [self _currentTimeZoneName];

  if (popup == nil) {
    return;
  }
  for (int i = 0; timeZoneNames[i] != nil; i++) {
    if ([NSTimeZone timeZoneWithName:timeZoneNames[i]] != nil) {
      [names addObject:timeZoneNames[i]];
    }
  }
  if (current && ![names containsObject:current] && [NSTimeZone timeZoneWithName:current]) {
    [names addObject:current];
  }
  [names sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
    NSInteger oa = [[NSTimeZone timeZoneWithName:a] secondsFromGMT];
    NSInteger ob = [[NSTimeZone timeZoneWithName:b] secondsFromGMT];
    if (oa != ob) {
      return (oa < ob) ? NSOrderedAscending : NSOrderedDescending;
    }
    return [a compare:b];
  }];

  [popup removeAllItems];
  for (NSString *name in names) {
    [popup addItemWithTitle:[self _titleForTimeZoneName:name]];
    [[popup lastItem] setRepresentedObject:name];
  }
  if (current) {
    NSInteger idx = [popup indexOfItemWithRepresentedObject:current];
    if (idx >= 0) {
      [popup selectItemAtIndex:idx];
    }
  }
  [popup setTarget:self];
  [popup setAction:@selector(selectRegionAction:)];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Date" owner:self]) {
      NSLog(@"Date.preferences: Could not load NIB, aborting.");
      return nil;
    }
  }
  return view;
}

- (NSString *)buttonCaption
{
  return @"Date & Time Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

- (void)change24Hour:(id)sender
{
  BOOL flag = [sender integerValue] ? YES : NO;

  [defaults setBool:flag forKey:NXTClockView24HourFormat];
}

- (void)changeCalendarDate:(id)sender
{
  NSCalendarDate *now = [calendarView date];
  NSCalendarDate *then;

  switch ([sender tag]) {
    case 0:
      then = [now dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0];
      break;
    case 1:
      then = [now dateByAddingYears:-1 months:0 days:0 hours:0 minutes:0 seconds:0];
      break;
    case 2:
      then = [now dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
      break;
    case 3:
      then = [now dateByAddingYears:1 months:0 days:0 hours:0 minutes:0 seconds:0];
      break;
  }
  
  [monthField setStringValue:[then descriptionWithCalendarFormat:@"%B"]];
  [yearField setStringValue:[then descriptionWithCalendarFormat:@"%Y"]];
  [calendarView setDate:then];
}

- (void)selectRegionAction:(id)sender
{
  NSString *name = [[timeZoneRegionSelectorPopUpButton selectedItem] representedObject];
  NSString *current = [self _currentTimeZoneName];
  NSTask *task;
  int status = -1;

  if (name == nil || [name isEqualToString:current]) {
    return;
  }

  // Try timedated directly (works if polkit allows it), then a passwordless
  // sudo rule (see Packaging/Sources/extra/nextspace-timezone.sudoers).
  NSArray *attempts = @[
    @[ @"/usr/bin/timedatectl", @[ @"--no-ask-password", @"set-timezone", name ] ],
    @[ @"/usr/bin/sudo", @[ @"-n", @"/usr/bin/timedatectl", @"set-timezone", name ] ]
  ];
  for (NSArray *cmd in attempts) {
    task = [NSTask new];
    [task setLaunchPath:cmd[0]];
    [task setArguments:cmd[1]];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    NS_DURING
      [task launch];
      [task waitUntilExit];
      status = [task terminationStatus];
    NS_HANDLER
      status = -1;
    NS_ENDHANDLER
    [task release];
    if (status == 0)
      break;
  }

  if (status != 0) {
    NSRunAlertPanel(NSLocalizedString(@"Time Zone", @""),
                    NSLocalizedString(@"Could not change the time zone to %@.", @""),
                    NSLocalizedString(@"OK", @""), nil, nil, name);
    [self _fillTimeZonePopUp];
    return;
  }

  [NSTimeZone resetSystemTimeZone];
  [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:name]];
  [clockView setCalendarDate:[NSCalendarDate now]];
}

@end
