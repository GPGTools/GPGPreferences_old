//
//  GPGAgentPrefs.h
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


#import <PreferencePanes/PreferencePanes.h>


@class GPGOptions;


@interface GPGAgentPrefs : NSPreferencePane
{
    GPGOptions              *options;
    IBOutlet NSTextField    *agentStatusTextField;
    IBOutlet NSButton       *agentStartStopButton;
    IBOutlet NSButton       *agentFlushButton;
    IBOutlet NSButton       *ignoreCacheForSigningSwitch;
    IBOutlet NSDatePicker   *defaultTimeoutDatePicker;
    IBOutlet NSDatePicker   *maxTimeoutDatePicker;
    IBOutlet NSButton       *smartCardDaemonStartStopButton;
    IBOutlet NSTextField    *smartCardDaemonStatusTextField;
}

- (IBAction)toggleAgent:(id)sender;
- (IBAction)flush:(id)sender;
- (IBAction)ignoreCacheForSigningChanged:(id)sender;
- (IBAction)defaultTimeoutChanged:(id)sender;
- (IBAction)maxTimeoutChanged:(id)sender;
- (IBAction)toggleSmartCardDaemon:(id)sender;

@end
