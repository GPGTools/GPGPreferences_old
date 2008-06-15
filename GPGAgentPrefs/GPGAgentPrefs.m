//
//  GPGAgentPrefs.m
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sun May 14 2006.
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

#import "GPGAgentPrefs.h"
#import <MacGPGME/MacGPGME.h>


typedef enum {
    GPGAgentIsNotInstalled,
    GPGAgentIsNotRunning,
    GPGAgentIsRunning
}GPGAgentStatus;

typedef enum {
    SmartcardDaemonIsNotInstalled,
    SmartcardDaemonIsNotRunning,
    SmartcardDaemonIsRunning
}SmartCardDaemonStatus;


@interface GPGAgentPrefs(Private)
- (void)refreshAgentStatus;
- (void)refreshSmartCardDaemonStatus;
@end

// TODO: how to get informed automatically when agent/daemon state changes?

@implementation GPGAgentPrefs

- (void)dealloc
{
    [options release];
    
    [super dealloc];
}

- (GPGOptions *)options
{
    if(options == nil){
        // If conf file doesn't exist, GPGOptions considers file as empty.
        options = [[GPGOptions alloc] initWithPath:[[GPGEngine defaultHomeDirectoryForProtocol:GPGOpenPGPProtocol] stringByAppendingPathComponent:@"gpg-agent.conf"]];
    }
    
    return options;
}

- (void)willSelect
{
    [super willSelect];

    [self refreshAgentStatus];
    [self refreshSmartCardDaemonStatus];
    [smartCardDaemonStartStopButton setHidden:YES]; // TODO: remove 2 lines once available
    [smartCardDaemonStatusTextField setHidden:YES];
    
    // To avoid the date picker to display AM/PM, we need to ensure that locale
    // doesn't display them; let's use the root locale.
    NSLocale    *aLocale = [NSLocale systemLocale];
    [defaultTimeoutDatePicker setLocale:aLocale];
    [maxTimeoutDatePicker setLocale:aLocale];
}

- (void)willUnselect
{
    [super willUnselect];
    
    [options release];
    options = nil;
}

#pragma mark GPG Agent

- (NSString *)agentLaunchdFile
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/net.sourceforge.macgpg.gpg-agent.plist"];
}

- (GPGAgentStatus)agentStatusAndPID:(int *)agentPIDPtr
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:[self agentLaunchdFile]])
        return GPGAgentIsNotInstalled;
    
    NSTask  *task = [[NSTask alloc] init];
    NSError *anError;
    NSPipe  *aPipe = [NSPipe pipe];
    NSPipe  *aPipe2 = [NSPipe pipe];
    
    [task setArguments:[NSArray arrayWithObjects:@"list", nil]];
    [task setLaunchPath:@"/bin/launchctl"];
    [task setStandardOutput:aPipe];
    
    NSTask  *task2 = [[NSTask alloc] init];
    
    [task2 setArguments:[NSArray arrayWithObjects:@"net.sourceforge.macgpg.gpg-agent", nil]];
    [task2 setLaunchPath:@"/usr/bin/grep"];

    [task2 setStandardInput:aPipe];
    [task2 setStandardOutput:aPipe2];
    [task launch];
    [task2 launch];
    
    NSData  *data = [[[[aPipe2 fileHandleForReading] readDataToEndOfFile] retain] autorelease];
    
    [task2 waitUntilExit];
    [task waitUntilExit];
    
    if([task terminationStatus] != 0)
		anError = [NSError errorWithDomain:@"GPGAgentPrefs" code:[task terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"LAUNCHCTL ERROR (%i)", nil, [self bundle], @""), [task terminationStatus]], NSLocalizedDescriptionKey, nil]];
    else
        anError = nil;
    
    [task release];
    [task2 release];
    
    if([data length] == 0)
        return GPGAgentIsNotRunning;
    else{
        if(agentPIDPtr){
            NSString    *aString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            *agentPIDPtr = [aString intValue];
            [aString release];
        }
        
        return GPGAgentIsRunning;
    }
}

