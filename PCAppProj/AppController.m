/* 
 * AppController.m created by phr on 2000-08-27 11:38:58 +0000
 *
 * Project TestApp
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id$
 */

#import "AppController.h"

@implementation AppController

static NSDictionary *infoDict = nil;

+ (void)initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  /*
   * Register your app's defaults here by adding objects to the
   * dictionary, eg
   *
   * [defaults setObject:anObject forKey:keyForThatObject];
   *
   */
  
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)init
{
  if ((self = [super init])) {
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
}

- (void)applicationShouldTerminate:(id)sender
{
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
}

- (void)showPrefPanel:(id)sender
{
}
/*
- (void)showInfoPanel:(id)sender
{
  if (!infoDict) {
    NSString *fp;
    NSBundle *bundle = [NSBundle mainBundle];

    fp = [bundle pathForResource:@"Info-project" ofType:@"plist"];
    infoDict = [[NSDictionary dictionaryWithContentsOfFile:fp] retain];
  }

  [[NSApplication sharedApplication] orderFrontStandardInfoPanelWithOptions:infoDict];
}
*/
@end
