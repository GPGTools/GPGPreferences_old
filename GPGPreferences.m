//
//  GPGPreferences.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sun Feb 03 2002.
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

#import "GPGPreferences.h"
#import "GPGPrefController.h"
#import "GPGExpertPrefs.h"
#import "GPGGlobalPrefs.h"
#import "GPGOptions.h"
#import "GPGCompatibilityPrefs.h"
#import "GPGKeyServerPrefs.h"


@implementation GPGPreferences

#warning TODO: Create image for bundle, check tiff premultiplied

- (id) initWithBundle:(NSBundle *)bundle
{
    if(self = [super initWithBundle:bundle]){
        tabViewItemControllers = [[NSArray allocWithZone:[self zone]] initWithObjects:[GPGGlobalPrefs controllerWithIdentifier:@"GPGGlobalPrefs"], [GPGKeyServerPrefs controllerWithIdentifier:@"GPGKeyServerPrefs"], [GPGCompatibilityPrefs controllerWithIdentifier:@"GPGCompatibilityPrefs"], [GPGExpertPrefs controllerWithIdentifier:@"GPGExpertPrefs"], nil];
    }

    return self;
}

- (void) dealloc
{
    [tabViewItemControllers release];
    
    [super dealloc];
}

- (void) mainViewDidLoad
{
    NSEnumerator		*anEnum;
    GPGPrefController	*aController;
    int					i;

    [super mainViewDidLoad];

    i = [tabView numberOfTabViewItems] - 1;
    for(; i >= 0; i--)
        [tabView removeTabViewItem:[tabView tabViewItemAtIndex:i]];
    
    anEnum = [tabViewItemControllers objectEnumerator];
    while(aController = [anEnum nextObject])
        [tabView addTabViewItem:[aController tabViewItem]];

    [versionTextField setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"VERSION %@", nil, [self bundle], ""), [[[self bundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
}

- (GPGPrefController *) controllerForIdentifier:(NSString *)identifier
{
    NSEnumerator		*anEnum = [tabViewItemControllers objectEnumerator];
    GPGPrefController	*aController;

    while(aController = [anEnum nextObject])
        if([NSStringFromClass([aController class]) isEqualToString:identifier])
            return aController;

    [NSException raise:NSInternalInconsistencyException format:@"Unable to find controller for identifier '%@' (not a class name?!)", identifier];
    return nil; // Never reached; just to avoid compiler warning
}

- (void) willSelect
{
    [super willSelect];
    [[self controllerForIdentifier:[[tabView selectedTabViewItem] identifier]] tabItemWillBeSelected];
}

- (void) willUnselect
{
    [super willUnselect];
    [[self controllerForIdentifier:[[tabView selectedTabViewItem] identifier]] tabItemWillBeDeselected];
}

- (void) tabView:(NSTabView *)theTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSTabViewItem	*selectedTabViewItem = [tabView selectedTabViewItem];

    if(selectedTabViewItem != nil)
        [[self controllerForIdentifier:[selectedTabViewItem identifier]] tabItemWillBeDeselected];
    [[self controllerForIdentifier:[tabViewItem identifier]] tabItemWillBeSelected];
}

@end
