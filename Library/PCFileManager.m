/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2000-2004 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

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
*/

#include "PCDefines.h"
#include "PCFileManager.h"
#include "PCFileCreator.h"
#include "PCProjectManager.h"
#include "PCProject.h"
#include "PCProjectBrowser.h"
#include "PCServer.h"
#include "PCAddFilesPanel.h"

#include "PCLogController.h"

@implementation PCFileManager

// ===========================================================================
// ==== Class methods
// ===========================================================================

static PCFileManager *_mgr = nil;

+ (PCFileManager *)defaultManager
{
  if (_mgr == nil)
    {
      _mgr = [[self alloc] init];
    }

  return _mgr;
}

// ===========================================================================
// ==== Init and free
// ===========================================================================

- (id)initWithProjectManager:(PCProjectManager *)aProjectManager
{
  if ((self = [super init])) 
    {
      projectManager = aProjectManager;
      creators = [[PCFileCreator sharedCreator] creatorDictionary];
      RETAIN(creators);
    }
  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCFileManager: dealloc");
#endif

  RELEASE(creators);
  RELEASE(newFilePanel);

  if (addFilesPanel)
    {
      RELEASE(addFilesPanel);
    }
  
  [super dealloc];
}

// ===========================================================================
// ==== File stuff
// ===========================================================================

- (NSMutableArray *)filesForOpenOfType:(NSArray *)types
                              multiple:(BOOL)yn
			         title:(NSString *)title
			       accView:(NSView *)accessoryView
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString       *lastOpenDir = [ud objectForKey:@"LastOpenDirectory"];
  NSOpenPanel    *openPanel = nil;
  int            retval;

  openPanel = [NSOpenPanel openPanel];
  [openPanel setAllowsMultipleSelection:yn];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:NO];
//  [openPanel setDelegate:self];
  [openPanel setTitle:title];
  [openPanel setAccessoryView:accessoryView];

  if (!lastOpenDir)
    {
      lastOpenDir = NSHomeDirectory();
    }

  retval = [openPanel runModalForDirectory:lastOpenDir file:nil types:types];
  if (retval == NSOKButton) 
    {
      [ud setObject:[openPanel directory] forKey:@"LastOpenDirectory"];
      return [[[openPanel filenames] mutableCopy] autorelease];
    }

  return nil;
}

- (NSString *)fileForSaveOfType:(NSArray *)types
		          title:(NSString *)title
		        accView:(NSView *)accessoryView
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString       *lastOpenDir = [ud objectForKey:@"LastOpenDirectory"];
  NSSavePanel    *savePanel = nil;
  int            retval;

  savePanel = [NSSavePanel savePanel];
  [savePanel setDelegate:self];
  [savePanel setTitle:title];
//  [savePanel setAccessoryView:nil];
  [savePanel setAccessoryView:accessoryView];

  if (!lastOpenDir)
    {
      lastOpenDir = NSHomeDirectory();
    }

  retval = [savePanel runModalForDirectory:lastOpenDir file:nil];
  if (retval == NSOKButton) 
    {
      [ud setObject:[savePanel directory] forKey:@"LastOpenDirectory"];
      return [[[savePanel filename] mutableCopy] autorelease];
    }

  return nil;
}

- (BOOL)createDirectoriesIfNeededAtPath:(NSString *)path
{
  NSString       *_path = [NSString stringWithString:path];
  NSMutableArray *pathArray = [NSMutableArray array];
  NSFileManager  *fm = [NSFileManager defaultManager];
  BOOL           isDir;
  int            i;

  while (![fm fileExistsAtPath:_path isDirectory:&isDir])
    {
      [pathArray addObject:[_path lastPathComponent]];
      _path = [_path stringByDeletingLastPathComponent];
    }

  if (!isDir)
    {
      return NO;
    }

  if ([_path length] != [path length])
    {
      for (i = [pathArray count]-1; i >= 0; i--)
	{
	  _path = 
	    [_path stringByAppendingPathComponent:[pathArray objectAtIndex:i]];
	  if ([fm createDirectoryAtPath:_path attributes:nil] == NO)
	    {
	      return NO;
	    }
	}
    }

  return YES;
}

