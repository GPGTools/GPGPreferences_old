//
//  GPGExtensionsPrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sat Mar 09 2002.
//
//
//  Copyright (C) 2002 Mac GPG Project.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://macgpg.sourceforge.net/> or <macgpg@rbisland.cx>
//


#import "GPGExtensionsPrefs.h"
#import "GPGOptions.h"


static NSString	*defaultExtensionsLibPath = @"/usr/local/lib/gnupg";


@implementation GPGExtensionsPrefs

- (void) dealloc
{
    [extensionsTableView setDataSource:nil];
    [extensionsTableView setDelegate:nil];
    [switchProtoButton autorelease];
    [extensions release];

    [super dealloc];
}

- (void) reloadExtensions
{
    [extensions release];
    extensions = nil;
}

- (NSMutableArray *) extensions
{
    if(extensions == nil){
        NSFileManager			*fileManager = [NSFileManager defaultManager];
        NSDirectoryEnumerator	*anEnum = [fileManager enumeratorAtPath:defaultExtensionsLibPath];
        NSString				*aName;
        int						i;
        NSArray					*optionNames = [[self options] optionNames];
        NSArray					*optionValues = [[self options] optionValues];
        NSArray					*optionStates = [[self options] optionStates];
        NSMutableDictionary		*extDictPerLocation = [NSMutableDictionary dictionary];

        extensions = [[NSMutableArray alloc] initWithCapacity:3];

        while(aName = [anEnum nextObject]){
            NSString	*fullPath = [defaultExtensionsLibPath stringByAppendingPathComponent:aName];
            BOOL		isDir;

            if([fileManager fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir){
                NSMutableDictionary	*extensionDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"isExtensionEnabled", aName, @"extensionName", defaultExtensionsLibPath, @"extensionLocation", [NSNumber numberWithBool:YES], @"fileExists", nil];

                [anEnum skipDescendents];
                [extensions addObject:extensionDict];
                [extDictPerLocation setObject:extensionDict forKey:fullPath];
            }
        }

        for(i = [optionNames count] - 1; i >= 0; i--){
            if([[optionNames objectAtIndex:i] isEqualToString:@"load-extension"]){
                NSString			*aValue = [optionValues objectAtIndex:i];
                NSMutableDictionary	*extensionDict;
                BOOL				fileExists;
                BOOL				isEnabled;
                BOOL				isDir;

                if(![aValue hasPrefix:@"/"])
                    aValue = [defaultExtensionsLibPath stringByAppendingPathComponent:aValue];

                isEnabled = [[optionStates objectAtIndex:i] boolValue];
                fileExists = [fileManager fileExistsAtPath:aValue isDirectory:&isDir];
                fileExists = (fileExists && !isDir);
                extensionDict = [extDictPerLocation objectForKey:aValue];

                if(fileExists || isEnabled){
                    if(extensionDict != nil){
                        if(![[extensionDict objectForKey:@"isExtensionEnabled"] boolValue] && isEnabled)
                            [extensionDict setObject:[NSNumber numberWithBool:YES] forKey:@"isExtensionEnabled"];
                    }
                    else{
                        extensionDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:isEnabled], @"isExtensionEnabled", [aValue lastPathComponent], @"extensionName", [aValue stringByDeletingLastPathComponent], @"extensionLocation", [NSNumber numberWithBool:fileExists], @"fileExists", nil];
                        [extensions addObject:extensionDict];
                        [extDictPerLocation setObject:extensionDict forKey:aValue];
                    }
                }
            }
        }
    }

    return extensions;
}

- (void) saveExtensions
{
    NSEnumerator	*anEnum = [[self extensions] objectEnumerator];
    NSDictionary	*anExtension;
    int				aCount;

    // First we remove all load-extension occurences
    [[self options] setOptionValue:nil forName:@"load-extension"];
    aCount = [[[self options] optionNames] count];
    while(anExtension = [anEnum nextObject]){
        [[self options] addOptionNamed:@"load-extension"];
        [[self options] setOptionValue:[[anExtension objectForKey:@"extensionLocation"] stringByAppendingPathComponent:[anExtension objectForKey:@"extensionName"]] atIndex:aCount];
        [[self options] setOptionState:[[anExtension objectForKey:@"isExtensionEnabled"] boolValue] atIndex:aCount];
        aCount++;
    }
    
    [[self options] saveOptions];
    [self reloadExtensions];
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    [[extensionsTableView tableColumnWithIdentifier:@"isExtensionEnabled"] setDataCell:[switchProtoButton cell]];
    [[switchProtoButton retain] removeFromSuperview];
    [self tableViewSelectionDidChange:nil];
}

