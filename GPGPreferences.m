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
#import "authinfo.h"
#import <Carbon/Carbon.h>


#define TERMINAL_UTF8_STRING_ENCODING	(4)
#define TERMINAL_DOMAIN_NAME			@"com.apple.Terminal"
#define TERMINAL_STRING_ENCODING_KEY	@"StringEncoding"


OSStatus GPGPreferences_ExecuteAdminCommand(const char *rightName, int authorizedCommandOperation, const char *fileArgument, CFBundleRef bundle); // Implemented in authapp.c

@interface GPGPreferences(Private)
- (void) startTests;
- (void) nextTest;
@end

@implementation GPGPreferences

#warning TODO: Create image for bundle, check tiff premultiplied

- (id) initWithBundle:(NSBundle *)bundle
{
    if(self = [super initWithBundle:bundle]){
        tabViewItemControllers = [[NSArray allocWithZone:[self zone]] initWithObjects:[GPGGlobalPrefs controllerWithIdentifier:@"GPGGlobalPrefs" preferences:self], [GPGKeyServerPrefs controllerWithIdentifier:@"GPGKeyServerPrefs" preferences:self], [GPGCompatibilityPrefs controllerWithIdentifier:@"GPGCompatibilityPrefs" preferences:self], [GPGExpertPrefs controllerWithIdentifier:@"GPGExpertPrefs" preferences:self], nil];
    }

    return self;
}

- (void) dealloc
{
    [tabViewItemControllers release];
    [userDefaultsDictionary release];
    [testSelectors release];
    [[operationMatrix superview] release];
    
    [super dealloc];
}

- (NSMutableDictionary *) userDefaultsDictionary
{
    if(userDefaultsDictionary == nil){
        NSString	*domainName = [[self bundle] bundleIdentifier];
        
        userDefaultsDictionary = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] persistentDomainForName:domainName]];
    }
    
    return userDefaultsDictionary;
}

- (void) saveUserDefaults
{
    if(userDefaultsDictionary != nil){
        NSString	*domainName = [[self bundle] bundleIdentifier];

        [[NSUserDefaults standardUserDefaults] setPersistentDomain:userDefaultsDictionary forName:domainName];
        [userDefaultsDictionary release];
        userDefaultsDictionary = nil;
    }
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
    
    [self performSelector:@selector(startTests) withObject:nil afterDelay:0.0];
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

- (void) checkGPGHasBaseFiles
{
    // Check if .gnupg/options exists, i.e. if gpg has already been run.
    // If it has never been used, run it to create the .gnupg directory, this way gpg is ready for use.
    // Note that we run it twice: the first time gpg creates the .gnupg/options file,
    // the second time it creates the keyrings.
    // (This should be done by EasyGnuPG installer)
    if(![[NSFileManager defaultManager] fileExistsAtPath:[[GPGOptions homeDirectory] stringByAppendingPathComponent:@"options"]]){
        int	i;
        
        for(i = 0; i < 2; i++){
            NSTask	*aTask = [[NSTask alloc] init];
        
            [aTask setLaunchPath:[GPGOptions gpgPath]];
            [aTask setArguments:[NSArray arrayWithObjects:@"--no-tty", @"--list-keys", nil]];
            [aTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            
            NS_DURING
                [aTask launch];
                [aTask waitUntilExit];
            NS_HANDLER
            NS_ENDHANDLER
        
            [aTask release];
        }
    }
    [self nextTest];
}

- (void) charsetSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString	*lastCharset = (NSString *)contextInfo;
    
    if(returnCode == NSOKButton){
        GPGOptions	*options = [[GPGOptions alloc] init];
        
        [options setOptionValue:@"utf8" forName:@"charset"];
        [options setOptionState:YES forName:@"charset"];
        [options setOptionValue:nil forName:@"no-utf8-strings"];
        [options setOptionState:YES forName:@"utf8-strings"];
        [options saveOptions];
        [options release];
        [[self userDefaultsDictionary] setObject:@"utf8" forKey:@"LastCharset"];
    }
    else
        [[self userDefaultsDictionary] setObject:lastCharset forKey:@"LastCharset"];

	// We won't bother user asking her once again, unless she changed charset to something else
	[self saveUserDefaults];
    [lastCharset release];
    [self nextTest];
}

- (void) checkCharsetIsUTF8
{
    // Check that --charset utf8 is set, and that --utf8-strings is set.
    // We ask only if first time, or if user already did it but modified it.
    GPGOptions	*options = [[GPGOptions alloc] init];
    NSString	*charset = [options optionValueForName:@"charset"];
    BOOL		shouldChange;
    NSString	*lastCharset = @"";
    
    shouldChange = (charset == nil || ![options optionStateForName:@"charset"]);
	shouldChange = shouldChange || (![charset isEqualToString:@"utf8"] && ![charset isEqualToString:@"utf-8"]);
    shouldChange = shouldChange || ![options optionStateForName:@"utf8-strings"];
    shouldChange = shouldChange || [options optionStateForName:@"no-utf8-strings"];
    
    if(shouldChange){
        lastCharset = [[self userDefaultsDictionary] objectForKey:@"LastCharset"];
        if(lastCharset == nil){
            lastCharset = @"";
            shouldChange = YES;
        }
        else
            shouldChange = ![lastCharset isEqualToString:@""] && ![charset isEqualToString:lastCharset];
    }
    else
        lastCharset = @"";
    
    if(shouldChange){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"CHANGE CHARSET TO UTF-8?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"PLEASE DO", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(charsetSheetDidDismiss:returnCode:contextInfo:), [lastCharset retain], @"%@", NSLocalizedStringFromTableInBundle(@"WHY CHANGING CHARSET...", nil, bundle, ""));
    }
    else
        [self nextTest];
    [options release];
}

- (void) checkGNUPGHOMERights
{
    // Set rights on --homeDirectory (0700) (+ other files?)
    [self nextTest];
}

- (void) checkGNUPGHOMESuggestion
{
    // Suggest to use ~/Library/GnuPG as homeDirectory (ask only once)
    // Not sure that it is a good idea...
    // Maybe it's better if user can't easily manipulate gpg files
    // like keyrings, trustdb; no risk that she breaks something.
    [self nextTest];
}

- (void) terminalStringEncodingSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSNumber	*terminalStringEncodingNumber = (NSNumber *)contextInfo;
    
    if(returnCode == NSOKButton){
        NSUserDefaults		*standardUserDefaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary	*newUserDefaults = [NSMutableDictionary dictionaryWithDictionary:[standardUserDefaults persistentDomainForName:TERMINAL_DOMAIN_NAME]];
        NSNumber			*newValue = [NSNumber numberWithUnsignedInt:TERMINAL_UTF8_STRING_ENCODING];
        
        [newUserDefaults setObject:newValue forKey:TERMINAL_STRING_ENCODING_KEY];
        [standardUserDefaults setPersistentDomain:newUserDefaults forName:TERMINAL_DOMAIN_NAME];
        [standardUserDefaults synchronize];
        [[self userDefaultsDictionary] setObject:newValue forKey:@"LastTerminalStringEncoding"];
    }
    else
        [[self userDefaultsDictionary] setObject:terminalStringEncodingNumber forKey:@"LastTerminalStringEncoding"];

	// We won't bother user asking her once again, unless she changed encoding to something else
	[self saveUserDefaults];
    [terminalStringEncodingNumber release];
    [self nextTest];
}

