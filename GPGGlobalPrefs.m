//
//  GPGGlobalPrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sun Feb 03 2002.
//
//
//  Copyright (C) 2002-2003 Mac GPG Project.
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
//  More info at <http://macgpg.sourceforge.net/> or <macgpg@rbisland.cx>
//

#import "GPGGlobalPrefs.h"
#import "GPGOptions.h"
#import "GPGPreferences.h"


@implementation GPGGlobalPrefs

- (void) dealloc
{
    [warningView release];
    [[moveButton superview] release];
    
    [super dealloc];
}

- (void) updateWarningView
{
    if([GPGOptions homeDirectoryChanged]){
        if([warningView superview] == nil)
            [warningPlaceholder addSubview:warningView];
    }
    else if([warningView superview] != nil)
        [warningView removeFromSuperview];
}

- (void) tabItemWillBeSelected
{
    NSString	*version;
    
    [super tabItemWillBeSelected];
    [gpgPathTextField setStringValue:[GPGOptions gpgPath]];
    [homeDirectoryTextField setStringValue:[GPGOptions homeDirectory]];
    [self updateWarningView];

    version = [preferences gnupgVersion];
    if(version != nil)
        [versionTextField setStringValue:version];
    else
        [versionTextField setStringValue:NSLocalizedStringFromTableInBundle(@"GPG NOT FOUND", nil, [NSBundle bundleForClass:[self class]], "")];
}

- (BOOL) setAccessRightsAtPath:(NSString *)path
{
    BOOL			unableToSetAllRights = NO;
    NSFileManager	*defaultManager = [NSFileManager defaultManager];
    NSString		*aComponent;
    NSDictionary	*directoryAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0700], NSFilePosixPermissions, NSUserName(), NSFileOwnerAccountName, nil];
    NSDictionary	*fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0600], NSFilePosixPermissions, NSUserName(), NSFileOwnerAccountName, nil];
    NSEnumerator	*anEnum;

    unableToSetAllRights = ![defaultManager changeFileAttributes:directoryAttributes atPath:path];

    anEnum = [defaultManager enumeratorAtPath:path];
    while(aComponent = [anEnum nextObject]){
        NSString	*destinationPath = [path stringByAppendingPathComponent:aComponent];
        BOOL		isDirectory;

        if([defaultManager fileExistsAtPath:destinationPath isDirectory:&isDirectory])
            unableToSetAllRights = unableToSetAllRights || ![defaultManager changeFileAttributes:(isDirectory ? directoryAttributes:fileAttributes) atPath:destinationPath];
    }

    return !unableToSetAllRights;
}

- (BOOL) moveHomeDirectory:(NSString *)homeDirectory toPath:(NSString *)newHomeDirectory
{
    NSFileManager	*defaultManager = [NSFileManager defaultManager];
    NSEnumerator	*anEnum = [[newHomeDirectory pathComponents] objectEnumerator];
    NSString		*aComponent;
    NSString		*aPath = @"/";
    BOOL			created = YES;
    BOOL			couldNotMoveAtLeastOneFile = NO;
    BOOL			couldMoveAtLeastOneFile = NO;
    BOOL			unableToSetRights;

    // Create directory if necessary
    while(aComponent = [anEnum nextObject]){
        BOOL	isDirectory;

        aPath = [aPath stringByAppendingPathComponent:aComponent];
        if(![defaultManager fileExistsAtPath:aPath isDirectory:&isDirectory]){
            if(![defaultManager createDirectoryAtPath:aPath attributes:nil]){
                created = NO;
                break;
            }
        }
    }

    if(!created){
        NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"UNABLE TO CREATE DIRECTORY", nil, bundle, ""), nil, nil, nil, [view window], nil, NULL, NULL, NULL, NSLocalizedStringFromTableInBundle(@"UNABLE TO CREATE DIRECTORY AT %@", nil, bundle, ""), aPath);
        return NO;
    }

    anEnum = [defaultManager enumeratorAtPath:homeDirectory];
    while(aComponent = [anEnum nextObject]){
        NSString	*destinationPath = [newHomeDirectory stringByAppendingPathComponent:aComponent];
        BOOL		ok = [defaultManager movePath:[homeDirectory stringByAppendingPathComponent:aComponent] toPath:destinationPath handler:nil];
        // Moving is done by copying file, and then removing original one
        // If removing does not work, it returns NO, but leaves copy!

        couldNotMoveAtLeastOneFile = couldNotMoveAtLeastOneFile || !ok;
        couldMoveAtLeastOneFile = couldMoveAtLeastOneFile || ok;
    }

    unableToSetRights = ![self setAccessRightsAtPath:newHomeDirectory];
    if(!couldNotMoveAtLeastOneFile){
        (void)[defaultManager removeFileAtPath:homeDirectory handler:nil];
        if(unableToSetRights){
            NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

            NSBeginInformationalAlertSheet(NSLocalizedStringFromTableInBundle(@"ERROR WITH HOMEDIRECTORY ACCESS RIGHTS", nil, bundle, ""), nil, nil, nil, [view window], nil, NULL, NULL, NULL, NSLocalizedStringFromTableInBundle(@"DIRECTORY MOVED TO %@, BUT SOME ACCESS RIGHTS COULD NOT BE SET - PLEASE CHECK.", nil, bundle, ""), newHomeDirectory);
        }
    }
    else{
        NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"ERROR WHEN MOVING HOMEDIRECTORY", nil, bundle, ""), nil, nil, nil, [view window], nil, NULL, NULL, NULL, NSLocalizedStringFromTableInBundle((couldMoveAtLeastOneFile ? @"UNABLE TO MOVE WHOLE DIRECTORY CONTENT %@ TO %@":@"UNABLE TO MOVE DIRECTORY %@ TO %@ - NO CHANGE"), nil, bundle, ""), homeDirectory, newHomeDirectory);

        return couldMoveAtLeastOneFile;
    }

    return YES;
}

