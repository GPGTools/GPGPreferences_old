//
//  GPGPrefController.m
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

#import "GPGPrefController.h"
#import "GPGOptions.h"


@implementation GPGPrefController

+ (id) controllerWithIdentifier:(NSString *)newIdentifier
{
    return [[[self alloc] initWithIdentifier:newIdentifier] autorelease];
}

- (id) initWithIdentifier:(NSString *)newIdentifier
{
    if(self = [self init]){
        identifier = [newIdentifier copy];
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
