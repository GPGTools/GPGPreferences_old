//
//  GPGCompatibilityPrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Thu Feb 07 2002.
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


#import "GPGCompatibilityPrefs.h"
#import "GPGOptions.h"


enum {
    rfc1991OptionSet = 0,
    pgp2OptionSet,
    pgp6OptionSet,
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
    unsigned	selectedRow = customOptionSet;
    int			i;
    BOOL		pgp5Compatible = NO;

    optionNames = [[self options] optionNames];
    optionStates = [[self options] optionStates];

    for(i = [optionNames count] - 1; i >= 0; i--){
        NSString	*aName = [optionNames objectAtIndex:i];

        if([[optionStates objectAtIndex:i] boolValue] && selectedRow == customOptionSet){
            if([aName isEqualToString:@"rfc1991"])
                selectedRow = rfc1991OptionSet;
            else if([aName isEqualToString:@"pgp2"])
                selectedRow = pgp2OptionSet;
            else if([aName isEqualToString:@"pgp6"])
                selectedRow = pgp6OptionSet;
            else if([aName isEqualToString:@"openpgp"])
                selectedRow = openPGPOptionSet;
            else if([aName isEqualToString:@"force-v3-sigs"])
                pgp5Compatible = YES;
        }
    }

    *pgp5CompatiblePtr = (pgp5Compatible || (selectedRow == rfc1991OptionSet) || (selectedRow == pgp2OptionSet) || (selectedRow == pgp6OptionSet));

    return selectedRow;
}

- (void) updateWarning
{
    if([optionMatrix selectedRow] == openPGPOptionSet && [pgp5Button state]){
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
    unsigned	selectedRow;
    BOOL		pgp5Compatible;

    [super tabItemWillBeSelected];
    selectedRow = [self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];

    [optionMatrix selectCellAtRow:selectedRow column:0];
    [pgp5Button setEnabled:(selectedRow != rfc1991OptionSet && selectedRow != pgp2OptionSet && selectedRow != pgp6OptionSet)];
    [pgp5Button setState:(pgp5Compatible || (selectedRow == rfc1991OptionSet) || (selectedRow == pgp2OptionSet) || (selectedRow == pgp6OptionSet))];
    [self updateWarning];
}

- (IBAction) chooseOptionSet:(id)sender
{
    BOOL	pgp5Compatible;

    switch([optionMatrix selectedRow]){
        case rfc1991OptionSet:
            [[self options] setOptionState:YES forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case pgp2OptionSet:
            [[self options] setOptionState:YES forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case pgp6OptionSet:
            [[self options] setOptionState:YES forName:@"pgp6"];
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"openpgp"];
            [pgp5Button setEnabled:NO];
            [pgp5Button setState:YES];
            break;
        case openPGPOptionSet:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
            [[self options] setOptionState:YES forName:@"openpgp"];
            [pgp5Button setEnabled:YES];
            (void)[self selectedOptionSetAndPGP5Compatibility:&pgp5Compatible];
            [pgp5Button setState:pgp5Compatible];
            break;
        default:
            [[self options] setOptionState:NO forName:@"rfc1991"];
            [[self options] setOptionState:NO forName:@"pgp2"];
            [[self options] setOptionState:NO forName:@"pgp6"];
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

    if(flag)
        // Let's be sure that option is after openpgp option:
        // we remove it first, then add it at the end
        [[self options] setOptionValue:nil forName:@"force-v3-sigs"];
    [[self options] setOptionState:flag forName:@"force-v3-sigs"];
    [[self options] saveOptions];
    [self updateWarning];
}

@end
