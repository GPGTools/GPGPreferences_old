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


#import "GPGKeyServerPrefs.h"
#import "GPGOptions.h"


@implementation GPGKeyServerPrefs

#warning TODO: Suggest http proxy; we could also modify it when SystemPrefs modify it (sync)
#warning TODO: add support for include-revoked and include-disabled
- (id) initWithIdentifier:(NSString *)newIdentifier preferences:(GPGPreferences *)preferencesInstance
{
    if(self = [super initWithIdentifier:newIdentifier preferences:preferencesInstance]){
        NSString	*filename = [[NSBundle bundleForClass:[self class]] pathForResource:@"KeyServers" ofType:@"plist"];

        keyServerList = [[NSArray alloc] initWithContentsOfFile:filename];
        NSAssert1(keyServerList != nil, @"Unable to read property list '%@'", filename);
        keyServerOptions = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void) dealloc
{
    [warningView release];
    [keyServerList release];
    [keyServerOptions release];

    [super dealloc];
}

- (void) updateWarningView
{
    if([GPGOptions httpProxyChanged]){
        if([warningView superview] == nil)
            [warningPlaceholder addSubview:warningView];
    }
    else if([warningView superview] != nil)
        [warningView removeFromSuperview];
}

- (void) tabItemWillBeSelected
{
    NSString		*aString;
    NSString		*keyServerOptionsString = [[self options] optionValueForName:@"keyserver-options"];
    NSArray			*optionParameters = [keyServerOptionsString componentsSeparatedByString:@","];
    NSEnumerator	*anEnum = [optionParameters objectEnumerator];
    int				setIndex, unsetIndex;
    
    [super tabItemWillBeSelected];

    [keyServerOptions removeAllObjects];
    while(aString = [anEnum nextObject])
        [keyServerOptions addObjectsFromArray:[aString componentsSeparatedByString:@" "]];
    [keyServerOptions removeObject:@""];
    optionParameters = [[keyServerOptions reverseObjectEnumerator] allObjects]; // Reversed array

    setIndex = [optionParameters indexOfObject:@"honor-http-proxy"];
    unsetIndex = [optionParameters indexOfObject:@"no-honor-http-proxy"];
    [isHttpProxyHonoredButton setState:(setIndex < unsetIndex)];
    
    aString = [GPGOptions httpProxy];
    if(aString == nil)
        [httpProxyTextField setStringValue:@""];
    else
        [httpProxyTextField setStringValue:aString];

    setIndex = [optionParameters indexOfObject:@"auto-key-retrieve"];
    unsetIndex = [optionParameters indexOfObject:@"no-auto-key-retrieve"];
    [isAutomaticKeyRetrievingEnabledButton setState:(setIndex < unsetIndex)];

    aString = [[self options] optionValueForName:@"keyserver"];
    [keyServerListComboBox reloadData];
    if(aString == nil)
        [keyServerListComboBox setStringValue:@""];
    else
        [keyServerListComboBox setStringValue:aString];

    [self updateWarningView];
}

- (IBAction) changeHttpProxy:(id)sender
{
    [GPGOptions setHttpProxy:[httpProxyTextField stringValue]];
    [self updateWarningView];
}

- (IBAction) changeKeyServer:(id)sender
{
    NSString	*newKeyServer = [keyServerListComboBox stringValue];

    if([newKeyServer rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0){
        [[self options] setOptionState:YES forName:@"keyserver"];
        [[self options] setOptionValue:newKeyServer forName:@"keyserver"];
    }
    else
        [[self options] setOptionState:NO forName:@"keyserver"];
    [[self options] saveOptions];
}

- (IBAction) toggleAutomaticKeyRetrieval:(id)sender
{
    [keyServerOptions removeObject:@"no-auto-key-retrieve"];
    [keyServerOptions removeObject:@"auto-key-retrieve"];
    [keyServerOptions addObject:([isAutomaticKeyRetrievingEnabledButton state] ? @"auto-key-retrieve":@"no-auto-key-retrieve")];
    [[self options] setOptionValue:[keyServerOptions componentsJoinedByString:@","] forName:@"keyserver-options"];
    [[self options] saveOptions];
}

- (IBAction) toggleHttpProxyUse:(id)sender
{
    [keyServerOptions removeObject:@"no-honor-http-proxy"];
    [keyServerOptions removeObject:@"honor-http-proxy"];
    [keyServerOptions addObject:([isHttpProxyHonoredButton state] ? @"honor-http-proxy":@"no-honor-http-proxy")];
    [[self options] setOptionValue:[keyServerOptions componentsJoinedByString:@","] forName:@"keyserver-options"];
    [[self options] saveOptions];
}

- (int) numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return [keyServerList count];
}

- (id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
    return [keyServerList objectAtIndex:index];
}

- (unsigned int) comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string
{
    return [keyServerList indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string
{
    NSEnumerator	*anEnum = [keyServerList objectEnumerator];
    NSString		*aKeyServer;

    while(aKeyServer = [anEnum nextObject])
        if([aKeyServer hasPrefix:string])
            return aKeyServer;
    
    return string;
}

@end
