//
//  GPGExtensionsPrefs.h
//  GPGPreferences
//
//  Created by davelopper@users.sourceforge.net on Sat Mar 09 2002.
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


@interface GPGExtensionsPrefs : GPGPrefController
{
    IBOutlet NSButtonCell	*deleteExtensionButtonCell;
    IBOutlet NSTableView	*extensionsTableView;
    IBOutlet NSButton		*switchProtoButton;
    NSMutableArray			*extensions;
}

- (IBAction) addExtension:(id)sender;
- (IBAction) deleteExtension:(id)sender;

@end