- (NSDate *)referenceDate
{
    return [NSDate dateWithTimeIntervalSince1970:-3600];
}

- (void)refreshAgentStatus
{
    int     seconds = 0;
    NSDate  *refDate = [self referenceDate];
    
    switch([self agentStatusAndPID:NULL]){
        case GPGAgentIsNotInstalled:
            [agentStartStopButton setEnabled:NO];
            [agentFlushButton setEnabled:NO];
            [agentStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"START", nil, [self bundle], @"")];
            [agentStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"GPG_AGENT IS NOT INSTALLED", nil, [self bundle], @"")];
            [ignoreCacheForSigningSwitch setEnabled:NO];
            [ignoreCacheForSigningSwitch setState:NSOffState];
            [defaultTimeoutDatePicker setEnabled:NO];
            [defaultTimeoutDatePicker setDateValue:[refDate addTimeInterval:600]];
            [maxTimeoutDatePicker setEnabled:NO];
            [maxTimeoutDatePicker setDateValue:[refDate addTimeInterval:7200]];
            break;
        case GPGAgentIsNotRunning:
            [agentStartStopButton setEnabled:YES];
            [agentFlushButton setEnabled:NO];
            [agentStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"START", nil, [self bundle], @"")];
            [agentStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"GPG_AGENT IS NOT RUNNING", nil, [self bundle], @"")];
            [ignoreCacheForSigningSwitch setEnabled:YES];
            [ignoreCacheForSigningSwitch setState:([[self options] optionStateForName:@"ignore-cache-for-signing"] ? NSOnState : NSOffState)];
            if([[self options] optionStateForName:@"default-cache-ttl"])
                seconds = [[[self options] optionValueForName:@"default-cache-ttl"] intValue];
            else
                seconds = 600;
            [defaultTimeoutDatePicker setDateValue:[refDate addTimeInterval:seconds]];
            [defaultTimeoutDatePicker setEnabled:YES];
            if([[self options] optionStateForName:@"max-cache-ttl"])
                seconds = [[[self options] optionValueForName:@"max-cache-ttl"] intValue];
            else
                seconds = 7200;
            [maxTimeoutDatePicker setDateValue:[refDate addTimeInterval:seconds]];
            [maxTimeoutDatePicker setEnabled:YES];
            break;
        case GPGAgentIsRunning:
            [agentStartStopButton setEnabled:YES];
            [agentFlushButton setEnabled:YES];
            [agentStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"STOP", nil, [self bundle], @"")];
            [agentStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"GPG_AGENT IS RUNNING", nil, [self bundle], @"")];
            [ignoreCacheForSigningSwitch setEnabled:YES];
            [ignoreCacheForSigningSwitch setState:([[self options] optionStateForName:@"ignore-cache-for-signing"] ? NSOnState : NSOffState)];
            if([[self options] optionStateForName:@"default-cache-ttl"])
                seconds = [[[self options] optionValueForName:@"default-cache-ttl"] intValue];
            else
                seconds = 600;
            [defaultTimeoutDatePicker setDateValue:[refDate addTimeInterval:seconds]];
            [defaultTimeoutDatePicker setEnabled:YES];
            if([[self options] optionStateForName:@"max-cache-ttl"])
                seconds = [[[self options] optionValueForName:@"max-cache-ttl"] intValue];
            else
                seconds = 7200;
            [maxTimeoutDatePicker setDateValue:[refDate addTimeInterval:seconds]];
            [maxTimeoutDatePicker setEnabled:YES];
    }
}

