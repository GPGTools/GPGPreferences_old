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
#import "GPGSignaturePrefs.h"
#import "GPGExtensionsPrefs.h"
#import "GPGCompatibilityPrefs.h"
#import "GPGKeyServerPrefs.h"
#import "authinfo.h"
#import <Carbon/Carbon.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>


#define TERMINAL_UTF8_STRING_ENCODING	(4)
#define TERMINAL_DOMAIN_NAME			@"com.apple.Terminal"
#define TERMINAL_STRING_ENCODING_KEY	@"StringEncoding"


OSStatus GPGPreferences_ExecuteAdminCommand(const char *rightName, int authorizedCommandOperation, const char *fileArgument, uid_t uid, gid_t gid, mode_t mode, CFBundleRef bundle); // Implemented in authapp.c

@interface GPGPreferences(Private)
- (void) startTests;
- (void) nextTest;
- (OSErr) executeOperation:(int)command forFilename:(NSString *)filename owner:(uid_t)owner group:(gid_t)group mode:(mode_t)mode;
@end

@implementation GPGPreferences

#warning TODO: Add bundle icon

- (id) initWithBundle:(NSBundle *)bundle
{
    if(self = [super initWithBundle:bundle]){
        tabViewItemControllers = [[NSArray allocWithZone:[self zone]] initWithObjects:[GPGGlobalPrefs controllerWithIdentifier:@"GPGGlobalPrefs" preferences:self], [GPGKeyServerPrefs controllerWithIdentifier:@"GPGKeyServerPrefs" preferences:self], [GPGSignaturePrefs controllerWithIdentifier:@"GPGSignaturePrefs" preferences:self], [GPGExtensionsPrefs controllerWithIdentifier:@"GPGExtensionsPrefs" preferences:self], [GPGCompatibilityPrefs controllerWithIdentifier:@"GPGCompatibilityPrefs" preferences:self], [GPGExpertPrefs controllerWithIdentifier:@"GPGExpertPrefs" preferences:self], nil];
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
    
    [options release];
    if(shouldChange){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"CHANGE CHARSET TO UTF-8?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"PLEASE DO", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(charsetSheetDidDismiss:returnCode:contextInfo:), [lastCharset retain], @"%@", NSLocalizedStringFromTableInBundle(@"WHY CHANGING CHARSET...", nil, bundle, ""));
    }
    else
        [self nextTest];
}

- (void) fileRightSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSDictionary	*aDict = (NSDictionary *)contextInfo;

    if(returnCode == NSOKButton){
        NSEnumerator	*anEnum = [[aDict objectForKey:@"badFiles"] objectEnumerator];
        NSString		*aPath;
        NSFileManager	*defaultManager = [NSFileManager defaultManager];
        NSMutableArray	*stillBadPaths = [NSMutableArray array];

        while(aPath = [anEnum nextObject]){
            NSDictionary	*attr = [NSDictionary dictionaryWithDictionary:[defaultManager fileAttributesAtPath:aPath traverseLink:YES]];

            if(![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()]){
                OSErr	error = [self executeOperation:kMyAuthorizedCommandSetOwnerAndMode forFilename:aPath owner:getuid() group:getgid() mode:[[attr objectForKey:NSFilePosixPermissions] intValue] & ~(S_IRWXG|S_IRWXO)];

                if(error)
                    [stillBadPaths addObject:aPath];
            }
            else{
                NSNumber	*newPosix = [NSNumber numberWithInt:[[attr objectForKey:NSFilePosixPermissions] intValue] & ~(S_IRWXG|S_IRWXO)];

                if(![defaultManager changeFileAttributes:[NSDictionary dictionaryWithObject:newPosix forKey:NSFilePosixPermissions] atPath:aPath]){
                    [stillBadPaths addObject:aPath];
                }
            }
        }

        anEnum = [[aDict objectForKey:@"badExtensions"] objectEnumerator];
        while(aPath = [anEnum nextObject]){
            NSDictionary	*attr = [NSDictionary dictionaryWithDictionary:[defaultManager fileAttributesAtPath:aPath traverseLink:YES]];

            if(![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()]){
                OSErr	error = [self executeOperation:kMyAuthorizedCommandSetOwnerAndMode forFilename:aPath owner:0 group:0 mode:(S_IRUSR|S_IXUSR|S_IXGRP|S_IXOTH)]; // root/wheel r-x--x--x

                if(error)
                    [stillBadPaths addObject:aPath];
            }
            else{
                NSNumber	*newPosix = [NSNumber numberWithInt:(S_IRUSR|S_IXUSR|S_IXGRP|S_IXOTH)]; // r-x--x--x

                if(![defaultManager changeFileAttributes:[NSDictionary dictionaryWithObject:newPosix forKey:NSFilePosixPermissions] atPath:aPath]){
                    [stillBadPaths addObject:aPath];
                }
            }
        }

        if([stillBadPaths count]){
            NSBundle	*bundle = [self bundle];
            NSString	*message = [NSString stringWithFormat:@"UNABLE TO MODIFY ACCESS RIGHTS ON FILES:\n\n%@", [stillBadPaths componentsJoinedByString:@"\n"]];

            [aDict release];
            NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"UNABLE TO MODIFY ACCESS RIGHTS", nil, bundle, ""), nil, nil, nil, [[self mainView] window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), NULL, @"%@", NSLocalizedStringFromTableInBundle(message, nil, bundle, ""));
        }
        else{
            [aDict release];
            [self nextTest];
        }
    }
    else{
        [aDict release];
        [self nextTest];
    }
}

