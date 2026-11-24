/* gormcmp: compare connections of two .gorm files (English vs localized).
   usage: gormcmp <a.gorm> <b.gorm>   -> "OK n connections" or a diff.
   Unknown custom classes are replaced by runtime stubs so any gorm loads. */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSGormLoading.h>
#import <objc/runtime.h>

static Class guessSuper(NSString *n)
{
  if ([n hasSuffix:@"Browser"]) return [NSBrowser class];
  if ([n hasSuffix:@"Field"]) return [NSTextField class];
  if ([n hasSuffix:@"SplitView"]) return [NSSplitView class];
  if ([n hasSuffix:@"Matrix"]) return [NSMatrix class];
  if ([n hasSuffix:@"Button"]) return [NSButton class];
  return [NSView class];
}

static id loadWithStubs(NSString *file)
{
  for (int i = 0; i < 40; i++) {
    NS_DURING
      id c = [NSUnarchiver unarchiveObjectWithFile:file];
      NS_VALRETURN(c);
    NS_HANDLER
      NSString *r = [localException reason];
      NSRange a = [r rangeOfString:@"find class '"];
      if (a.location == NSNotFound) {
        fprintf(stderr, "%s\n", [r UTF8String]);
        NS_VALRETURN(nil);
      }
      NSString *rest = [r substringFromIndex:NSMaxRange(a)];
      NSString *name = [rest substringToIndex:[rest rangeOfString:@"'"].location];
      Class k = objc_allocateClassPair(guessSuper(name), [name UTF8String], 0);
      objc_registerClassPair(k);
    NS_ENDHANDLER
  }
  return nil;
}

static NSString *describeObject(id o)
{
  if ([o isKindOfClass:[NSString class]])
    return [NSString stringWithFormat:@"'%@'", o];
  return NSStringFromClass([o class]);
}

static NSArray *describe(NSString *path)
{
  id c = loadWithStubs([path stringByAppendingPathComponent:@"objects.gorm"]);
  NSMutableArray *a;

  if (c == nil)
    return nil;
  a = [NSMutableArray array];
  for (id con in [c connections]) {
    [a addObject:[NSString stringWithFormat:@"%@ %@ -> %@ : %@", NSStringFromClass([con class]),
                                            describeObject([con source]),
                                            describeObject([con destination]), [con label]]];
  }
  [a sortUsingSelector:@selector(compare:)];
  return a;
}

int main(int argc, const char **argv)
{
  @autoreleasepool {
    NSArray *e, *j;

    if (argc != 3) {
      fprintf(stderr, "usage: gormcmp a.gorm b.gorm\n");
      return 2;
    }
    [NSApplication sharedApplication];
    e = describe([NSString stringWithUTF8String:argv[1]]);
    j = describe([NSString stringWithUTF8String:argv[2]]);
    if (!e || !j) {
      printf("LOADFAIL a=%d b=%d\n", e != nil, j != nil);
      return 2;
    }
    if ([e isEqual:j]) {
      printf("OK %lu connections\n", (unsigned long)[e count]);
      return 0;
    }
    printf("DIFF a=%lu b=%lu\n", (unsigned long)[e count], (unsigned long)[j count]);
    for (id x in e) if (![j containsObject:x]) printf("  -%s\n", [x UTF8String]);
    for (id x in j) if (![e containsObject:x]) printf("  +%s\n", [x UTF8String]);
    return 1;
  }
}