- (NSError *)loadAgent
{
    NSTask  *task = [[NSTask alloc] init];
    NSError *anError;
    
    [task setArguments:[NSArray arrayWithObjects:@"load", @"-w", @"-F", @"-S", @"Aqua", [self agentLaunchdFile], nil]];
    [task setLaunchPath:@"/bin/launchctl"];
    [task launch];
    [task waitUntilExit];
    
    if([task terminationStatus] != 0)
		anError = [NSError errorWithDomain:@"GPGAgentPrefs" code:[task terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"LAUNCHCTL ERROR (%i)", nil, [self bundle], @""), [task terminationStatus]], NSLocalizedDescriptionKey, nil]];
    else
        anError = nil;
    
    [task release];
    
    return anError;
}

// Will stop agent, and mark it as 'disabled'
- (NSError *)stopAgent
{
    NSTask  *task = [[NSTask alloc] init];
    NSError *anError;
    
    [task setArguments:[NSArray arrayWithObjects:@"unload", @"-w", @"-S", @"Aqua", [self agentLaunchdFile], nil]];
    [task setLaunchPath:@"/bin/launchctl"];
    [task launch];
    [task waitUntilExit];
    
    if([task terminationStatus] != 0)
		anError = [NSError errorWithDomain:@"GPGAgentPrefs" code:[task terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"LAUNCHCTL ERROR (%i)", nil, [self bundle], @""), [task terminationStatus]], NSLocalizedDescriptionKey, nil]];
    else
        anError = nil;
    
    [task release];
    
    return anError;
}

- (IBAction)toggleAgent:(id)sender
{
    NSError *anError = nil;
    
    switch([self agentStatusAndPID:NULL]){
        case GPGAgentIsNotInstalled:
            [agentStartStopButton setEnabled:NO];
            NSBeep();
            break;
        case GPGAgentIsNotRunning:
            anError = [self loadAgent];
            break;
        case GPGAgentIsRunning:
            anError = [self stopAgent];
    }
    [self refreshAgentStatus];
    
    if(anError)
        [NSApp presentError:anError modalForWindow:[[self mainView] window] delegate:nil didPresentSelector:NULL contextInfo:NULL];
}

- (BOOL)sendHUPSignalToAgentPID:(int)agentPID
{
    int anError;
    
    if((anError = kill(agentPID, SIGHUP)) != 0){
        NSBeep();
        NSLog(@"kill() returned %i", anError);
    }
    
    return anError == 0;
}

- (IBAction)flush:(id)sender
{
    int agentPID;
    
    if([self agentStatusAndPID:&agentPID] == GPGAgentIsRunning){
        if(![self sendHUPSignalToAgentPID:agentPID])
            NSBeep();
    }
    else{
        [agentFlushButton setEnabled:NO];
        NSBeep();
    }
}

- (IBAction)ignoreCacheForSigningChanged:(id)sender
{
    int agentPID;
    
    [[self options] setOptionState:([sender state] == NSOnState) forName:@"ignore-cache-for-signing"];
    [[self options] saveOptions];
    if([self agentStatusAndPID:&agentPID] == GPGAgentIsRunning)
        [self sendHUPSignalToAgentPID:agentPID];
}

- (IBAction)defaultTimeoutChanged:(id)sender
{
    int agentPID;

    [[self options] setOptionState:YES forName:@"default-cache-ttl"];
    [[self options] setOptionValue:[NSString stringWithFormat:@"%.0lf", [[sender dateValue] timeIntervalSinceDate:[self referenceDate]]] forName:@"default-cache-ttl"];
    [[self options] saveOptions];
    if([self agentStatusAndPID:&agentPID] == GPGAgentIsRunning)
        [self sendHUPSignalToAgentPID:agentPID];
}

- (IBAction)maxTimeoutChanged:(id)sender
{
    int agentPID;
    
    [[self options] setOptionState:YES forName:@"max-cache-ttl"];
    [[self options] setOptionValue:[NSString stringWithFormat:@"%.0lf", [[sender dateValue] timeIntervalSinceDate:[self referenceDate]]] forName:@"max-cache-ttl"];
    [[self options] saveOptions];
    if([self agentStatusAndPID:&agentPID] == GPGAgentIsRunning)
        [self sendHUPSignalToAgentPID:agentPID];
}

