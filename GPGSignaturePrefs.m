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


@implementation GPGSignaturePrefs

- (void) tabItemWillBeSelected
{
    BOOL		displaysVersion = YES;
    int			i;
    NSArray		*optionNames = [[self options] optionNames];
    NSArray		*optionStates = [[self options] optionStates];
    int			optionNamesCount = [optionNames count];
    NSString	*customComment;
    
    [super tabItemWillBeSelected];

    [commentSwitch setState:[[self options] optionStateForName:@"comment"]];
    customComment = [[self options] optionValueForName:@"comment"];
    if(customComment == nil)
        customComment = @"";    
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

- (NSString *) checkComment
{
    NSString	*comment = [customCommentTextField stringValue];
    BOOL		isEmptyComment = (comment == nil || [comment rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length == 0);

    if(isEmptyComment){
        comment = @"";
        [[self options] setOptionState:NO forName:@"comment"];
    }
    else if(![comment canBeConvertedToEncoding:NSASCIIStringEncoding]){
        NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"COMMENT SHOULD BE ASCII ONLY", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"CHANGE ANYWAY", nil, bundle, ""), nil, [view window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), [comment retain], @"%@", NSLocalizedStringFromTableInBundle(@"WHY ONLY ASCII IN COMMENT...", nil, bundle, ""));
    }

    return comment;
}

- (IBAction) toggleComment:(id)sender
{
    if([commentSwitch state])
        (void)[self checkComment];
    [[self options] setOptionState:[commentSwitch state] forName:@"comment"];
    [[self options] saveOptions];
}

- (void) sheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString	*comment = (NSString *)contextInfo;

    if(returnCode == NSAlertAlternateReturn){
        [[self options] setOptionValue:comment forName:@"comment"];
        [[self options] saveOptions];
    }
    else{
        NSString	*oldComment = [[self options] optionValueForName:@"comment"];

        if(!oldComment)
            oldComment = @"";
        [customCommentTextField setStringValue:oldComment];
        [commentSwitch setState:[[self options] optionStateForName:@"comment"]];
    }

    [comment release];
}

- (IBAction) updateComment:(id)sender
{
    NSString	*comment = [self checkComment];
    
    [[self options] setOptionValue:comment forName:@"comment"];
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
