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
//  More info at <http://macgpg.sourceforge.net/> or <macgpg@rbisland.cx>
//


#import "GPGCompatibilityPrefs.h"
#import "GPGOptions.h"


enum {
    rfc1991OptionSet = 0,
    pgp2OptionSet,
    pgp6OptionSet,
    pgp7OptionSet,
    openPGPOptionSet,
    customOptionSet
};


@implementation GPGCompatibilityPrefs

- (void) awakeFromNib
{
    [super awakeFromNib];
    warningImage = [[warningImageView image] retain];
}

- (void) dealloc
{
    [warningImage release];

    [super dealloc];
}

- (int) selectedOptionSetAndPGP5Compatibility:(BOOL *)pgp5CompatiblePtr
{
    NSArray		*optionNames;
    NSArray		*optionStates;
    unsigned	selectedTag = customOptionSet;
    unsigned	previousSelectedTag = selectedTag;
    int			i;
    BOOL		pgp5Compatible = NO;

    optionNames = [[self options] optionNames];
    optionStates = [[self options] optionStates];

    for(i = [optionNames count] - 1; i >= 0; i--){
        NSString	*aName = [optionNames objectAtIndex:i];

        if([[optionStates objectAtIndex:i] boolValue] && selectedTag == customOptionSet){
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
            else if([aName isEqualToString:@"openpgp"]){
                previousSelectedTag = selectedTag;
                selectedTag = openPGPOptionSet;
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
    if([[optionMatrix selectedCell] tag] == openPGPOptionSet && [pgp5Button state]){
        if([warningImageView image] == nil)
            [warningImageView setImage:warningImage];
    }
    else{
        if([warningImageView image] != nil)
            [warningImageView setImage:nil];
    }
}

- (void) tabItemWillBeSelected
{
    unsigned	selectedTag;
    BOOL		pgp5Compatible;

    [super tabItemWillBeSelected];
    selectedTag = [self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];

    NSAssert1([optionMatrix selectCellWithTag:selectedTag], @"Could't find cell with tag %d!!!", selectedTag);
    [pgp5Button setEnabled:(selectedTag != rfc1991OptionSet && selectedTag != pgp2OptionSet && selectedTag != pgp6OptionSet && selectedTag != pgp7OptionSet)];
    [pgp5Button setState:(pgp5Compatible || (selectedTag == rfc1991OptionSet) || (selectedTag == pgp2OptionSet) || (selectedTag == pgp6OptionSet) || (selectedTag == pgp7OptionSet))];
    [self updateWarning];
}

- (IBAction) chooseOptionSet:(id)sender
{
    BOOL	pgp5Compatible;

    // Let's delete these entries
    [[self options] setOptionValue:nil forName:@"no-pgp2"];
    [[self options] setOptionValue:nil forName:@"no-pgp6"];
    [[self options] setOptionValue:nil forName:@"no-pgp7"];

    switch([[optionMatrix selectedCell] tag]){
        case rfc1991OptionSet:
            [[self options] setOptionState:YES forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"pgp7"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case pgp2OptionSet:
            [[self options] setOptionState:NO forName:@"rfc1991"]; // Implies rfc1991 though
            [[self options] setOptionState:YES forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"pgp7"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case pgp6OptionSet:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:YES forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"pgp7"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case pgp7OptionSet:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:YES forName:@"pgp7"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case openPGPOptionSet:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"pgp7"];
            [[self options] setOptionState:YES forName:@"openpgp"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        default:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"pgp7"];
            [[self options] setOptionState:NO forName:@"openpgp"];
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
