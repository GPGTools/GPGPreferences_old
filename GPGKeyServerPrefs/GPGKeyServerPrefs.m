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


#import "GPGKeyServerPrefs.h"
#import <MacGPGME/MacGPGME.h>


@interface GPGKeyServerPrefs(Private)
- (void) comboBoxSelectionDidChange:(NSNotification *)notification;
@end

@implementation GPGKeyServerPrefs

// TODO: Suggest http proxy; we could also modify it when SystemPrefs modify it (sync)

- (GPGOptions *)options
{
    if(options == nil)
        options = [[GPGOptions alloc] init];
    
    return options;
}

- (void)refreshKeyServerList
{
    NSString	*filename = [[self bundle] pathForResource:@"KeyServers" ofType:@"plist"];
    NSArray		*additionalKeyServers = [[self options] allOptionValuesForName:@"keyserver"];

    [keyServerList release];
    [keyServerCustomEntries removeAllObjects];
    keyServerList = [[NSArray alloc] initWithContentsOfFile:filename];
    NSAssert1(keyServerList != nil, @"Unable to read property list '%@'", filename);

    if(additionalKeyServers != nil){
        NSEnumerator	*anEnum = [additionalKeyServers objectEnumerator];
        NSString		*aName;

        while(aName = [anEnum nextObject])
            if(![keyServerList containsObject:aName] && ![keyServerCustomEntries containsObject:aName])
                [keyServerCustomEntries addObject:aName];
        keyServerList = [[keyServerCustomEntries arrayByAddingObjectsFromArray:keyServerList] retain];
    }
}

