
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

#import "NextSpace.h"
#import "NXTScrollerKnobSlotCell.h"

// static NSImage *knobSlotPattern = nil;

@implementation NXTScrollerKnobSlotCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NextSpace *theme = (NextSpace *)[GSTheme theme];

  if (NSIsEmptyRect(cellFrame)) {
    return;
  }
  [theme fillKnobSlotPatternInRect:cellFrame];
}

@end
