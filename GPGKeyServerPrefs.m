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


#import "GPGKeyServerPrefs.h"
#import "GPGOptions.h"
#import "GPGPreferences.h"


@implementation GPGKeyServerPrefs

#warning TODO: Suggest http proxy; we could also modify it when SystemPrefs modify it (sync)

- (void) refreshKeyServerList
{
    NSString	*filename = [[NSBundle bundleForClass:[self class]] pathForResource:@"KeyServers" ofType:@"plist"];
    NSArray		*additionalKeyServers = [[preferences userDefaultsDictionary] objectForKey:@"AdditionalKeyServers"];

    [keyServerList release];
    [keyServerCustomEntries removeAllObjects];
    keyServerList = [[NSArray alloc] initWithContentsOfFile:filename];
    NSAssert1(keyServerList != nil, @"Unable to read property list '%@'", filename);

    if(additionalKeyServers != nil){
        [keyServerCustomEntries setArray:additionalKeyServers];
        keyServerList = [[additionalKeyServers arrayByAddingObjectsFromArray:keyServerList] retain];
    }
}

- (id) initWithIdentifier:(NSString *)newIdentifier preferences:(GPGPreferences *)preferencesInstance
{
    if(self = [super initWithIdentifier:newIdentifier preferences:preferencesInstance]){
        keyServerOptions = [[NSMutableArray alloc] init];
        keyServerCustomEntries = [[NSMutableArray alloc] init];
        [self refreshKeyServerList];
    }

    return self;
}

- (void) dealloc
{
    [warningView release];
    [keyServerList release];
    [keyServerOptions release];
    [keyServerCustomEntries release];

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
    NSString	*aString;
    
    [super tabItemWillBeSelected];

    [isHttpProxyHonoredButton setState:[[self options] subOptionState:@"honor-http-proxy" forName:@"keyserver-options"]];
    
    aString = [GPGOptions httpProxy];
    if(aString == nil)
        [httpProxyTextField setStringValue:@""];
    else
        [httpProxyTextField setStringValue:aString];

    [isAutomaticKeyRetrievingEnabledButton setState:[[self options] subOptionState:@"auto-key-retrieve" forName:@"keyserver-options"]];
    [includeRevokedButton setState:[[self options] subOptionState:@"include-revoked" forName:@"keyserver-options"]];
    [includeDisabledButton setState:[[self options] subOptionState:@"include-disabled" forName:@"keyserver-options"]];
    [includeSubkeysButton setState:[[self options] subOptionState:@"include-subkeys" forName:@"keyserver-options"]];

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

    // There is no way to remove an entry...
    if([newKeyServer rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0){
        [[self options] setOptionState:YES forName:@"keyserver"];
        if(![keyServerList containsObject:newKeyServer]){
            if(![keyServerCustomEntries containsObject:newKeyServer]){
                [keyServerCustomEntries addObject:newKeyServer];
                [[preferences userDefaultsDictionary] setObject:keyServerCustomEntries forKey:@"AdditionalKeyServers"];
                [preferences saveUserDefaults];
                [self refreshKeyServerList];
            }
        }
        [[self options] setOptionValue:newKeyServer forName:@"keyserver"];
    }
    else{
        [[self options] setOptionState:NO forName:@"keyserver"];
    }
    [[self options] saveOptions];
    [keyServerListComboBox reloadData];
}

- (void) setKeyServerOption:(NSString *)option toState:(BOOL)flag
{
    [[self options] setSubOption:option state:flag forName:@"keyserver-options"];
    [[self options] saveOptions];
}

- (IBAction) toggleAutomaticKeyRetrieval:(id)sender
{
    [self setKeyServerOption:@"auto-key-retrieve" toState:[isAutomaticKeyRetrievingEnabledButton state]];
}

- (IBAction) toggleHttpProxyUse:(id)sender
{
    [self setKeyServerOption:@"honor-http-proxy" toState:[isHttpProxyHonoredButton state]];
}

- (IBAction) toggleIncludeRevoked:(id)sender
{
    [self setKeyServerOption:@"include-revoked" toState:[includeRevokedButton state]];
}

- (IBAction) toggleIncludeDisabled:(id)sender
{
    [self setKeyServerOption:@"include-disabled" toState:[includeDisabledButton state]];
}

- (IBAction) toggleIncludeSubkeys:(id)sender
{
    [self setKeyServerOption:@"include-subkeys" toState:[includeSubkeysButton state]];
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