- (id)initWithBundle:(NSBundle *)bundle
{
    if(self = [super initWithBundle:bundle]){
        keyServerOptions = [[NSMutableArray alloc] init];
        keyServerCustomEntries = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)dealloc
{
    [keyServerList release];
    [keyServerOptions release];
    [keyServerCustomEntries release];
    [options release];

    [super dealloc];
}

- (void)willSelect
{
    NSString	*aString;
    
    [super willSelect];

    aString = [[self options] subOptionValue:@"http-proxy" state:NULL forName:@"keyserver-options"];
    if(aString)
        [httpProxyTextField setStringValue:aString];
    else{
        NSString    *defaultValue = [[[NSProcessInfo processInfo] environment] objectForKey:@"http_proxy"];
        
        [httpProxyTextField setStringValue:@""];
        if(defaultValue != nil && [defaultValue length] > 0)
            [[httpProxyTextField cell] setPlaceholderString:defaultValue];
        else
            [[httpProxyTextField cell] setPlaceholderString:@""];
    }

    [isAutomaticKeyRetrievingEnabledButton setState:[[self options] subOptionState:@"auto-key-retrieve" forName:@"keyserver-options"]];
    [includeRevokedButton setState:[[self options] subOptionState:@"include-revoked" forName:@"keyserver-options"]];
    [includeDisabledButton setState:[[self options] subOptionState:@"include-disabled" forName:@"keyserver-options"]];
    [includeSubkeysButton setState:[[self options] subOptionState:@"include-subkeys" forName:@"keyserver-options"]];
    aString = [[self options] subOptionValue:@"timeout" state:NULL forName:@"keyserver-options"];
    if(aString)
        [timeoutTextField setStringValue:aString];
    else
        [timeoutTextField setStringValue:@""];

    [self refreshKeyServerList];
    if(![[self options] optionStateForName:@"keyserver"])
        [keyServerListComboBox setStringValue:@""];
    else{
        aString = [[self options] optionValueForName:@"keyserver"];
        [keyServerListComboBox setStringValue:aString];
    }
    [keyServerListComboBox reloadData];

    [self comboBoxSelectionDidChange:nil];
}

- (IBAction)changeHttpProxy:(id)sender
{
    NSString    *httpProxy = [sender stringValue];
    
    if(httpProxy != nil && [httpProxy length] == 0)
        httpProxy = nil;
    [[self options] setSubOption:@"http-proxy" value:httpProxy state:(httpProxy != nil) forName:@"keyserver-options"];
    [[self options] saveOptions];
}

- (IBAction)changeKeyServer:(id)sender
{
    NSString		*newKeyServer = [keyServerListComboBox stringValue];
    BOOL			isValidName = ([newKeyServer rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0);
    NSEnumerator	*anEnum = [[[self options] optionNames] objectEnumerator];
    NSString		*aName;
    BOOL			foundOne = !isValidName;
    int				anIndex = 0;
    NSArray			*optionValues = [[self options] optionValues];
    
    while(aName = [anEnum nextObject]){
        if([aName isEqualToString:@"keyserver"]){
            BOOL	isSameServer = [[optionValues objectAtIndex:anIndex] isEqualToString:newKeyServer];
            
            [[self options] setOptionState:(!foundOne && isSameServer) atIndex:anIndex];
            if(isSameServer)
                foundOne = YES; // Only one can be active
        }
        anIndex++;
    }
    
    if(!foundOne && isValidName){
        [[self options] addOptionNamed:@"keyserver"];
        anIndex = [optionValues count] - 1;
        [[self options] setOptionState:YES atIndex:anIndex];
        [[self options] setOptionValue:newKeyServer atIndex:anIndex];
    }
    [[self options] saveOptions];
    [self refreshKeyServerList];
    [keyServerListComboBox reloadData];
    [self comboBoxSelectionDidChange:nil];
}

- (IBAction)removeServerFromList:(id)sender
{
    NSString		*oldSelectedKeyServer = [keyServerListComboBox stringValue];
    NSString		*newSelectedKeyServer;
    NSEnumerator	*anEnum = [[NSArray arrayWithArray:[[self options] optionNames]] objectEnumerator];
    NSString		*aName;
    BOOL			foundOne = NO;
    int				anIndex = 0;
    NSArray			*optionValues = [[self options] optionValues];
    int				aCount;
    int				deletedCount = 0;
    int				oldSelectedKeyServerIndex = [keyServerList indexOfObject:oldSelectedKeyServer];

    aCount = [keyServerList count];
    if(oldSelectedKeyServerIndex == aCount - 1)
        oldSelectedKeyServerIndex = aCount - 2;
    else
        oldSelectedKeyServerIndex++;
    if(oldSelectedKeyServerIndex < 0){
        [keyServerListComboBox setStringValue:@""];
        newSelectedKeyServer = nil;
    }
    else{
        newSelectedKeyServer = [keyServerList objectAtIndex:oldSelectedKeyServerIndex];
        [keyServerListComboBox setStringValue:newSelectedKeyServer];
    }

    while(aName = [anEnum nextObject]){
        if([aName isEqualToString:@"keyserver"]){
            NSString	*aValue = [optionValues objectAtIndex:anIndex - deletedCount];
            
            if([aValue isEqualToString:oldSelectedKeyServer]){
                [[self options] removeOptionAtIndex:anIndex - deletedCount];
                deletedCount++;
            }
            if(!foundOne && newSelectedKeyServer && [aValue isEqualToString:newSelectedKeyServer]){
                [[self options] setOptionState:YES atIndex:anIndex - deletedCount];
                foundOne = YES;
            }
        }
        anIndex++;
    }
    if(!foundOne)
        [self changeKeyServer:nil];
    else{
        [[self options] saveOptions];
        [self refreshKeyServerList];
        [keyServerListComboBox reloadData];
    }
    [self comboBoxSelectionDidChange:nil];
}

- (void)setKeyServerOption:(NSString *)option toState:(BOOL)flag
{
    [[self options] setSubOption:option state:flag forName:@"keyserver-options"];
    [[self options] saveOptions];
}

- (IBAction)toggleAutomaticKeyRetrieval:(id)sender
{
    [self setKeyServerOption:@"auto-key-retrieve" toState:[isAutomaticKeyRetrievingEnabledButton state]];
}

- (IBAction)toggleIncludeRevoked:(id)sender
{
    [self setKeyServerOption:@"include-revoked" toState:[includeRevokedButton state]];
}

- (IBAction)toggleIncludeDisabled:(id)sender
{
    [self setKeyServerOption:@"include-disabled" toState:[includeDisabledButton state]];
}

- (IBAction)toggleIncludeSubkeys:(id)sender
{
    [self setKeyServerOption:@"include-subkeys" toState:[includeSubkeysButton state]];
}

- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return [keyServerList count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
    return [keyServerList objectAtIndex:index];
}

- (unsigned int)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string
{
    return [keyServerList indexOfObject:string];
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string
{
    NSEnumerator	*anEnum = [keyServerList objectEnumerator];
    NSString		*aKeyServer;

    while(aKeyServer = [anEnum nextObject])
        if([aKeyServer hasPrefix:string])
            return aKeyServer;
    
    return string;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    [removeServerButton setEnabled:[keyServerCustomEntries containsObject:[keyServerListComboBox stringValue]]];
}

- (void)willUnselect
{
    [super willUnselect];

    [self changeKeyServer:nil];
    [options release];
    options = nil;
}

- (IBAction)changeTimeout:(id)sender
{
    NSString    *timeout = [sender stringValue];
    
    [[self options] setSubOption:@"timeout" value:timeout state:(timeout != nil) forName:@"keyserver-options"];
    [[self options] saveOptions];
}

@end
