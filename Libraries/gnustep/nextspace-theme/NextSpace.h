#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

@interface NextSpace : GSTheme
{
}
@property (readonly) NSImage *knobSlotPattern;
// Fill rect with the knob slot pattern on any graphics backend.
- (void)fillKnobSlotPatternInRect:(NSRect)rect;
@end
