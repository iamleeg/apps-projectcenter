/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2001 Free Software Foundation

   Author: Philippe C.D. Robert <phr@3dkit.org>

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Id$
*/

#import "PCAppController.h"
#import "PCMenuController.h"

#import <ProjectCenter/ProjectCenter.h>

@implementation PCAppController

//============================================================================
//==== Intialization & deallocation
//============================================================================

+ (void)initialize
{
    NSMutableDictionary	*defaults = [NSMutableDictionary dictionary];
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *prefix = [env objectForKey:@"GNUSTEP_LOCAL_ROOT"];
    NSString *_bundlePath;

    if (prefix && ![prefix isEqualToString:@""]) {
      _bundlePath = [prefix stringByAppendingPathComponent:@"Library/ProjectCenter"];
    }
    else {
      _bundlePath = [NSString stringWithString:@"/usr/GNUstep/Local/Library/ProjectCenter"];
    }

    [defaults setObject:_bundlePath forKey:BundlePaths];

    [defaults setObject:@"/bin/vi" forKey:Editor];
    [defaults setObject:@"/usr/bin/gdb" forKey:Debugger];
    [defaults setObject:@"/usr/bin/gcc" forKey:Compiler];

    [defaults setObject:@"YES" forKey:ExternalEditor];

    [defaults setObject:[NSString stringWithFormat:@"%@/ProjectCenterBuildDir",NSTemporaryDirectory()] forKey:RootBuildDirectory];

    /*
    [defaults setBool:YES forKey:PromtOnClean];
    [defaults setBool:YES forKey:PromtOnQuit];
    [defaults setBool:YES forKey:AutoSave];
    [defaults setBool:NO forKey:RemoveBackup];
    [defaults setInteger:60 forKey:AutoSavePeriod];
    [defaults setBool:NO forKey:DeleteCacheWhenQuitting];
     */
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)init
{
    if ((self = [super init])) {
        // The bundle loader
        bundleLoader = [[PCBundleLoader alloc] init];
        [bundleLoader setDelegate:self];

        // They are registered by the bundleLoader
        projectTypes = [[NSMutableDictionary alloc] init];

 	prefController = [[PCPrefController alloc] init];
	finder = [[PCFindController alloc] init];
	infoController = [[PCInfoController alloc] init];
	logger = [[PCLogController alloc] init];
	projectManager = [[PCProjectManager alloc] init];
	fileManager = [PCFileManager fileManager];
	menuController = [[PCMenuController alloc] init];

	[projectManager setDelegate:self];
	[fileManager setDelegate:projectManager];

	[menuController setAppController:self];
	[menuController setFileManager:fileManager];
	[menuController setProjectManager:projectManager];
    }
    return self;
}

- (void)dealloc
{
  if (doConnection) {
    [doConnection invalidate];
    [doConnection release];
  }
  
  [prefController release];
  [finder release];
  [infoController release];
  [logger release];
  [projectManager release];
  [fileManager release];
  [menuController release];
  
  [bundleLoader release];
  [doServer release];
  [projectTypes release];
  
  [super dealloc];
}

//============================================================================
//==== Delegate
//============================================================================

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
  delegate = aDelegate;
}

//============================================================================
//==== Bundle Management
//============================================================================

- (PCBundleLoader *)bundleLoader
{
  return bundleLoader;
}

- (PCProjectManager *)projectManager
{
  return projectManager;
}

- (PCPrefController *)prefController
{
  return prefController;
}

- (PCServer *)doServer
{
  return doServer;
}

- (PCFindController *)finder
{
  return finder;
}

- (PCLogController *)logger
{
  return logger;
}

- (NSDictionary *)projectTypes
{
  return projectTypes;
}

//============================================================================
//==== Misc...
//============================================================================

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  if ([[fileName lastPathComponent] isEqualToString:@"PC.project"] == NO) {
    return NO;
  }

  return [projectManager openProjectAt:fileName];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
  [bundleLoader loadBundles];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  NSString *h = [[NSProcessInfo processInfo] hostName];
  NSString *connectionName = [NSString stringWithFormat:@"ProjectCenter:%@",h];
  [logger logMessage:@"Loading additional subsystems..." tag:INFORMATION];

  //[bundleLoader loadBundles];
    
  // The DO server
  doServer = [[PCServer alloc] init];
  
  NS_DURING
    
  doConnection = [[NSConnection alloc] init];
  [doConnection registerName:connectionName];
  
  NS_HANDLER
    
  NSRunAlertPanel(@"Warning!",@"Could not register the DO connection %@",@"OK",nil,nil,nil,connectionName);
  NS_ENDHANDLER
    
  [[NSNotificationCenter defaultCenter] addObserver:doServer selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:doConnection];
  
  [doConnection setDelegate:doServer];

  [[NSNotificationCenter defaultCenter] postNotificationName:PCAppDidInitNotification object:nil];
}

- (BOOL)applicationShouldTerminate:(id)sender
{
// This should be queried per project!
/*
    if ([projectManager hasEditedDocuments]) {
        if (NSRunAlertPanel(@"Unsaved projects!", @"Do you want to save them?", @"Yes", @"No", nil)) {
            [projectManager saveAllProjects];
        }
    }
*/
    [[NSNotificationCenter defaultCenter] postNotificationName:PCAppWillTerminateNotification object:nil];

    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // [[PCLogController sharedController] logMessageWithTag:INFORMATION object:self format:@"ProjectCenter is going down..."];

    if ([[[NSUserDefaults standardUserDefaults] stringForKey:DeleteCacheWhenQuitting] isEqualToString:@"YES"]) {
        [[NSFileManager defaultManager] removeFileAtPath:[projectManager rootBuildPath] handler:nil];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//============================================================================
//==== Delegate stuff
//============================================================================

- (void)bundleLoader:(id)sender didLoadBundle:(NSBundle *)aBundle
{
    Class principalClass;
    
    NSAssert(aBundle,@"No valid bundle!");

    principalClass = [aBundle principalClass];
    if ([principalClass conformsToProtocol:@protocol(ProjectType)]) {
        NSString	*name = [[principalClass sharedCreator] projectTypeName];

        [logger logMessage:[NSString stringWithFormat:@"Project type %@ successfully loaded!",name] tag:INFORMATION];

        if ([self registerProjectCreator:NSStringFromClass(principalClass) forKey:name]) {
            [menuController addProjectTypeNamed:name];

            [logger logMessage:[NSString stringWithFormat:@"Project type %@ successfully registered!",name] tag:INFORMATION];
        }
    }
    else if ([principalClass conformsToProtocol:@protocol(FileCreator)]) {
        [fileManager registerCreatorsWithObjectsAndKeys:[[principalClass sharedCreator] creatorDictionary]];

	// In objc.h there is already th like (char *)name...
	// [logger logMessage:[NSString stringWithFormat:@"FileCreator %@ successfully loaded!",(NSString *)[[principalClass sharedCreator] name]] tag:INFORMATION];
}
}

@end

@implementation PCAppController (ProjectRegistration)

- (BOOL)registerProjectCreator:(NSString *)className forKey:(NSString *)aKey
{
    if ([projectTypes objectForKey:aKey]) {
        return NO;
    }

    [projectTypes setObject:className forKey:aKey];

    return YES;
}

@end
