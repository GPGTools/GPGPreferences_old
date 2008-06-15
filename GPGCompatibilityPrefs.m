//
//  GPGCompatibilityPrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Thu Feb 07 2002.
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


#import "GPGCompatibilityPrefs.h"
#import <MacGPGME/MacGPGME.h>


enum {
    rfc1991OptionSet = 0,
    pgp2OptionSet,
    pgp6OptionSet,
    pgp7OptionSet,
    pgp8OptionSet,
    gnupgOptionSet, // The default set
    openPGPOptionSet,
    rfc2440OptionSet,
    rfc4880OptionSet
};


@implementation GPGCompatibilityPrefs

- (GPGOptions *) options
{
    if(options == nil)
        options = [[GPGOptions alloc] init];
    
    return options;
}

- (void) dealloc
{
    [options release];

    [super dealloc];
}

- (int) selectedOptionSetAndPGP5Compatibility:(BOOL *)pgp5CompatiblePtr
{
    NSArray		*optionNames;
    NSArray		*optionStates;
    unsigned	selectedTag = gnupgOptionSet;
    unsigned	previousSelectedTag = selectedTag;
    int			i;
    BOOL		pgp5Compatible = NO;

    optionNames = [[self options] optionNames];
    optionStates = [[self options] optionStates];

    for(i = [optionNames count] - 1; i >= 0; i--){
        NSString	*aName = [optionNames objectAtIndex:i];

        if([[optionStates objectAtIndex:i] boolValue] && selectedTag == gnupgOptionSet){
            if([aName isEqualToString:@"rfc1991"]){
                previousSelectedTag = selectedTag;
                selectedTag = rfc1991OptionSet;
            }
            else if([aName isEqualToString:@"pgp2"]){
                previousSelectedTag = selectedTag;
                selectedTag = pgp2OptionSet;
            }
            else if([aName isEqualToString:@"no-pgp2"] && selectedTag == pgp2OptionSet)
                selectedTag = previousSelectedTag;
            else if([aName isEqualToString:@"pgp6"]){
                previousSelectedTag = selectedTag;
                selectedTag = pgp6OptionSet;
            }
            else if([aName isEqualToString:@"no-pgp6"] && selectedTag == pgp6OptionSet)
                selectedTag = previousSelectedTag;
            else if([aName isEqualToString:@"pgp7"]){
                previousSelectedTag = selectedTag;
                selectedTag = pgp7OptionSet;
            }
            else if([aName isEqualToString:@"no-pgp7"] && selectedTag == pgp7OptionSet)
                selectedTag = previousSelectedTag;
            else if([aName isEqualToString:@"pgp8"]){
                previousSelectedTag = selectedTag;
                selectedTag = pgp8OptionSet;
            }
            else if([aName isEqualToString:@"no-pgp8"] && selectedTag == pgp8OptionSet)
                selectedTag = previousSelectedTag;
            else if([aName isEqualToString:@"gnupg"]){
                previousSelectedTag = selectedTag;
                selectedTag = gnupgOptionSet;
            }
            else if([aName isEqualToString:@"openpgp"]){
                previousSelectedTag = selectedTag;
                selectedTag = openPGPOptionSet;
            }
            else if([aName isEqualToString:@"rfc2440"]){
                previousSelectedTag = selectedTag;
                selectedTag = rfc2440OptionSet;
            }
            else if([aName isEqualToString:@"rfc4880"]){
                previousSelectedTag = selectedTag;
                selectedTag = rfc4880OptionSet;
            }
            else if([aName isEqualToString:@"force-v3-sigs"])
                pgp5Compatible = YES;
            else if([aName isEqualToString:@"no-force-v3-sigs"])
                pgp5Compatible = NO;
        }
    }

    *pgp5CompatiblePtr = (pgp5Compatible || (selectedTag == rfc1991OptionSet) || (selectedTag == pgp2OptionSet) || (selectedTag == pgp6OptionSet) || (selectedTag == pgp7OptionSet));

    return selectedTag;
}