#pragma mark Smartcard Daemon

- (SmartCardDaemonStatus)smartCardDaemonStatus
{
    return SmartcardDaemonIsNotInstalled; // TODO: Add Smartcard Daemon support
}

- (void)refreshSmartCardDaemonStatus
{
    switch([self smartCardDaemonStatus]){
        case SmartcardDaemonIsNotInstalled:
            [smartCardDaemonStartStopButton setEnabled:NO];
            [smartCardDaemonStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"START", nil, [self bundle], @"")];
            [smartCardDaemonStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"SCD IS NOT INSTALLED", nil, [self bundle], @"")];
            break;
        case SmartcardDaemonIsNotRunning:
            [smartCardDaemonStartStopButton setEnabled:YES];
            [smartCardDaemonStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"START", nil, [self bundle], @"")];
            [smartCardDaemonStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"SCD IS NOT RUNNING", nil, [self bundle], @"")];
            break;
        case SmartcardDaemonIsRunning:
            [smartCardDaemonStartStopButton setEnabled:YES];
            [smartCardDaemonStartStopButton setTitle:NSLocalizedStringFromTableInBundle(@"STOP", nil, [self bundle], @"")];
            [smartCardDaemonStatusTextField setStringValue:NSLocalizedStringFromTableInBundle(@"SCD IS RUNNING", nil, [self bundle], @"")];
    }
}

- (NSString *)smartCardDaemonLaunchdFile
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/net.sourceforge.macgpg.smartcard-daemon.plist"];
}

- (NSError *)loadSmartCardDaemon
{
    NSTask  *task = [[NSTask alloc] init];
    NSError *anError;
    
    [task setArguments:[NSArray arrayWithObjects:@"load", @"-w", @"-F", @"-S", @"Aqua", [self smartCardDaemonLaunchdFile], nil]];
    [task setLaunchPath:@"/bin/launchctl"];
    [task launch];
    [task waitUntilExit];
    
    if([task terminationStatus] != 0)
		anError = [NSError errorWithDomain:@"GPGAgentPrefs" code:[task terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"LAUNCHCTL ERROR (%i)", nil, [self bundle], @""), [task terminationStatus]], NSLocalizedDescriptionKey, nil]];
    else
        anError = nil;
    
    [task release];
    
    return anError;
}

// Will stop agent, and mark it as 'disabled'
- (NSError *)stopSmartCardDaemon
{
    NSTask  *task = [[NSTask alloc] init];
    NSError *anError;
    
    [task setArguments:[NSArray arrayWithObjects:@"unload", @"-w", @"-S", @"Aqua", [self smartCardDaemonLaunchdFile], nil]];
    [task setLaunchPath:@"/bin/launchctl"];
    [task launch];
    [task waitUntilExit];
    
    if([task terminationStatus] != 0)
		anError = [NSError errorWithDomain:@"GPGAgentPrefs" code:[task terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"LAUNCHCTL ERROR (%i)", nil, [self bundle], @""), [task terminationStatus]], NSLocalizedDescriptionKey, nil]];
    else
        anError = nil;
    
    [task release];
    
    return anError;
}

- (IBAction)toggleSmartCardDaemon:(id)sender
{
    NSError *anError = nil;
    
    switch([self smartCardDaemonStatus]){
        case SmartcardDaemonIsNotRunning:
            anError = [self loadSmartCardDaemon];
            break;
        case SmartcardDaemonIsRunning:
            anError = [self stopSmartCardDaemon];
    }
    [self refreshSmartCardDaemonStatus];
    
    if(anError)
        [NSApp presentError:anError modalForWindow:[[self mainView] window] delegate:nil didPresentSelector:NULL contextInfo:NULL];
}

@end
