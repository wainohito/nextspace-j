#import <AppKit/AppKit.h>

#import "NextSpace.h"
#import "NXTScrollerKnobSlotCell.h"

@implementation NextSpace

@synthesize knobSlotPattern;

#pragma mark - Init & dealloc

- (void)dealloc
{
  [knobSlotPattern release];
  [super dealloc];
}

- (NSImage *)knobSlotPattern
{
  if (knobSlotPattern == nil) {
    // NSLog(@"%s: Setting knob slot pattern image...", __func__);
    NSString *path = [[self bundle] pathForResource:@"SharedGrayAlpha"
                                             ofType:@"tiff"
                                        inDirectory:@"Resources"];
    // NSLog(@"SharedGrayAlpha path %@", path);
    NSImage *sharedGrayBits = [[NSImage alloc] initWithContentsOfFile:path];
    NSImage *pattern = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
    NSData *tiffRep;

    [pattern lockFocusOnRepresentation:nil];
    // The bits are white dots on a transparent background.  Make the pattern
    // opaque (NeXT light gray) so redrawing the knob slot erases the old knob
    // position instead of leaving trails.
    [[NSColor colorWithCalibratedWhite:(170.0 / 255.0) alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 12, 12));
    [sharedGrayBits drawAtPoint:NSZeroPoint
                       fromRect:NSMakeRect(49, 88, 12, 12)
                      operation:NSCompositeSourceOver
                       fraction:1.0];
    [pattern unlockFocus];

    tiffRep = [pattern TIFFRepresentation];
    [pattern release];
    [sharedGrayBits release];
    knobSlotPattern = [[NSImage alloc] initWithData:tiffRep];

    // NSLog(@"%s: Setting knob slot pattern image - DONE!", __func__);
  }

  return knobSlotPattern;
}

- (void)fillKnobSlotPatternInRect:(NSRect)rect
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  NSImage *pattern = self.knobSlotPattern;
  NSSize size = [pattern size];
  CGFloat x, y;

  if (NSIsEmptyRect(rect)) {
    return;
  }

  if ([[ctxt className] isEqualToString:@"CairoContext"]) {
    [ctxt GSSetPatterColor:pattern];
    [ctxt DPSrectfill:rect.origin.x:rect.origin.y:rect.size.width:rect.size.height];
    return;
  }

  // Other backends (e.g. ART) have no pattern colors: fill with the opaque
  // base color, then tile the pattern clipped to rect.  The tiles are aligned
  // to the view's coordinate origin so adjacent redraws match up.
  [NSGraphicsContext saveGraphicsState];
  NSRectClip(rect);
  [[NSColor colorWithCalibratedWhite:(170.0 / 255.0) alpha:1.0] set];
  NSRectFill(rect);
  for (y = floor(NSMinY(rect) / size.height) * size.height; y < NSMaxY(rect); y += size.height) {
    for (x = floor(NSMinX(rect) / size.width) * size.width; x < NSMaxX(rect); x += size.width) {
      [pattern drawAtPoint:NSMakePoint(x, y)
                  fromRect:NSZeroRect
                 operation:NSCompositeSourceOver
                  fraction:1.0];
    }
  }
  [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - NSScroller

- (NSCell *)cellForScrollerKnobSlot:(BOOL)horizontal
{
  NXTScrollerKnobSlotCell *cell;

  cell = [NXTScrollerKnobSlotCell new];
  [cell setBordered:NO];
  [cell setTitle:nil];

  return cell;
}

#pragma mark - NSSlider

- (void)drawSliderBorderAndBackground:(NSBorderType)aType
                                frame:(NSRect)cellFrame
                               inCell:(NSCell *)cell
                         isHorizontal:(BOOL)horizontal
{
  if (NSIsEmptyRect(cellFrame)) {
    return;
  }

  if (aType == NSBezelBorder) {
    [self drawGrayBezel:cellFrame withClip:NSZeroRect];
  } else {
    [[GSTheme theme] drawBorderType:aType frame:cellFrame view:[cell controlView]];
  }
}

- (void)drawBarInside:(NSRect)rect inCell:(NSCell *)cell flipped:(BOOL)flipped
{
  if (NSIsEmptyRect(rect)) {
    return;
  }

  [self fillKnobSlotPatternInRect:rect];
}

// - (void)drawKnobInCell:(NSCell *)cell
// {
//   NSLog(@"%s", __func__);

//   NSView *controlView = [cell controlView];
//   NSSliderCell *sliderCell = (NSSliderCell *)cell;
//   NSRect knobRect = [sliderCell knobRectFlipped:[controlView isFlipped]];

//   [sliderCell drawKnob:knobRect];
// }

@end

