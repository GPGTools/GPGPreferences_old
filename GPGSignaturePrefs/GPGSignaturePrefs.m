//
//  GPGSignaturePrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Wed Mar 06 2002.
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


#import "GPGSignaturePrefs.h"
#import <MacGPGME/MacGPGME.h>


@implementation GPGSignaturePrefs

- (void) dealloc
{
    [options release];
    
    [super dealloc];
}

- (GPGOptions *) options
{
    if(options == nil)
        options = [[GPGOptions alloc] init];
    
    return options;
}

- (void)willSelect
{
    BOOL		displaysVersion = YES;
    int			i;
    NSArray		*optionNames = [[self options] optionNames];
    NSArray		*optionStates = [[self options] optionStates];
    int			optionNamesCount = [optionNames count];
    NSString	*aString;
    NSArray     *commentLines;
    BOOL        isActive;
    
    [super willSelect];

    isActive = [[self options] optionStateForName:@"comment"];
    [commentSwitch setState:isActive ? NSOnState : NSOffState];
    if(isActive)
        commentLines = [[self options] activeOptionValuesForName:@"comment"];
    else
        commentLines = [[self options] allOptionValuesForName:@"comment"];
    if(commentLines == nil)
        aString = @"";
    else
        aString = [commentLines componentsJoinedByString:@"\n"];
    [customCommentsTextView setString:aString];

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
    [useKeyServerURLSwitch setState:[[self options] optionStateForName:@"sig-keyserver-url"]];
    aString = [[self options] optionValueForName:@"sig-keyserver-url"];
    if(aString == nil)
        aString = @"";
    [keyServerURLTextField setStringValue:aString];
}

- (void)willUnselect
{   
//    if([[customCommentsTextView window] firstResponder] == customCommentsTextView)
//        [customCommentsTextView commitEditing];
    
    [options release];
    options = nil;
}

- (BOOL)isCommentActive
{
    return ([commentSwitch state] == NSOnState);
}

- (void)saveComment:(NSString *)comment active:(BOOL)isActive
{
    NSEnumerator    *lineEnum = [[comment componentsSeparatedByString:@"\n"] objectEnumerator];
    NSString        *eachLine;
    
    [[self options] setOptionValue:nil forName:@"comment"];
    while(eachLine = [lineEnum nextObject])
        [[self options] addOptionNamed:@"comment" value:eachLine state:isActive];
    [[self options] saveOptions];
}

- (void) sheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [self replyToShouldUnselect:YES];
}

- (void) sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    NSString	*comment = (NSString *)contextInfo;
    
    if(returnCode == NSAlertAlternateReturn)
        [self saveComment:comment active:[self isCommentActive]];
    else{
        BOOL        isActive = [[self options] optionStateForName:@"comment"];
        NSArray     *commentLines;
        NSString	*oldComment;
        
        if(isActive)
            commentLines = [[self options] activeOptionValuesForName:@"comment"];
        else
            commentLines = [[self options] allOptionValuesForName:@"comment"];
        if(commentLines == nil)
            oldComment = @"";
        else
            oldComment = [commentLines componentsJoinedByString:@"\n"];
        
        [customCommentsTextView setString:oldComment];
        [commentSwitch setState:isActive ? NSOnState : NSOffState];
    }
    
    [comment release];
}

- (NSString *) checkCommentWithCallbackSelector:(SEL)callbackSelector
{
    NSString	*comment = [customCommentsTextView string];
    BOOL		isEmptyComment = (comment == nil || [comment rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length == 0);

    if(isEmptyComment)
        [self saveComment:nil active:NO];
    else if(![comment canBeConvertedToEncoding:NSASCIIStringEncoding]){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"COMMENT SHOULD BE ASCII ONLY", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"CHANGE ANYWAY", nil, bundle, ""), nil, [[self mainView] window], self, @selector(sheetDidEnd:returnCode:contextInfo:), callbackSelector, [comment retain], @"%@", NSLocalizedStringFromTableInBundle(@"WHY ONLY ASCII IN COMMENT...", nil, bundle, ""));
    }
    else
        [self saveComment:comment active:[self isCommentActive]];
}

- (IBAction) toggleComment:(id)sender
{
    if([self isCommentActive])
        [self checkCommentWithCallbackSelector:NULL];
    else{
        [[self options] setOptionState:NO forName:@"comment"];
        [[self options] saveOptions];
    }
}

- (NSPreferencePaneUnselectReply)shouldUnselect
{
    if([[customCommentsTextView window] firstResponder] == customCommentsTextView){
        delayedUnselect = YES;
        [[customCommentsTextView window] makeFirstResponder:nil];
        return NSUnselectLater;
    }
    else
        return NSUnselectNow;
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
    [self checkCommentWithCallbackSelector:(delayedUnselect ? @selector(sheetDidDismiss:returnCode:contextInfo:) : NULL)];
    delayedUnselect = NO;
}

- (IBAction) toggleVersion:(id)sender
{
    BOOL	flag = [sender state];

    [[self options] setOptionValue:nil forName:@"emit-version"]; // This option should not be used in options file; let's remove it
    [[self options] setOptionState:!flag forName:@"no-version"];
    [[self options] saveOptions];
}

- (IBAction)updateKeyServerURL:(id)sender
{
    [[self options] setOptionValue:[sender stringValue] forName:@"sig-keyserver-url"];
    [[self options] saveOptions];
}

- (IBAction)toggleKeyServerURL:(id)sender
{
    BOOL	flag = [sender state];
    
    [[self options] setOptionState:flag forName:@"sig-keyserver-url"];
    [[self options] setOptionValue:[keyServerURLTextField stringValue] forName:@"sig-keyserver-url"];
    [[self options] saveOptions];
}

@end