- (void) checkGNUPGHOMERights
{
    // Set rights on --homeDirectory (0700) (+ other files?)
    // gpg checks rights on extensions, keyrings, options, trustDB and random_seed
    // We check only the default files
    // See gpg code: g10/misc.c, check_permissions()
    NSFileManager	*defaultManager = [NSFileManager defaultManager];
    NSString		*homeDirectory = [GPGOptions homeDirectory];
    NSMutableArray	*files = [NSMutableArray arrayWithObjects:[homeDirectory stringByAppendingPathComponent:@"random_seed"], [homeDirectory stringByAppendingPathComponent:@"secring.gpg"], [homeDirectory stringByAppendingPathComponent:@"pubring.gpg"], [homeDirectory stringByAppendingPathComponent:@"trustdb.gpg"], [homeDirectory stringByAppendingPathComponent:@"options"], nil];
    NSEnumerator	*anEnum;
    NSString		*aPath;
    NSMutableArray	*badFiles = [NSMutableArray array];
    NSMutableArray	*badExtensions = [NSMutableArray array];
    GPGOptions		*options = [[GPGOptions alloc] init];

    [files addObjectsFromArray:[options activeOptionValuesForName:@"keyring"]];
    [files addObjectsFromArray:[options activeOptionValuesForName:@"secret-keyring"]];

    anEnum = [files objectEnumerator];
    while(aPath = [anEnum nextObject]){
        if([defaultManager fileExistsAtPath:aPath]){
            NSDictionary	*attr = [defaultManager fileAttributesAtPath:aPath traverseLink:YES];

            if([[attr objectForKey:NSFileType] isEqualToString:NSFileTypeRegular]){
                // User must be owner
                if(![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()])
                    [badFiles addObject:aPath];
                // group and others may not read/write/exec
                else if([[attr objectForKey:NSFilePosixPermissions] intValue] & (S_IRWXG|S_IRWXO)){
                    attr = [defaultManager fileAttributesAtPath:[aPath stringByDeletingLastPathComponent] traverseLink:YES];
                    if(![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()] || [[attr objectForKey:NSFilePosixPermissions] intValue] & (S_IRWXG|S_IRWXO))
                        [badFiles addObject:aPath];
                }
            }
        }
    }

    [files setArray:[options activeOptionValuesForName:@"load-extension"]];
    anEnum = [files objectEnumerator];
    while(aPath = [anEnum nextObject]){
        if(![aPath isAbsolutePath])
            aPath = [@"/usr/local/lib/gnupg" stringByAppendingPathComponent:aPath];
        if([defaultManager fileExistsAtPath:aPath]){
            NSDictionary	*attr = [defaultManager fileAttributesAtPath:aPath traverseLink:YES];

            if([[attr objectForKey:NSFileType] isEqualToString:NSFileTypeRegular]){
                // owner must be user or root
                if(![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()] && ![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:@"root"])
                    [badExtensions addObject:aPath];
                // group and others may not write, except if parentDir's owner is user or root,
                // and parentDir is not readable/writable/executable for group/others
                else if([[attr objectForKey:NSFilePosixPermissions] intValue] & (S_IWGRP|S_IWOTH)){
                    attr = [defaultManager fileAttributesAtPath:[aPath stringByDeletingLastPathComponent] traverseLink:YES];
                    if((![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:NSUserName()]  && ![[attr objectForKey:NSFileOwnerAccountName] isEqualToString:@"root"]) || [[attr objectForKey:NSFilePosixPermissions] intValue] & (S_IRWXG|S_IRWXO))
                        [badExtensions addObject:aPath];
                }
            }
        }
    }
    [options release];

    if([badExtensions count] || [badFiles count]){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"SOME FILES HAVE INVALID FILE ACCESS RIGHTS. CORRECT THEM?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"PLEASE DO", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(fileRightSheetDidDismiss:returnCode:contextInfo:), [[NSDictionary alloc] initWithObjectsAndKeys:badFiles, @"badFiles", badExtensions, @"badExtensions", nil], @"%@", [NSLocalizedStringFromTableInBundle(@"WHICH ACCESS RIGHTS...", nil, bundle, "") stringByAppendingString:[[badFiles arrayByAddingObjectsFromArray:badExtensions] componentsJoinedByString:@"\n"]]);
    }
    else
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

- (void) checkComment
{
    // Same test as in GPGSignaturePrefs, but done only once here
    GPGOptions	*options = [[GPGOptions alloc] init];
    NSString	*comment = [options optionValueForName:@"comment"];
    BOOL		isEmptyComment = (comment == nil || [comment rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length == 0);

    [options release];
    if(!isEmptyComment && ![comment canBeConvertedToEncoding:NSASCIIStringEncoding]){
        NSString	*lastComment = [[self userDefaultsDictionary] objectForKey:@"LastComment"];

        if(!lastComment){
            NSBundle	*bundle = [self bundle];

            [[self userDefaultsDictionary] setObject:comment forKey:@"LastComment"];
            [self saveUserDefaults];
            // WARNING: same title/message as in GPGSignaturePrefs
            NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"COMMENT SHOULD BE ASCII ONLY", nil, bundle, ""), nil, nil, nil, [[self mainView] window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), NULL, @"%@", NSLocalizedStringFromTableInBundle(@"WHY ONLY ASCII IN COMMENT...", nil, bundle, ""));
        }
        else
            [self nextTest];
    }
    else
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
    NSNumber	*terminalStringEncodingNumber = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:TERMINAL_DOMAIN_NAME] objectForKey:TERMINAL_STRING_ENCODING_KEY];
    int			terminalStringEncoding = -1;
    NSNumber	*lastTerminalStringEncodingNumber = [[self userDefaultsDictionary] objectForKey:@"LastTerminalStringEncoding"];
    int			lastTerminalStringEncoding = -1;
    
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
                // We won't bother user asking her once again, unless she changed encoding to something else
                [[self userDefaultsDictionary] setObject:[NSNumber numberWithInt:terminalStringEncoding] forKey:@"LastTerminalStringEncoding"];
                [self saveUserDefaults];
                NSBeginInformationalAlertSheet(NSLocalizedStringFromTableInBundle(@"SUGGEST CHANGE TERMINAL STRING ENCODING", nil, bundle, ""), nil, nil, nil, [[self mainView] window], nil, NULL, NULL, NULL, @"%@", NSLocalizedStringFromTableInBundle(@"WHY AND HOW CHANGE TERMINAL SETTINGS...", nil, bundle, ""));
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

