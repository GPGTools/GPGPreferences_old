//
//  GPGPrefController.m
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

#import "GPGPrefController.h"
#import "GPGOptions.h"
#import "GPGPreferences.h"


@implementation GPGPrefController

+ (id) controllerWithIdentifier:(NSString *)newIdentifier preferences:(GPGPreferences *)preferencesInstance
{
    return [[[self alloc] initWithIdentifier:newIdentifier preferences:preferencesInstance] autorelease];
}

- (id) initWithIdentifier:(NSString *)newIdentifier preferences:(GPGPreferences *)preferencesInstance
{
    if(self = [self init]){
        identifier = [newIdentifier copy];
        preferences = preferencesInstance; // Do not retain it to avoid retain-cycle
    }

    return self;
}

- (void) dealloc
{
    [identifier release];
    [view release];
    [tabViewItem release];
    [options release];
    
    [super dealloc];
}

- (GPGOptions *) options
{
    if(options == nil)
        options = [[GPGOptions alloc] init];

    return options;
}

- (NSString *) tabViewItemIdentifier
{
    return identifier;
}

- (void) awakeFromNib
{
    [[self tabViewItem] setView:view];
    [[self tabViewItem] setInitialFirstResponder:initialFirstResponder];
}

- (NSTabViewItem *) tabViewItem
{
    if(tabViewItem == nil){
        NSString	*tabViewItemIdentifier = [self tabViewItemIdentifier];
        
        tabViewItem = [[NSTabViewItem alloc] initWithIdentifier:tabViewItemIdentifier];
        [tabViewItem setLabel:NSLocalizedStringFromTableInBundle(tabViewItemIdentifier, nil, [NSBundle bundleForClass:[self class]], "")];
    }
    
    return tabViewItem;
}

- (NSString *) nibName
{
    return NSStringFromClass([self class]);
}

- (void) tabItemWillBeSelected
{
    if(view == nil)
        NSAssert1([NSBundle loadNibNamed:[self nibName] owner:self], @"Unable to load nib named '%@'", [self nibName]);
}

- (void) tabItemWillBeDeselected
{
    [options release];
    options = nil;
}

@end
