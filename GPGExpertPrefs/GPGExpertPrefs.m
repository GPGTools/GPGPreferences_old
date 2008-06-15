//
//  GPGExpertPrefs.m
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
//  More info at <http://macgpg.sourceforge.net/>
//

#import "GPGExpertPrefs.h"
#import <MacGPGME/MacGPGME.h>


static NSString	*privatePboardType = @"GPGExpertPrefsPrivate";


@interface GPGExpertPrefs(Private)
- (void) tableViewSelectionDidChange:(NSNotification *)notification;
@end


// TODO: add support for gpg-agent config file
@implementation GPGExpertPrefs

- (void)dealloc
{
    [optionsTableView setDataSource:nil];
    [optionsTableView setDelegate:nil];
    [optionsTableView unregisterDraggedTypes];
    [options release];

    [super dealloc];
}

- (GPGOptions *)options
{
    if(options == nil)
        options = [[GPGOptions alloc] init];
    
    return options;
}

- (void)mainViewDidLoad
{    
    [super mainViewDidLoad];
    
    [optionsTableView setVerticalMotionCanBeginDrag:YES];
    [self tableViewSelectionDidChange:nil];
    [optionsTableView registerForDraggedTypes:[NSArray arrayWithObject:privatePboardType]];
}

- (void)willSelect
{
    [super willSelect];

    [optionsTableView reloadData];
}

- (void)willUnselect
{
    [super willUnselect];
    
    [options release];
    options = nil;
}

- (IBAction)addOption:(id)sender
{
    int	selectedRow = [optionsTableView selectedRow];
    
    if(selectedRow >= 0){
        selectedRow = [[[[[optionsTableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] objectAtIndex:0] intValue];
        
        [[self options] insertOptionNamed:@"NEW_OPTION" atIndex:selectedRow];
    }
    else{
        [[self options] addOptionNamed:@"NEW_OPTION"];
        selectedRow = [optionsTableView numberOfRows] - 1;
    }
    [[self options] saveOptions];
    [optionsTableView reloadData];
    [optionsTableView selectRow:selectedRow byExtendingSelection:NO];
    [optionsTableView scrollRowToVisible:selectedRow];
}

- (IBAction)deleteOption:(id)sender
{
    NSEnumerator	*anEnum = [[[[optionsTableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
    NSNumber		*aRow;

    while(aRow = [anEnum nextObject])
        [[self options] removeOptionAtIndex:[aRow unsignedIntValue]];
    [[self options] saveOptions];
    [optionsTableView reloadData];
    [optionsTableView deselectAll:nil];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[[self options] optionNames] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if([[tableColumn identifier] isEqualToString:@"isOptionEnabled"])
        return [[[self options] optionStates] objectAtIndex:row];
    else if([[tableColumn identifier] isEqualToString:@"optionName"])
        return [[[self options] optionNames] objectAtIndex:row];
    else if([[tableColumn identifier] isEqualToString:@"optionValue"])
        return [[[self options] optionValues] objectAtIndex:row];
    else
        return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if([[tableColumn identifier] isEqualToString:@"isOptionEnabled"])
        [[self options] setOptionState:[object boolValue] atIndex:row];
    else if([[tableColumn identifier] isEqualToString:@"optionName"]){
        if([object rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0)
            [[self options] setOptionName:object atIndex:row];
    }
    else if([[tableColumn identifier] isEqualToString:@"optionValue"])
        [[self options] setOptionValue:object atIndex:row];
    [[self options] saveOptions];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [deleteOptionButtonCell setEnabled:([optionsTableView numberOfSelectedRows] != 0)];
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
    NSArray	*pboardTypes = [NSArray arrayWithObject:privatePboardType];
    
    [pboard declareTypes:pboardTypes owner:nil];
    [pboard addTypes:pboardTypes owner:nil];
    [pboard setData:[NSArchiver archivedDataWithRootObject:rows] forType:privatePboardType];

    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];

    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    NSArray	*pboardTypes = [NSArray arrayWithObject:privatePboardType];

    if([[info draggingPasteboard] availableTypeFromArray:pboardTypes] != nil){
        NSArray		*droppedRows = [NSUnarchiver unarchiveObjectWithData:[[info draggingPasteboard] dataForType:privatePboardType]];
        int			count;

        row = [[self options] moveOptionsAtIndexes:droppedRows toIndex:row];
        [optionsTableView deselectAll:nil];
        [optionsTableView reloadData];
        for(count = [droppedRows count]; count > 0; count--, row++)
            [optionsTableView selectRow:row byExtendingSelection:YES];

        return YES;
    }
    
    return NO;
}

- (IBAction)revealOptionsFileInFinder:(id)sender
{
    NSString	*filename = [[GPGEngine engineForProtocol:GPGOpenPGPProtocol] optionsFilename];
    
    if(![[NSWorkspace sharedWorkspace] selectFile:filename inFileViewerRootedAtPath:[filename stringByDeletingLastPathComponent]])
        NSBeep();
}

- (IBAction)openManPage:(id)sender
{
    NSString    *urlString;
    
    if([[[GPGEngine engineForProtocol:GPGOpenPGPProtocol] version] hasPrefix:@"1."])
        urlString = @"x-man-page://1/gpg";
    else
        urlString = @"x-man-page://1/gpg2";
    if(![[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]])
         NSBeep();
}

@end