- (void) sheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [self nextTest];
}

- (void) checkTerminalStringEncoding
{
    // Check that Terminal uses UTF8, else suggest change 
    // If Terminal is running, user should do it manually,
    // else we can safely modify Terminal prefs: com.apple.Terminal StringEncoding 4
    // We ask only if first time, or if user already did it but modified it
    NSNumber			*terminalStringEncodingNumber = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:TERMINAL_DOMAIN_NAME] objectForKey:TERMINAL_STRING_ENCODING_KEY];
    int					terminalStringEncoding = -1;
    NSNumber			*lastTerminalStringEncodingNumber = [[self userDefaultsDictionary] objectForKey:@"LastTerminalStringEncoding"];
    int					lastTerminalStringEncoding = -1;
    
    if(terminalStringEncodingNumber != nil)
        terminalStringEncoding = [terminalStringEncodingNumber intValue];
    if(lastTerminalStringEncodingNumber != nil)
        lastTerminalStringEncoding = [lastTerminalStringEncodingNumber intValue];
    
    if(lastTerminalStringEncoding != terminalStringEncoding){
        if(terminalStringEncoding != TERMINAL_UTF8_STRING_ENCODING){
            NSBundle			*bundle = [self bundle];
            ProcessSerialNumber	psn = {kNoProcess, kNoProcess};
            ProcessInfoRec		info;
            OSStatus			outStatus = noErr;
            char				processName[32];
            
            info.processInfoLength = sizeof(ProcessInfoRec);
            info.processName = processName;
            info.processAppSpec = NULL;
            while(outStatus == noErr){
                outStatus = GetNextProcess(&psn);
                if(outStatus == noErr){                    
                    outStatus = GetProcessInformation(&psn, &info);
                    if(outStatus == noErr)
                        // info.processName is a Pascal string; first byte is length
                        if(memcmp(info.processName, "\010Terminal", 9) == 0)
                            break;
                }
            }
            
            if(outStatus == noErr){
                // If Terminal is running, ask user to do it herself
                NSBeginInformationalAlertSheet(NSLocalizedStringFromTableInBundle(@"SUGGEST CHANGE TERMINAL STRING ENCODING", nil, bundle, ""), nil, nil, nil, [[self mainView] window], nil, NULL, NULL, NULL, @"%@", NSLocalizedStringFromTableInBundle(@"WHY AND HOW CHANGE TERMINAL SETTINGS...", nil, bundle, ""));

                // We won't bother user asking her once again, unless she changed encoding to something else
                [[self userDefaultsDictionary] setObject:[NSNumber numberWithInt:terminalStringEncoding] forKey:@"LastTerminalStringEncoding"];
                [self saveUserDefaults];
            }
            else
                // Seems that Terminal is not running; we can modify its preferences
                NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"CHANGE TERMINAL STRING ENCODING?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"PLEASE DO", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(terminalStringEncodingSheetDidDismiss:returnCode:contextInfo:), [[NSNumber numberWithInt:terminalStringEncoding] retain], @"%@", NSLocalizedStringFromTableInBundle(@"WHY CHANGING TERMINAL SETTINGS...", nil, bundle, ""));
        }
        else{
            // We won't bother user asking her once again, unless she changed encoding to something else
            [[self userDefaultsDictionary] setObject:[NSNumber numberWithInt:terminalStringEncoding] forKey:@"LastTerminalStringEncoding"];
            [self saveUserDefaults];
            [self nextTest];
        }
    }
    else
        [self nextTest];
}

