//
//  GPGOptions.h
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

#import <Foundation/Foundation.h>


@interface GPGOptions : NSObject
{
    NSMutableArray	*optionFileLines;
    NSMutableArray	*optionNames;
    NSMutableArray	*optionValues;
    NSMutableArray	*optionStates;
    NSMutableArray	*optionLineNumbers;
    BOOL			hasModifications;
}

+ (NSString *) homeDirectory;
+ (void) setHomeDirectory:(NSString *)homeDirectory;
+ (BOOL) homeDirectoryChanged;

+ (NSString *) httpProxy;
+ (void) setHttpProxy:(NSString *)httpProxy;
+ (BOOL) httpProxyChanged;

+ (NSString *) gpgPath;

// -saveOptions is automatically called
- (void) setOptionValue:(NSString *)value atIndex:(unsigned)index;
// If value is nil, option is removed
- (void) setOptionName:(NSString *)name atIndex:(unsigned)index;
- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index;

// -saveOptions is automatically called
- (void) addOptionNamed:(NSString *)name;
- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index;
- (void) removeOptionAtIndex:(unsigned)index;

- (NSArray *) optionNames;
- (NSArray *) optionValues;
- (NSArray *) optionStates;

// You need to call -saveOptions
- (NSString *) optionValueForName:(NSString *)name;
// Returns nil if option is not defined
- (void) setOptionValue:(NSString *)value forName:(NSString *)name;
// If value is nil, option is removed
- (BOOL) optionStateForName:(NSString *)name;
- (void) setOptionState:(BOOL)state forName:(NSString *)name;

- (void) saveOptions;

@end