- (void) updateWarning
{
    [warningImageView setHidden:[[optionMatrix selectedCell] tag] != openPGPOptionSet || [pgp5Button state] == NSOffState];
}

- (void)willSelect
{
    unsigned	selectedTag;
    BOOL		pgp5Compatible;

    [super willSelect];
    selectedTag = [self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];

    NSAssert1([optionMatrix selectCellWithTag:selectedTag], @"Could't find cell with tag %d!!!", selectedTag);
    [pgp5Button setEnabled:(selectedTag != rfc1991OptionSet && selectedTag != pgp2OptionSet && selectedTag != pgp6OptionSet && selectedTag != pgp7OptionSet)];
    [pgp5Button setState:(pgp5Compatible || (selectedTag == rfc1991OptionSet) || (selectedTag == pgp2OptionSet) || (selectedTag == pgp6OptionSet) || (selectedTag == pgp7OptionSet))];
    [self updateWarning];
}

- (void)willUnselect
{
    [super willUnselect];
    
    [options release];
    options = nil;
}

- (IBAction) chooseOptionSet:(id)sender
{
    BOOL	pgp5Compatible;

    // Let's delete these entries
    [[self options] setOptionValue:nil forName:@"no-pgp2"];
    [[self options] setOptionValue:nil forName:@"no-pgp6"];
    [[self options] setOptionValue:nil forName:@"no-pgp7"];
    [[self options] setOptionValue:nil forName:@"no-pgp8"];
    // There are no 'no-*' variants for other options

    // Let's disable all options; we'll reenable only the matching one
    [[self options] setOptionState:NO forName:@"rfc1991"];
    [[self options] setOptionState:NO forName:@"pgp2"];
    [[self options] setOptionState:NO forName:@"pgp6"];
    [[self options] setOptionState:NO forName:@"pgp7"];
    [[self options] setOptionState:NO forName:@"pgp8"];
    [[self options] setOptionState:NO forName:@"gnupg"];
    [[self options] setOptionState:NO forName:@"openpgp"];
    [[self options] setOptionState:NO forName:@"rfc2440"];
    [[self options] setOptionState:NO forName:@"rfc4880"];

    [pgp5Button setEnabled:NO];
    [pgp5Button setState:YES];

    switch([[optionMatrix selectedCell] tag]){
        case rfc1991OptionSet:
            [[self options] setOptionState:YES forName:@"rfc1991"];
            break;
        case pgp2OptionSet:
            [[self options] setOptionState:YES forName:@"pgp2"]; // Implies rfc1991 though
            break;
        case pgp6OptionSet:
            [[self options] setOptionState:YES forName:@"pgp6"];
            break;
        case pgp7OptionSet:
            [[self options] setOptionState:YES forName:@"pgp7"];
            break;
        case pgp8OptionSet:
            [[self options] setOptionState:YES forName:@"pgp8"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        case openPGPOptionSet:
            [[self options] setOptionState:YES forName:@"openpgp"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        case rfc2440OptionSet:
            [[self options] setOptionState:YES forName:@"rfc2440"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        case rfc4880OptionSet:
            [[self options] setOptionState:YES forName:@"rfc4880"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        case gnupgOptionSet:
        default:
            [[self options] setOptionState:YES forName:@"gnupg"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
    }
    [self updateWarning];
    [[self options] saveOptions];
}

- (IBAction) togglePGP5Option:(id)sender
{
    BOOL	flag = [sender state];

    if(flag){
        // Let's be sure that option is after openpgp option:
        // we remove it first, then add it at the end
        [[self options] setOptionValue:nil forName:@"force-v3-sigs"];
    }
    [[self options] setOptionState:flag forName:@"force-v3-sigs"];
    [[self options] setOptionValue:nil forName:@"no-force-v3-sigs"];
    [[self options] saveOptions];
    [self updateWarning];
}

@end