- (void) tabItemWillBeSelected
{
    [super tabItemWillBeSelected];
    [self reloadExtensions];
    [extensionsTableView reloadData];
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSNumber	*selectedRowNumber = (NSNumber *)contextInfo;

    if(returnCode == NSOKButton){
        NSEnumerator		*anEnum;
        NSString			*aFilename;
        int					selectedRow = [selectedRowNumber intValue];
        int					aCount = [[sheet filenames] count];
        NSMutableDictionary	*extDictPerLocation = [NSMutableDictionary dictionaryWithCapacity:[[self extensions] count]];
        NSMutableDictionary	*extensionDict;

        anEnum = [[self extensions] objectEnumerator];
        while(extensionDict = [anEnum nextObject]){
            aFilename = [[extensionDict objectForKey:@"extensionLocation"] stringByAppendingPathComponent:[extensionDict objectForKey:@"extensionName"]];
            [extDictPerLocation setObject:extensionDict forKey:aFilename];
        }

        anEnum = [[sheet filenames] reverseObjectEnumerator];
        while(aFilename = [anEnum nextObject]){
            extensionDict = [extDictPerLocation objectForKey:aFilename];
            if(extensionDict != nil)
                [extensionDict setObject:[NSNumber numberWithBool:YES] forKey:@"isExtensionEnabled"];
            else{
                extensionDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"isExtensionEnabled", [aFilename lastPathComponent], @"extensionName", [aFilename stringByDeletingLastPathComponent], @"extensionLocation", [NSNumber numberWithBool:YES], @"fileExists", nil];
                [[self extensions] insertObject:extensionDict atIndex:selectedRow];
            }
        }
        
        [self saveExtensions];
        [extensionsTableView reloadData];
        [extensionsTableView selectRow:selectedRow byExtendingSelection:NO];
        [extensionsTableView selectRow:(selectedRow + aCount) byExtendingSelection:YES];
        [extensionsTableView scrollRowToVisible:selectedRow];        
    }
    [selectedRowNumber release];
}

- (IBAction) addExtension:(id)sender
{
    int			selectedRow = [extensionsTableView selectedRow];
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
    NSNumber	*selectedRowNumber;

    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setCanSelectHiddenExtension:YES];
    [openPanel setExtensionHidden:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setPrompt:NSLocalizedStringFromTableInBundle(@"ADD EXTENSION", nil, [NSBundle bundleForClass:[self class]], "")];
    [openPanel setAccessoryView:nil];
    
    if(selectedRow >= 0)
        selectedRowNumber = [[[[extensionsTableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] objectAtIndex:0];
    else
        selectedRowNumber = [NSNumber numberWithInt:[extensionsTableView numberOfRows] - 1];

    [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[view window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:[selectedRowNumber retain]];
}

- (IBAction) deleteExtension:(id)sender
{
    NSEnumerator	*anEnum = [[[[extensionsTableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
    NSNumber		*aRow;

    // No need to filter out modules in defaultExtensionsLibPath, they will be reloaded
    while(aRow = [anEnum nextObject])
        [[self extensions] removeObjectAtIndex:[aRow unsignedIntValue]];
    [self saveExtensions];
    [extensionsTableView reloadData];
    [extensionsTableView deselectAll:nil];
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[self extensions] count];
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    return [[[self extensions] objectAtIndex:row] objectForKey:[tableColumn identifier]];
}

- (void) tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    NSParameterAssert([[tableColumn identifier] isEqualToString:@"isExtensionEnabled"]);
    [[[self extensions] objectAtIndex:row] setObject:object forKey:[tableColumn identifier]];
    [self saveExtensions];
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    BOOL			flag = NO;
    NSEnumerator	*anEnum = [extensionsTableView selectedRowEnumerator];
    NSNumber		*aRow;
    
    // Do not allow deletion of module if in /usr/local/lib/gnupg
    // Deletion is simply removing module from list; file is not affected
    while(aRow = [anEnum nextObject]){
        if(![[[[self extensions] objectAtIndex:[aRow intValue]] objectForKey:@"extensionLocation"] isEqualToString:defaultExtensionsLibPath]){
            flag = YES;
            break;
        }
    }
    
    [deleteExtensionButtonCell setEnabled:flag];
}

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if(![[tableColumn identifier] isEqualToString:@"isExtensionEnabled"]){
        BOOL	fileExists = [[[[self extensions] objectAtIndex:row] objectForKey:@"fileExists"] boolValue];
        
        [cell setTextColor:(fileExists ? [NSColor controlTextColor]:[NSColor redColor])];
        if(fileExists)
            [cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toNotHaveTrait:NSItalicFontMask]];
        else
#warning Does not work
            [cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toHaveTrait:NSItalicFontMask]];
    }
}

@end
