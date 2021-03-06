//
//  GPGGlobalPrefs.h
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
//  More info at <http://macgpg.sourceforge.net/>
//


#import <PreferencePanes/PreferencePanes.h>


@interface GPGGlobalPrefs : NSPreferencePane
{
    IBOutlet NSTextField	*gpgPathTextField;
    IBOutlet NSTextField	*homeDirectoryTextField;
    IBOutlet NSTextView     *versionTextView;
    IBOutlet NSTextField	*warningTextField;
    IBOutlet NSImageView	*warningImageView;
    IBOutlet NSButton		*moveButton;
}

- (IBAction)changeExecutablePath:(id)sender;
- (IBAction)chooseExecutablePath:(id)sender;
- (IBAction)changeHomeDirectory:(id)sender;
- (IBAction)chooseHomeDirectory:(id)sender;
- (IBAction)showWarranty:(id)sender;

@end