- (BOOL)copyFile:(NSString *)file toFile:(NSString *)toFile
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *directory = nil;

  if (!file)
    {
      return NO;
    }

  if (![fm fileExistsAtPath:toFile]) 
    {
      directory = [toFile stringByDeletingLastPathComponent];
      if ([self createDirectoriesIfNeededAtPath:directory] == NO)
	{
	  return NO;
	}

      if (![fm copyPath:file toPath:toFile handler:nil])
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)copyFile:(NSString *)file intoDirectory:(NSString *)directory
{
  NSString *path = nil;

  if (!file)
    {
      return NO;
    }
    
  path = [directory stringByAppendingPathComponent:[file lastPathComponent]];

  if (![self copyFile:file toFile:path])
    {
      return NO;
    }

  return YES;
}

- (BOOL)copyFiles:(NSArray *)files intoDirectory:(NSString *)directory
{
  NSEnumerator *enumerator = nil;
  NSString     *file = nil;

  if (!files)
    {
      return NO;
    }

  enumerator = [files objectEnumerator];
  while ((file = [enumerator nextObject]))
    {
      if ([self copyFile:file intoDirectory:directory] == NO)
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)removeFiles:(NSArray *)files fromDirectory:(NSString *)directory
{
  NSEnumerator  *filesEnum = nil;
  NSString      *file = nil;
  NSString      *path = nil;
  NSFileManager *fm = [NSFileManager defaultManager];

  if (!files)
    {
      return NO;
    }

  filesEnum = [files objectEnumerator];
  while ((file = [filesEnum nextObject]))
    {
      path = [directory stringByAppendingPathComponent:file];
      if (![fm removeFileAtPath:path handler:nil])
	{
	  return NO;
	}
    }
  return YES;
}

- (void)createFile
{
  NSString     *path = nil;
  NSString     *fileName = [nfNameField stringValue];
  NSString     *fileType = [nfTypePB titleOfSelectedItem];
  NSDictionary *theCreator = [creators objectForKey:fileType];
  NSString     *key = [theCreator objectForKey:@"ProjectKey"];

//  PCLogInfo(self, @"[createFile] %@", fileName);

  path = [projectManager fileManager:self 
                      willCreateFile:fileName
		             withKey:key];

//  PCLogInfo(self, @"creating file at %@", path);

  // Create file
  if (path) 
    {
      NSDictionary  *newFiles = nil;
      PCFileCreator *creator = nil;
      PCProject     *project = [projectManager activeProject];
      NSEnumerator  *enumerator;
      NSString      *aFile;

      creator = [theCreator objectForKey:@"Creator"];
      if (!creator) 
	{
	  NSRunAlertPanel(@"Attention!",
			  @"Could not create %@. The creator is missing!",
			  @"OK",nil,nil,fileName);
	  return;
	}

      // Do it finally...
      newFiles = [creator createFileOfType:fileType path:path project:project];

      // Key: name of file
      enumerator = [[newFiles allKeys] objectEnumerator]; 
      while ((aFile = [enumerator nextObject])) 
	{
	  fileType = [newFiles objectForKey:aFile];
	  theCreator = [creators objectForKey:fileType];
	  key = [theCreator objectForKey:@"ProjectKey"];
	   
	  [projectManager fileManager:self didCreateFile:aFile withKey:key];
	}
    }
}

@end

@implementation PCFileManager (UInterface)

// -- "New File in Project" Panel
- (void)showNewFilePanel
{
  if (!newFilePanel)
    {
      if ([NSBundle loadNibNamed:@"NewFile" owner:self] == NO)
	{
	  PCLogError(self, @"error loading NewFile NIB!");
	  return;
	}
      [newFilePanel setFrameAutosaveName:@"NewFile"];
      if (![newFilePanel setFrameUsingName: @"NewFile"])
    	{
	  [newFilePanel center];
	}
      [newFilePanel center];
      [nfImage setImage:[NSApp applicationIconImage]];
      [nfTypePB setRefusesFirstResponder:YES];
      [nfTypePB removeAllItems];
      [nfTypePB addItemsWithTitles:
	[[creators allKeys] 
	  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
      [nfTypePB selectItemAtIndex:0];
      [nfCancleButton setRefusesFirstResponder:YES];
      [nfCreateButton setRefusesFirstResponder:YES];
    }

  [self newFilePopupChanged:nfTypePB];

  [newFilePanel makeKeyAndOrderFront:self];
  [nfNameField setStringValue:@""];
  [newFilePanel makeFirstResponder:nfNameField];
}

- (void)closeNewFilePanel:(id)sender
{
  [newFilePanel orderOut:self];
}

- (void)createFile:(id)sender
{
  [self createFile];
  [self closeNewFilePanel:self];
}

- (void)newFilePopupChanged:(id)sender
{
  NSString     *type = [sender titleOfSelectedItem];
  NSDictionary *creator = [creators objectForKey:type];

  if (type)
    {
      [nfDescriptionTV setString:[creator objectForKey:@"TypeDescription"]];
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotif
{
  if ([aNotif object] != nfNameField)
    {
      return;
    }

  // TODO: Add check for valid file names
  if ([[nfNameField stringValue] length] > 0)
    {
      [nfCreateButton setEnabled:YES];
    }
  else
    {
      [nfCreateButton setEnabled:NO];
    }
}

// --- "Add Files..." panel
- (NSMutableArray *)filesForAddOfTypes:(NSArray*)fileTypes
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString       *lastOpenDir = [ud objectForKey:@"LastOpenDirectory"];
  PCProject      *project = [projectManager activeProject];
  NSString       *selectedCategory = nil;
  int            retval;

  if (addFilesPanel == nil)
    {
      addFilesPanel = [PCAddFilesPanel addFilesPanel];
      [addFilesPanel setDelegate:self];
    }
  [addFilesPanel setCategories:[project rootCategories]];
  selectedCategory = [[project projectBrowser] nameOfSelectedCategory];
  [addFilesPanel selectCategory:selectedCategory];

  if (!lastOpenDir)
    {
      lastOpenDir = NSHomeDirectory();
    }

  retval = [addFilesPanel runModalForDirectory:lastOpenDir
                                          file:nil
					 types:fileTypes];
  if (retval == NSOKButton) 
    {
      [ud setObject:[addFilesPanel directory] forKey:@"LastOpenDirectory"];
      return [[addFilesPanel filenames] mutableCopy];
    }

  return nil;
}

// ============================================================================
// ==== PCAddFilesPanel delegate
// ============================================================================

- (void)categoryChangedTo:(NSString *)category
{
  PCProject        *project = [projectManager activeProject];
  NSArray          *fileTypes = nil;
  PCProjectBrowser *browser = [project projectBrowser];
  NSString         *path = [browser path];

  [addFilesPanel setTitle:[NSString stringWithFormat:@"Add %@",category]];

  fileTypes = [project 
    fileTypesForCategoryKey:[project keyForCategory:category]];
  [addFilesPanel setFileTypes:fileTypes];

  // Set project browser path
  path = [path stringByDeletingLastPathComponent];
  path = [path stringByAppendingPathComponent:category];
  [browser setPath:path];
}

// ============================================================================
// ==== NSOpenPanel and NSSavePanel delegate
// ============================================================================

// If file name already in project -- don't show it! 
- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL          isDir;
  PCProject     *project = nil;
  NSArray       *fileTypes = nil;
  NSString      *category = nil;
  NSString      *categoryKey = nil;

  [fileManager fileExistsAtPath:filename isDirectory:&isDir];
  
  if ([[filename pathExtension] isEqualToString:@"gorm"])
    {
      isDir = NO;
    }
    
  if (sender == addFilesPanel && !isDir)
    {
      project = [projectManager activeProject];
      category = [addFilesPanel selectedCategory];
      categoryKey = [project keyForCategory:category];
      fileTypes = [project fileTypesForCategoryKey:categoryKey];
      // Wrong file extension
      if (fileTypes 
	  && ![fileTypes containsObject:[filename pathExtension]])
	{
	  return NO;
	}
      // File is already in project
      if (![project doesAcceptFile:filename forKey:categoryKey])
	{
	  return NO;
	}
    }

  return YES;
}

// Test if we should accept file name selected or entered
- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename
{
  if ([[sender className] isEqualToString:@"NSOpenPanel"])
    {
      ;
    }
  else if ([[sender className] isEqualToString:@"NSSavePanel"])
    {
      ;
    }
    
  return YES;
}

@end