- (OSErr) executeOperation:(int)command forFilename:(NSString *)filename owner:(uid_t)owner group:(gid_t)group mode:(mode_t)mode
{
    NSString	*bundleIdentifier = [[self bundle] bundleIdentifier];
    NSString	*commandString = nil;
    
    switch(command){
        case kMyAuthorizedCommandLink:
            commandString = @".makeLinkForGPG";
            break;
        case kMyAuthorizedCommandMove:
            commandString = @".moveGPG";
            break;
        case kMyAuthorizedCommandSetOwnerAndMode:
            commandString = @".setOwnerAndMode";
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unknown command - matrix selected cell tag = %d", [[operationMatrix selectedCell] tag]];
    }
    return GPGPreferences_ExecuteAdminCommand([[bundleIdentifier stringByAppendingString:commandString] cString], command, [filename fileSystemRepresentation], owner, group, mode, CFBundleGetBundleWithIdentifier((CFStringRef)bundleIdentifier));
}

- (void) executeOperationForFilename:(NSString *)filename
{
    int		command = [[operationMatrix selectedCell] tag];
    OSErr	error = [self executeOperation:command forFilename:filename owner:-1 group:-1 mode:-1];
    
    if(error != noErr){
        NSBundle	*bundle = [self bundle];
        NSString	*message = [NSString stringWithFormat:@"AUTH ERROR %hd", error];
        NSString	*commandString = [NSString stringWithFormat:@"OP#%d", command];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"CANNOT EXECUTE OPERATION", nil, bundle, ""), nil, nil, nil, [[self mainView] window], self, NULL, @selector(sheetDidDismiss:returnCode:contextInfo:), NULL, NSLocalizedStringFromTableInBundle(@"OPERATION %@ FAILED (%@).", nil, bundle, ""), NSLocalizedStringFromTableInBundle(commandString, nil, bundle, ""), NSLocalizedStringFromTableInBundle(message, nil, bundle, ""));
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