- (void) sheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString	*homeDirectory = (NSString *)contextInfo;

    switch(returnCode){
        case NSAlertDefaultReturn:
            // Move directory
            if(![self moveHomeDirectory:[GPGOptions homeDirectory] toPath:homeDirectory])
                break;
            // Else, no break!
        case NSAlertAlternateReturn:
            // Keep new directory as-is, don't move anything
            // User is responsible to copy files, set access rights
            [GPGOptions setHomeDirectory:homeDirectory];
            [self updateWarningView];
            break;
        // If cancel or error, do nothing
    }
    [homeDirectoryTextField setStringValue:[GPGOptions homeDirectory]];
    [homeDirectory release];
}

- (void) setHomeDirectory:(NSString *)homeDirectory
{
    // Tell user that files will be moved, or cancel
    NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

    NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"MOVE FILES?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"MOVE", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T MOVE", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"CANCEL", nil, bundle, ""), [view window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), [homeDirectory retain], NSLocalizedStringFromTableInBundle(@"MOVE CONTENT OF %@ TO %@", nil, bundle, ""), [GPGOptions homeDirectory], homeDirectory);
}

- (IBAction) changeHomeDirectory:(id)sender
{
    NSString	*homeDirectory = [homeDirectoryTextField stringValue];

#warning After having changed home directory, we should check file permissions!
    if(homeDirectory != nil && [homeDirectory rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length > 0){
        homeDirectory = [homeDirectory stringByStandardizingPath];
        if(![homeDirectory isAbsolutePath])
            homeDirectory = [@"/" stringByAppendingPathComponent:homeDirectory];

        if(![homeDirectory isEqualToString:[[GPGOptions homeDirectory] stringByStandardizingPath]])
            [self setHomeDirectory:homeDirectory];
        else
            [homeDirectoryTextField setStringValue:homeDirectory];
    }
    else
        // We don't accept an empty path
        [homeDirectoryTextField setStringValue:[GPGOptions homeDirectory]];
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString	*homeDirectory = (NSString *)contextInfo;

    if(returnCode == NSOKButton){
        NSString	*newHomeDirectory = [sheet filename];
        
        if(![moveButton state] || [self moveHomeDirectory:homeDirectory toPath:newHomeDirectory]){
            [GPGOptions setHomeDirectory:newHomeDirectory];
            [self updateWarningView];
            [homeDirectoryTextField setStringValue:[GPGOptions homeDirectory]];
        }
    }
    [homeDirectory release];
}

- (IBAction) chooseHomeDirectory:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
    NSString	*homeDirectory = [GPGOptions homeDirectory];

    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanSelectHiddenExtension:YES];
    [openPanel setExtensionHidden:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setPrompt:NSLocalizedStringFromTableInBundle(@"CHOOSE", nil, [NSBundle bundleForClass:[self class]], "")];
    [openPanel setAccessoryView:[moveButton superview]];
    [moveButton setState:YES];

    [openPanel beginSheetForDirectory:homeDirectory file:nil types:nil modalForWindow:[view window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:[homeDirectory retain]];
}

- (IBAction) showWarranty:(id)sender
{
    NSString	*warranty = [preferences outputFromGPGTaskWithArgument:@"--warranty"];

    if(warranty != nil){
        // Let's reformat the string
        NSEnumerator	*anEnum = [[warranty componentsSeparatedByString:@"\n"] objectEnumerator];
        NSString		*aLine;
        NSMutableArray	*newLines = [NSMutableArray array];
        int				endingEmptyLinesCount = 0;

        while(aLine = [anEnum nextObject]){
            if([aLine isEqualToString:@""]){
                endingEmptyLinesCount++;
                [newLines addObject:@"\n\n"];
            }
            else{
                [newLines addObject:aLine];
                endingEmptyLinesCount = 0;
            }
        }
        // Let's remove ending empty lines
        if(endingEmptyLinesCount > 0)
            newLines = (NSMutableArray *)[newLines subarrayWithRange:NSMakeRange(0, [newLines count] - endingEmptyLinesCount)];

        warranty = [newLines componentsJoinedByString:@" "];
        
        NSBeginInformationalAlertSheet(NSLocalizedStringFromTableInBundle(@"WARRANTY", nil, [NSBundle bundleForClass:[self class]], nil), nil, nil, nil, [view window], nil, NULL, NULL, NULL, @"%@", warranty);
    }
    else
        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"WARRANTY", nil, [NSBundle bundleForClass:[self class]], nil), nil, nil, nil, [view window], nil, NULL, NULL, NULL, @"%@", NSLocalizedStringFromTableInBundle(@"WARRANTY ERROR", nil, [NSBundle bundleForClass:[self class]], nil));
}

@end
