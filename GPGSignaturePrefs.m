//
//  GPGSignaturePrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Wed Mar 06 2002.
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


#import "GPGSignaturePrefs.h"
#import "GPGOptions.h"


enum {
    noCommentChoice = 0,
    defaultCommentChoice,
    customCommentChoice
};


@implementation GPGSignaturePrefs

- (void) tabItemWillBeSelected
{
    unsigned	selectedRow;
    NSString	*customComment = nil;
    BOOL		displaysNoComment = NO;
    BOOL		usesDefaultComment = NO;
    BOOL		usesCustomComment = NO;
    BOOL		displaysVersion = YES;
    int			i;
    NSArray		*optionNames = [[self options] optionNames];
    NSArray		*optionStates = [[self options] optionStates];
    int			optionNamesCount = [optionNames count];
    
    [super tabItemWillBeSelected];
    
    for(i = optionNamesCount - 1; i >= 0; i--){
        NSString	*aName = [optionNames objectAtIndex:i];

        if([aName isEqualToString:@"comment"]){
            NSString	*aComment = [[[self options] optionValues] objectAtIndex:i];

            if([aComment isEqualToString:@""]){
                if([[optionStates objectAtIndex:i] boolValue] && !usesCustomComment && !usesDefaultComment)
                    displaysNoComment = YES;
            }
            else{
                if([[optionStates objectAtIndex:i] boolValue]){
                    if(!usesCustomComment)
                        customComment = aComment;
                    if(!displaysNoComment && !usesDefaultComment)
                        usesCustomComment = YES;
                }
                else if(customComment == nil)
                    customComment = aComment;
            }
        }
        else if([aName isEqualToString:@"default-comment"] && [[optionStates objectAtIndex:i] boolValue]){
            if(!displaysNoComment && !usesCustomComment)
                usesDefaultComment = YES;
        }
    }
    if(customComment == nil){
        customComment = @"";
        if(!usesDefaultComment && !displaysNoComment)
            usesDefaultComment = YES;
    }
    
    if(usesDefaultComment)
        selectedRow = defaultCommentChoice;
    else if(displaysNoComment)
        selectedRow = noCommentChoice;
    else
        selectedRow = customCommentChoice;
    [commentMatrix selectCellAtRow:selectedRow column:0];
    [customCommentTextField setStringValue:customComment];

    for(i = optionNamesCount - 1; i >= 0; i--){
        NSString	*aName = [optionNames objectAtIndex:i];

        if([aName isEqualToString:@"emit-version"] && [[optionStates objectAtIndex:i] boolValue]){
            displaysVersion = YES;
            break;
        }
        else if([aName isEqualToString:@"no-version"] && [[optionStates objectAtIndex:i] boolValue]){
            displaysVersion = NO;
            break;
        }
    }
    [versionSwitch setState:displaysVersion];
}

- (IBAction) commentMatrixChanged:(id)sender
{
    NSString	*comment = [customCommentTextField stringValue];

    switch([commentMatrix selectedRow]){
        case defaultCommentChoice:
            [[self options] setOptionValue:comment forName:@"comment"];
            [[self options] setOptionState:NO forName:@"comment"];
            break;
        case noCommentChoice:
            [[self options] setOptionValue:comment forName:@"comment"];
            [[self options] setOptionState:NO forName:@"comment"];
            [[self options] addOptionNamed:@"comment"]; // Value is empty, but state is NO
            [[self options] setOptionState:YES atIndex:[[[self options] optionStates] count] - 1];
            [[self options] setEmptyOptionValueAtIndex:[[[self options] optionStates] count] - 1];
            break;
        default:
            [[self options] setOptionValue:comment forName:@"comment"];
            [[self options] setOptionState:YES forName:@"comment"];
    }
    [[self options] setOptionValue:nil forName:@"default-comment"]; // This option should not be used in options file; let's remove it
    [[self options] saveOptions];
}

- (IBAction) updateComment:(id)sender
{
    NSString	*comment = [customCommentTextField stringValue];
    BOOL		isEmptyComment;

    isEmptyComment = (comment == nil || [comment rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length == 0);
    if(isEmptyComment){
        comment = @"";
        [commentMatrix selectCellAtRow:noCommentChoice column:0];
    }
    else
        [commentMatrix selectCellAtRow:customCommentChoice column:0];

    [[self options] setOptionValue:comment forName:@"comment"];
    [[self options] setOptionState:!isEmptyComment forName:@"comment"];
    if(isEmptyComment){
        [[self options] addOptionNamed:@"comment"]; // Value is empty, but state is NO
        [[self options] setOptionState:YES atIndex:[[[self options] optionStates] count] - 1];
        [[self options] setEmptyOptionValueAtIndex:[[[self options] optionStates] count] - 1];
    }
    [[self options] setOptionValue:nil forName:@"default-comment"]; // This option should not be used in options file; let's remove it
    [[self options] saveOptions];
}

- (IBAction) toggleVersion:(id)sender
{
    BOOL	flag = [sender state];

    [[self options] setOptionValue:nil forName:@"emit-version"]; // This option should not be used in options file; let's remove it
    [[self options] setOptionState:!flag forName:@"no-version"];
    [[self options] saveOptions];
}

@end