- (void) executeOperationForFilename:(NSString *)filename
{
    NSString	*bundleIdentifier = [[self bundle] bundleIdentifier];
    NSString	*commandString = nil;
    OSErr		error;
    int			command = [[operationMatrix selectedCell] tag];
    
    switch(command){
        case kMyAuthorizedCommandLink:
            commandString = @".makeLinkForGPG";
            break;
        case kMyAuthorizedCommandMove:
            commandString = @".moveGPG";
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unknown command - matrix selected cell tag = %d", [[operationMatrix selectedCell] tag]];
    }
    error = GPGPreferences_ExecuteAdminCommand([[bundleIdentifier stringByAppendingString:commandString] cString], command, [filename fileSystemRepresentation], CFBundleGetBundleWithIdentifier((CFStringRef)bundleIdentifier));
    if(error != noErr){
            NSBundle	*bundle = [self bundle];
            NSString	*message = [NSString stringWithFormat:@"AUTH ERROR %hd", error];

#warning Message according to value; see authinfo.h
            NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"CANNOT EXECUTE OPERATION", nil, bundle, ""), nil, nil, nil, [[self mainView] window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), NULL, NSLocalizedStringFromTableInBundle(@"OPERATION %@ FAILED (%@).", nil, bundle, ""), commandString, message);
    }
    else{
        [[self controllerForIdentifier:[[tabView selectedTabViewItem] identifier]] tabItemWillBeSelected]; // Forces refresh of view
        [self nextTest];
    }
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton)
        [self performSelector:@selector(executeOperationForFilename:) withObject:[sheet filename] afterDelay:0.0];
    else
        [self nextTest];
}

- (void) locationWarningSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton){
        NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

        [openPanel setCanChooseDirectories:NO];
        [openPanel setCanChooseFiles:YES];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setCanSelectHiddenExtension:YES];
        [openPanel setExtensionHidden:NO];
        [openPanel setTreatsFilePackagesAsDirectories:YES];
        [openPanel setPrompt:NSLocalizedStringFromTableInBundle(@"CHOOSE", nil, [NSBundle bundleForClass:[self class]], "")];
        [openPanel setAccessoryView:[operationMatrix superview]];
        [operationMatrix selectCellWithTag:kMyAuthorizedCommandLink];

        [openPanel beginSheetForDirectory:NSHomeDirectory() file:[[GPGOptions gpgPath] lastPathComponent] types:nil modalForWindow:[[self mainView] window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
    else
        [self nextTest];
}

- (void) checkGPGLocation
{
    // Check that gpg is in /usr/local/bin/ else ask where it is, and make link (=> needs Admin rights)
    NSFileManager	*defaultManager = [NSFileManager defaultManager];
    NSString		*gpgPath = [GPGOptions gpgPath];

    if(![defaultManager fileExistsAtPath:gpgPath]){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"WHERE IS GPG?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"SEARCH GPG", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"CANCEL", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(locationWarningSheetDidDismiss:returnCode:contextInfo:), NULL, NSLocalizedStringFromTableInBundle(@"WHY GPG MUST BE IN %@...", nil, bundle, ""), gpgPath);
    }
    else
        [self nextTest];
}

- (void) startTests
{
    testSelectors = [[NSArray alloc] initWithObjects:@"checkGPGLocation", @"checkGPGHasBaseFiles", @"checkCharsetIsUTF8", @"checkTerminalStringEncoding", @"checkGNUPGHOMERights", @"checkGNUPGHOMESuggestion", nil];
    currentTestSelector = [testSelectors objectAtIndex:0];
    [self checkGPGLocation];
}

- (void) nextTest
{
    int	currentIndex = [testSelectors indexOfObject:currentTestSelector];
    
    if(++currentIndex >= [testSelectors count]){
        currentTestSelector = nil;
        [testSelectors release];
        testSelectors = nil;
    }
    else{
        currentTestSelector = [testSelectors objectAtIndex:currentIndex];
        [self performSelector:NSSelectorFromString(currentTestSelector) withObject:nil afterDelay:0.0];
    }
}

@end
