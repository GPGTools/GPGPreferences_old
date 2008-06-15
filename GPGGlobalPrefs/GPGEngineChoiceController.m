//
//  GPGEngineChoiceController.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sat Dec 29 2007.
//
//
//  Copyright (C) 2002-2008 Mac GPG Project.
//  
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your options) any later version.
//  
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place--Suite 330, Boston, MA 02111-1307, USA
//  
//  More info at <http://macgpg.sourceforge.net/>
//

#import "GPGEngineChoiceController.h"
#import <MacGPGME/MacGPGME.h>


@implementation GPGEngineChoiceController

+ (id)sharedController
{
    static GPGEngineChoiceController    *sharedController = nil;
    
    if(sharedController == nil)
        sharedController = [[self alloc] init];
    
    return sharedController;
}

- (id)init
{
    if(self = [super init]){
        choices = [[NSMutableArray alloc] init];
        NSAssert([NSBundle loadNibNamed:@"GPGEngineChoiceController" owner:self], @"Unable to load nib named 'GPGEngineChoiceController'");
        NSAssert(window != nil, @"Error in nib 'GPGEngineChoiceController': 'window' outlet not bound");
        windowOriginalHeight = NSHeight([window contentRectForFrameRect:[window frame]]) - [choiceMatrix cellSize].height;
    }
         
    return self;
}

- (void) dealloc
{
    [engine release];
    [choices release];
    [selectedExecutablePath release];
    [window release];
    [arrayController release];
    
    [super dealloc];
}

- (void)resizeWindow
{
    // Matrix has already been resized by arrayController, but not repositioned;
    // window has not been resized.
    NSRect  aRect = [window contentRectForFrameRect:[window frame]];
    float   newHeight = windowOriginalHeight + NSHeight([choiceMatrix frame]);
    
    aRect.origin.y = NSMaxY(aRect) - newHeight;
    aRect.size.height = newHeight;
    aRect = [window frameRectForContentRect:aRect];
    [[self window] setFrame:aRect display:YES animate:YES];
}

- (NSWindow *)window
{    
    return window;
}

- (NSString *)selectedExecutablePath
{
    id  result = [[arrayController selection] valueForKey:@"path"];
    
    return NSIsControllerMarker(result) ? nil : result;
}

- (void)setSelectedExecutablePath:(NSString *)value
{
    NSEnumerator    *anEnum = [choices objectEnumerator];
    NSDictionary    *eachDict;
    id              newSelection = nil;
    
    while(eachDict = [anEnum nextObject]){
        if([[eachDict objectForKey:@"path"] isEqualToString:value]){
            newSelection = eachDict;
            break;
        }
    }
    if(newSelection)
        NSAssert1([arrayController setSelectedObjects:[NSArray arrayWithObject:newSelection]], @"Unable to set array controller selection to %@", [NSArray arrayWithObject:newSelection]);
    else
        [arrayController setSelectionIndex:NSNotFound];
}

- (GPGEngine *)engine
{
    return engine;
}

- (void)setEngine:(GPGEngine *)newEngine
{
    NSParameterAssert(newEngine != nil);

    [newEngine retain];
    [engine release];
    engine = newEngine;
    
    [self willChangeValueForKey:@"choices"];
    [choices removeAllObjects];
    
    NSString        *eachPath;
    NSArray         *availablePaths = [engine availableExecutablePaths];
    NSEnumerator    *anEnum = [availablePaths objectEnumerator];
    
    while(eachPath = [anEnum nextObject]){
        NSDictionary    *aDict = [NSDictionary dictionaryWithObjectsAndKeys:eachPath, @"path", [NSNumber numberWithBool:[availablePaths containsObject:eachPath]], @"enabled", nil];
        
        [choices addObject:aDict];
    }
    eachPath = [self selectedExecutablePath];
    if(eachPath != nil && ![availablePaths containsObject:eachPath]){
        NSDictionary    *aDict = [NSDictionary dictionaryWithObjectsAndKeys:eachPath, @"path", [NSNumber numberWithBool:[[NSFileManager defaultManager] isExecutableFileAtPath:eachPath]], @"enabled", nil];
        
        [choices addObject:aDict];
    }
    [self didChangeValueForKey:@"choices"];
    [self setSelectedExecutablePath:[engine executablePath]];

    // We cannot use bindings to set 'enabled' state on cells
    NSNumber    *eachState;
    NSInteger   aRow = 0;

    anEnum = [[choices valueForKey:@"enabled"] objectEnumerator];
    while(eachState = [anEnum nextObject])
        [[choiceMatrix cellAtRow:aRow++ column:0] setEnabled:[eachState boolValue]];
    [self resizeWindow];
}

- (IBAction)ok:(id)sender
{
    [[self window] orderOut:sender];
    [[NSApplication sharedApplication] endSheet:[self window] returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
    [[self window] orderOut:sender];
    [[NSApplication sharedApplication] endSheet:[self window] returnCode:NSCancelButton];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
    if(returnCode == NSOKButton){
        if(![[choices valueForKey:@"path"] containsObject:[panel filename]]){
            NSDictionary    *aDict = [NSDictionary dictionaryWithObjectsAndKeys:[panel filename], @"path", [NSNumber numberWithBool:YES], @"enabled", nil];
            
            [[self mutableArrayValueForKey:@"choices"] addObject:aDict];
            [self setSelectedExecutablePath:[panel filename]];
            [self resizeWindow];
        }
    }
    [panel release];
}

- (IBAction)other:(id)sender
{
    NSOpenPanel *openPanel = [[NSOpenPanel openPanel] retain];
    
    [openPanel setResolvesAliases:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setPrompt:NSLocalizedStringFromTableInBundle(@"SELECT_EXECUTABLE_PATH__PROMPT", nil, [NSBundle bundleForClass:[self class]], @"Prompt of executable choice panel")];
    [openPanel setTitle:NSLocalizedStringFromTableInBundle(@"SELECT_EXECUTABLE_PATH__TITLE", nil, [NSBundle bundleForClass:[self class]], @"Title of executable choice panel")];
    [openPanel beginSheetForDirectory:nil file:[self selectedExecutablePath] types:nil modalForWindow:nil modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

@end
