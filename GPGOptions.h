//
//  GPGOptions.h
//  GPGPreferences and GPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Feb 03 2002.
//
//
//  Copyright (C) 2002-2005 Mac GPG Project.
//  
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU Lesser General Public License as published by the Free
//  Software Foundation; either version 2.1 of the License, or (at your option)
//  any later version.
//  
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
//  details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program; if not, visit <http://www.gnu.org/> or write to the
//  Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, 
//  MA 02111-1307, USA.
//  
//  More info at <http://macgpg.sourceforge.net/>
//

#ifndef GPGOPTIONS_H
#define GPGOPTIONS_H

#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@interface GPGOptions : NSObject
{
    NSMutableArray	*optionFileLines;
    NSMutableArray	*optionNames;
    NSMutableArray	*optionValues;
    NSMutableArray	*optionStates;
    NSMutableArray	*optionLineNumbers;
    BOOL			hasModifications;
}

/*"
 * File locations
"*/
+ (NSString *) gpgPath;
+ (NSString *) optionsFilename;

/*"
 * GnuPG version
"*/
+ (NSString *) gnupgVersion;

/*"
 * GnuPG home directory
"*/
+ (NSString *) homeDirectory;
+ (void) setHomeDirectory:(NSString *)homeDirectory;
+ (BOOL) homeDirectoryChanged;

/*"
 * HTTP proxy
"*/
+ (NSString *) httpProxy;
+ (void) setHttpProxy:(NSString *)httpProxy;
+ (BOOL) httpProxyChanged;

/*"
 * Setting options
"*/
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

/*"
 * Getting options
"*/
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

/*"
 * Sub-options
"*/
// The following methods are used for --keyserver-options parameters
- (BOOL) subOptionState:(NSString *)subOptionName forName:(NSString *)optionName;
- (void) setSubOption:(NSString *)subOptionName state:(BOOL)state forName:(NSString *)optionName;
    // If state is YES and option does not yet exist, it is created

/*"
 * Loading and saving options
"*/
- (void) reloadOptions;
- (void) saveOptions;

/*"
 * Getting inactive and active options
"*/
- (NSArray *) allOptionValuesForName:(NSString *)name;
// Returns all values for option name whatever their state is
- (NSArray *) activeOptionValuesForName:(NSString *)name;
// Returns all values for option name whose state is active

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGOPTIONS_H */
