//
//  GPGOptions.h
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

+ (NSString *) optionsFilename;

+ (void) setGnupgVersion:(NSString *)version;
+ (NSString *) gnupgVersion;

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
- (void) setEmptyOptionValueAtIndex:(unsigned)index;
- (void) setOptionName:(NSString *)name atIndex:(unsigned)index;
- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index;

// -saveOptions is automatically called
- (void) addOptionNamed:(NSString *)name;
- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index;
- (void) removeOptionAtIndex:(unsigned)index;
- (unsigned) moveOptionsAtIndexes:(NSArray *)indexes toIndex:(unsigned)index;
// Returns the index of the first moved option

- (NSArray *) optionNames;
- (NSArray *) optionValues;
- (NSArray *) optionStates;

// You need to call -saveOptions
- (NSString *) optionValueForName:(NSString *)name;
// Returns nil if option is not defined
- (void) setOptionValue:(NSString *)value forName:(NSString *)name;
// If value is nil, option is removed
- (void) setEmptyOptionValueForName:(NSString *)name;
- (BOOL) optionStateForName:(NSString *)name;
- (void) setOptionState:(BOOL)state forName:(NSString *)name;
// If state is YES and option does not yet exist, it is created

// The following methods are used for --keyserver-options parameters
- (BOOL) subOptionState:(NSString *)subOptionName forName:(NSString *)optionName;
- (void) setSubOption:(NSString *)subOptionName state:(BOOL)state forName:(NSString *)optionName;
    // If state is YES and option does not yet exist, it is created

- (void) saveOptions;

- (NSArray *) activeOptionValuesForName:(NSString *)name;
// Returns all values for option name whose state is active

@end