- (void) updateOptionsSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton){
        GPGOptions	*options = [[GPGOptions alloc] init];
        NSString	*honorHTTPProxy = [options optionValueForName:@"honor-http-proxy"];
        NSString	*noAutoKeyRetrieve = [options optionValueForName:@"no-auto-key-retrieve"];

        [options setOptionValue:nil forName:@"default-comment"]; // Deprecated with gpg 1.0.7

        if(honorHTTPProxy != nil)
            [options setSubOption:@"honor-http-proxy" state:[options optionStateForName:@"honor-http-proxy"] forName:@"keyserver-options"];
        [options setOptionValue:nil forName:@"honor-http-proxy"]; // Deprecated with gpg 1.0.7

        if(noAutoKeyRetrieve != nil)
            [options setSubOption:@"auto-key-retrieve" state:![options optionStateForName:@"no-auto-key-retrieve"] forName:@"keyserver-options"];
        [options setOptionValue:nil forName:@"no-auto-key-retrieve"]; // Deprecated with gpg 1.0.7

        [options saveOptions];
        [options release];
    }
    [self nextTest];
}

- (void) updateOptionsFor107
{
    GPGOptions	*options = [[GPGOptions alloc] init];
    NSString	*honorHTTPProxy = [options optionValueForName:@"honor-http-proxy"];
    NSString	*noAutoKeyRetrieve = [options optionValueForName:@"no-auto-key-retrieve"];
    NSString	*defaultComment = [options optionValueForName:@"default-comment"];

    [options release];
    if(honorHTTPProxy != nil || noAutoKeyRetrieve != nil || defaultComment != nil){
        NSBundle	*bundle = [self bundle];

        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"UPDATE OPTIONS?", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"PLEASE DO", nil, bundle, ""), NSLocalizedStringFromTableInBundle(@"DON'T CHANGE", nil, bundle, ""), nil, [[self mainView] window], self, NULL, @selector(updateOptionsSheetDidDismiss:returnCode:contextInfo:), NULL, NSLocalizedStringFromTableInBundle(@"WHY UPDATING OPTIONS...", nil, bundle, ""));
    }
    else
        [self nextTest];
}

- (void) startTests
{
    testSelectors = [[NSArray alloc] initWithObjects:@"checkGPGLocation", @"checkGPGHasBaseFiles", @"updateOptionsFor107", @"checkCharsetIsUTF8", @"checkTerminalStringEncoding", @"checkGNUPGHOMERights", @"checkGNUPGHOMESuggestion", @"checkComment", nil];
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
