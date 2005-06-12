//
//  GPGOptions.m
//  GPGPreferences and MacGPGME
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

#ifdef BUILDING_MAC_GPGME
#include <MacGPGME/GPGOptions.h>
#include <MacGPGME/GPGEngine.h>
#else
#include "GPGOptions.h"
#endif

static NSString *gnupgVersion = nil;


@interface GPGOptions(Private)
- (void) doSaveOptions;
@end

@interface NSMutableArray(GPGOptions)
- (unsigned) gpgMoveObjectsAtIndexes:(NSArray *)indexes toIndex:(unsigned)index;
@end

@implementation GPGOptions
/*"
 * #GPGOptions class allows you to retrieve options used by %GnuPG, as defined
 * in #GPGPreferences, from %GnuPG configuration file, read by the executable.
 *
 * You can also set options and save them, though this should be the job of
 * #GPGPreferences only.
 *
 * Options are defined by a name, a state (active or not), and, optionally
 * (sic), a value.
 *
 * Some options (keyserver-options) can have sub-options too.
"*/

+ (NSString *) currentEnvironmentVariableValueForName:(NSString *)name
{
    return [[[NSProcessInfo processInfo] environment] objectForKey:name];
}

+ (NSString *) futureEnvironmentVariableValueForName:(NSString *)name
{
    NSString			*aDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@".MacOSX"];
    NSString			*filename = [aDirectory stringByAppendingPathComponent:@"environment.plist"];
    NSMutableDictionary	*environment = [NSMutableDictionary dictionaryWithContentsOfFile:filename];

    if(environment == nil)
        return nil;
    else
        return [environment objectForKey:name];
}

+ (void) setFutureEnvironmentVariableValue:(NSString *)value forName:(NSString *)name
{
    // We modify ~/.MacOSX/environment.plist
    NSString			*aDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@".MacOSX"];
    NSString			*filename = [aDirectory stringByAppendingPathComponent:@"environment.plist"];
    NSMutableDictionary	*environment = [NSMutableDictionary dictionaryWithContentsOfFile:filename];
    NSString			*currentValue;
    BOOL				isModified;

    if(environment == nil){
        environment = [NSMutableDictionary dictionary];
        currentValue = nil;
    }
    else
        currentValue = [environment objectForKey:name];
    
    if(currentValue == nil){
        if(value == nil)
            isModified = NO;
        else
            isModified = YES;
    }
    else{
        if(value == nil)
            isModified = YES;
        else
            isModified = ![currentValue isEqualToString:value];
    }
    
    if(isModified){
        NSFileManager	*defaultManager = [NSFileManager defaultManager];
        BOOL			isDirectory;

        if(value == nil)
            [environment removeObjectForKey:name];
        else
            [environment setObject:value forKey:name];

        if([defaultManager fileExistsAtPath:aDirectory isDirectory:&isDirectory])
            NSAssert1(isDirectory, @"'%@' is not a directory.", aDirectory);
        else
            NSAssert1([defaultManager createDirectoryAtPath:aDirectory attributes:nil], @"Unable to create directory '%@'", aDirectory);

        NSAssert1([environment writeToFile:filename atomically:YES], @"Unable to write file '%@'", filename);
    }
}

+ (NSString *) defaultHomeDirectory
/*"
 * Returns the default %{home directory} for %GnuPG, i.e. #{$HOME/.gnupg}
"*/
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@".gnupg"];
}

+ (NSString *) currentHomeDirectory
/*"
 * Returns the %{home directory} used by %GnuPG; this might be the %default
 * one, or the one defined by the environment variable #GNUPGHOME.
"*/
{
    NSString	*homeDirectory = [self currentEnvironmentVariableValueForName:@"GNUPGHOME"];

    if(homeDirectory == nil)
        return [self defaultHomeDirectory];
    else
        return homeDirectory;
}

+ (NSString *) homeDirectory
/*"
 * Returns the %{home directory} used by %GnuPG, as configured by user. Maybe
 * user will need to logout and login to get it active, due to the use of
 * environment variable #GNUPGHOME.
"*/
{
    NSString	*homeDirectory = [self futureEnvironmentVariableValueForName:@"GNUPGHOME"];

    if(homeDirectory == nil)
        return [self defaultHomeDirectory];
    else
        return homeDirectory;
}

+ (void) setHomeDirectory:(NSString *)homeDirectory
/*"
 * Sets the %{home directory} for %GnuPG. Maybe user will need to logout and
 * login to get it active, due to the use of environment variable #GNUPGHOME.
"*/
{
    if(homeDirectory != nil && [homeDirectory rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length > 0)
        [self setFutureEnvironmentVariableValue:homeDirectory forName:@"GNUPGHOME"];
    else
        [self setFutureEnvironmentVariableValue:nil forName:@"GNUPGHOME"];
}

+ (BOOL) homeDirectoryChanged
/*"
 * Returns whether user changed %GnuPG's %{home directory}, i.e.
 * #{+homeDirectory} is equal or not to {+currentHomeDirectory}.
"*/
{
    return (![[[self homeDirectory] stringByStandardizingPath] isEqualToString:[[self currentHomeDirectory] stringByStandardizingPath]]);
}

+ (NSString *) systemHttpProxy
{
#warning TODO: Take http proxy from System
    // See /System/Library/Frameworks/SystemConfiguration.framework/Versions/A/Headers/SCDynamicStoreCopySpecific.h
    // or /System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/InternetConfig.h
    return nil;
}

+ (NSString *) currentHttpProxy
/*"
 * Returns the HTTP proxy currently used by %GnuPG, when connecting to key
 * servers.
"*/
{
    NSString	*httpProxy = [self currentEnvironmentVariableValueForName:@"http_proxy"];

    return httpProxy;
}

+ (NSString *) httpProxy
/*"
 * Returns the HTTP proxy used by %GnuPG, when connecting to key servers.
 * Maybe user will need to logout and login to get it active, due to the use
 * of environment variable #{http_proxy}.
"*/
{
    NSString	*httpProxy = [self futureEnvironmentVariableValueForName:@"http_proxy"];

    return httpProxy;
}

+ (void) setHttpProxy:(NSString *)httpProxy
/*"
 * Sets the HTTP proxy to be used by %GnuPG, when connecting to key servers.
 * Maybe user will need to logout and login to get it active, due to the use
 * of environment variable #{http_proxy}.
"*/
{
    if([httpProxy rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0)
        [self setFutureEnvironmentVariableValue:httpProxy forName:@"http_proxy"];
    else
        [self setFutureEnvironmentVariableValue:nil forName:@"http_proxy"];
}

+ (BOOL) httpProxyChanged
/*"
 * Returns whether user changed %GnuPG's HTTP proxy, i.e. #{+httpProxy} is
 * equal or not to #{+currentHttpProxy}.
"*/
{
    NSString	*currentHttpProxy = [self currentHttpProxy];
    NSString	*httpProxy = [self httpProxy];

    if(currentHttpProxy == nil)
        if(httpProxy == nil)
            return NO;
        else
            return YES;
    else if(httpProxy == nil)
        return YES;
    else
        return ![currentHttpProxy isEqualToString:httpProxy];
}

+ (NSString *) gpgPath
/*"
 * Returns the expected location of %GnuPG. Currently hardcoded to
 * #{/usr/local/bin/gpg}, due to libgpgme.
"*/
{
    // MacGPGME does not support another path, yet
    return @"/usr/local/bin/gpg";
}

+ (NSString *) optionsFilename
/*"
 * Returns the full path name to %GnuPG configuration file. It depends on
 * %GnuPG version. If user changed %GnuPG's %{home directory} without logging
 * out and in, returned value might be not yet valid.
 *
 * Raises an exception when %GnuPG version cannot be found out.
"*/
{
    NSString	*aVersion = [self gnupgVersion];
    
    if(aVersion != nil && [aVersion rangeOfString:@"1.0."].length > 0)
        return [[self homeDirectory] stringByAppendingPathComponent:@"options"];
    else
        return [[self homeDirectory] stringByAppendingPathComponent:@"gpg.conf"];
}

- (void) parseOptionsFromLines:(NSArray *)lines save:(BOOL)save
{
    unsigned	i, lineCount;

    [optionFileLines setArray:lines];
    if(save)
        [self doSaveOptions];
    lineCount = [optionFileLines count];
    for(i = 0; i < lineCount; i++){
        NSString	*aLine = [optionFileLines objectAtIndex:i];
        unsigned	lineLength = [aLine length];

        if(lineLength > 0){
            BOOL		isCommented;
            unsigned	startIndex, endIndex;
            unsigned	j = 0;
            NSString	*aValue;

            // Trim spacers
            for(; j < lineLength; j++)
                if(!isspace([aLine characterAtIndex:j]))
                    break;
            if(j >= lineLength)
                continue;
            isCommented = ([aLine characterAtIndex:j] == '#');

            if(isCommented && (lineLength - j) == 1)
                continue;

            if(isCommented && isspace([aLine characterAtIndex:j + 1]))
                // A line beginning with a # followed by a spacer is considered as a comment for GPGPreferences
                continue;
            // else _we_ consider it as a disabled option
            // Note that if an option value begins or ends with a space, or contains a carriage return,
            // then it must be double-quoted, or \n must be escaped

            // Option name terminates at the first non spacer character or at the end of line

            // First we skip prepending spaces
            for(startIndex = j + (isCommented ? 1:0); startIndex < lineLength; startIndex++){
                if(!isspace([aLine characterAtIndex:startIndex]))
                    break;
            }
            if(startIndex >= lineLength)
                continue;
            // and find the end of the word
            for(endIndex = startIndex + 1; endIndex < lineLength; endIndex++){
                if(isspace([aLine characterAtIndex:endIndex]))
                    break;
            }

            [optionNames addObject:[aLine substringWithRange:NSMakeRange(startIndex, endIndex - startIndex)]];
            [optionLineNumbers addObject:[NSNumber numberWithUnsignedInt:i]];
            [optionStates addObject:[NSNumber numberWithBool:!isCommented]];

            // Now we skip spaces between name and value
            for(startIndex = endIndex + 1; startIndex < lineLength; startIndex++){
                if(!isspace([aLine characterAtIndex:startIndex]))
                    break;
            }
            if(startIndex >= lineLength){
                // No value, only an option name
                [optionValues addObject:@""];
                continue;
            }
            // and find the end of the value, backwards
            for(endIndex = lineLength - 1; endIndex > startIndex; endIndex--){
                if(!isspace([aLine characterAtIndex:endIndex]))
                    break;
            }
            aValue = [aLine substringWithRange:NSMakeRange(startIndex, endIndex - startIndex + 1)];
            if([aValue characterAtIndex:0] == '"' && [aValue length] > 1 && [aValue characterAtIndex:[aValue length] - 1] == '"')
                aValue = [aValue substringWithRange:NSMakeRange(1, [aValue length] - 2)]; // We unquote it
            [optionValues addObject:aValue];
        }
    }
}

- (void) reloadOptions
/*"
 * Re-reads %GnuPG's configuration file. If user changed %GnuPG's %{home}
 * %{directory} without logging out and in, options might be not yet active,
 * and changes won't be taken in account before logging out and in.
"*/
{
    NSString	*filename = [[self class] optionsFilename];
    NSString	*optionsAsString;
    NSData		*fileData;
    BOOL		wasInUnicode = NO;

    [optionFileLines removeAllObjects];
    [optionNames removeAllObjects];
    [optionValues removeAllObjects];
    [optionStates removeAllObjects];
    [optionLineNumbers removeAllObjects];

    fileData = [[NSData alloc] initWithContentsOfFile:filename];
    // Check whether file has been saved as Unicode (it shouldn't, but who knows...)
    if([fileData length] >= 2 && !([fileData length] & 1) && (((short int *)[fileData bytes])[0] == (short int)0xFEFF || ((short int *)[fileData bytes])[0] == (short int)0x0FFFE)){
        optionsAsString = [[NSString alloc] initWithData:fileData encoding:NSUnicodeStringEncoding];
        wasInUnicode = YES;
    }
    else
        optionsAsString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    [fileData release];
    if(optionsAsString == nil){
        NSLog(@"GPGPreferences: Unable to read file %@", filename);
        // If we were unable to read it, gpg is probably unable too
        optionsAsString = @"";
    }

    [self parseOptionsFromLines:[optionsAsString componentsSeparatedByString:@"\n"] save:wasInUnicode];
    [optionsAsString release];
    hasModifications = NO;
}

- (NSArray *) optionLines
{
    return optionFileLines;
}

- (id) init
/*"
 * Default initializer.
"*/
{
    if(self = [super init]){
        optionFileLines = [[NSMutableArray alloc] initWithCapacity:100];
        optionNames = [[NSMutableArray alloc] initWithCapacity:20];
        optionValues = [[NSMutableArray alloc] initWithCapacity:20];
        optionStates = [[NSMutableArray alloc] initWithCapacity:20];
        optionLineNumbers = [[NSMutableArray alloc] initWithCapacity:20];
        
        [self reloadOptions];
    }

    return self;
}

- (void) dealloc
{
    [optionFileLines release];
    [optionNames release];
    [optionValues release];
    [optionStates release];
    [optionLineNumbers release];
    
    [super dealloc];
}

- (void) doSaveOptions
{
    NSString	*filename = [[self class] optionsFilename];
    NSString	*content = [optionFileLines componentsJoinedByString:@"\n"];
    
    if(![content hasSuffix:@"\n"])
        content = [content stringByAppendingString:@"\n"];

    NSAssert1([[content dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filename atomically:YES], @"Unable to save options in %@", filename);
}

- (void) saveOptions
/*"
 * Save options by writing file back. Note that if user changed %GnuPG's %home
 * %directory without logging out and in, new options might be not yet valid.
"*/
{
#warning TODO: Save only if modified
    [self doSaveOptions];
#warning TODO: Test new options file by running gpg (gpg: /Users/kindov/.gnupg/options:21: invalid option)
    [self reloadOptions];
}

- (NSString *) normalizedValue:(NSString *)value
{
    // Replace \n occurences by \\n
    // Enclose with double-quotes if necessary
    if(value == nil)
        return value;
    else{
        NSMutableString	*newValue = [NSMutableString stringWithString:value];
        int				i;
        BOOL			needsDoubleQuotes = NO;
        BOOL			isLastChar = YES;

        for(i = [newValue length] - 1; i >= 0; i--){
            unichar	aChar = [newValue characterAtIndex:i];
            
            if(isLastChar){
                isLastChar = NO;
                needsDoubleQuotes = isspace(aChar);
            }
            if(aChar == '\n')
                [newValue replaceCharactersInRange:NSMakeRange(i, 1) withString:@"\\n"];
            else if(i == 0)
                needsDoubleQuotes = (needsDoubleQuotes || isspace(aChar));
        }

        if(needsDoubleQuotes)
            newValue = [NSString stringWithFormat:@"\"%@\"", newValue];

        return newValue;
    }
}

- (void) updateOptionLineAtIndex:(unsigned)index
{
    NSString	*newLine = [NSString stringWithFormat:@"%@%@ %@", ([[optionStates objectAtIndex:index] boolValue] ? @"":@"#"), [optionNames objectAtIndex:index], [optionValues objectAtIndex:index]];
    
    [optionFileLines replaceObjectAtIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] withObject:newLine];
}

- (void) setOptionValue:(NSString *)value atIndex:(unsigned)index
/*"
 *
"*/
{
    [optionValues replaceObjectAtIndex:index withObject:[self normalizedValue:value]];
    [self updateOptionLineAtIndex:index];
}

- (void) setEmptyOptionValueAtIndex:(unsigned)index
/*"
 *
"*/
{
    [self setOptionValue:@"\"\"" atIndex:index];
}

- (void) setOptionName:(NSString *)name atIndex:(unsigned)index
/*"
 *
"*/
{
    [optionNames replaceObjectAtIndex:index withObject:name];
    [self updateOptionLineAtIndex:index];
}

- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index
/*"
 *
"*/
{
    [optionStates replaceObjectAtIndex:index withObject:[NSNumber numberWithBool:flag]];
    [self updateOptionLineAtIndex:index];
}

- (void) addOptionNamed:(NSString *)name
/*"
 * Adds a new option named name, not active, with an empty value.
"*/
{
    [optionNames addObject:name];
    [optionValues addObject:@""];
    [optionStates addObject:[NSNumber numberWithBool:NO]];
    [optionLineNumbers addObject:[NSNumber numberWithUnsignedInt:[optionFileLines count]]];
    [optionFileLines addObject:[@"#" stringByAppendingString:name]];
}

- (void) addOptionNamed:(NSString *)name value:(NSString *)value state:(BOOL)state
/*"
 * Adds a new option named name, with an value and state. Does not disable 
 * existing options with save name. Use it only when option can appear multiple 
 * times.
"*/
{
    [optionNames addObject:name];
    [optionValues addObject:value];
    [optionStates addObject:[NSNumber numberWithBool:state]];
    [optionLineNumbers addObject:[NSNumber numberWithUnsignedInt:[optionFileLines count]]];
    [optionFileLines addObject:[NSString stringWithFormat:@"%@%@ %@", (state ? @"":@"#"), name, value]];
}

- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index
/*"
 *
"*/
{
    unsigned	maxIndex = [optionNames count];
    
    [optionNames insertObject:name atIndex:index];
    [optionValues insertObject:@"" atIndex:index];
    [optionStates insertObject:[NSNumber numberWithBool:NO] atIndex:index];
    [optionFileLines insertObject:[@"#" stringByAppendingString:name] atIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue]];
    [optionLineNumbers insertObject:[optionLineNumbers objectAtIndex:index] atIndex:index];

    for(index++, maxIndex++; index < maxIndex; index++)
        [optionLineNumbers replaceObjectAtIndex:index withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] + 1]];
}

- (void) removeOptionAtIndex:(unsigned)index
/*"
 *
"*/
{
    unsigned	maxIndex = [optionNames count];
    
    [optionNames removeObjectAtIndex:index];
    [optionValues removeObjectAtIndex:index];
    [optionFileLines removeObjectAtIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue]];
    [optionLineNumbers removeObjectAtIndex:index];
    [optionStates removeObjectAtIndex:index];

    for(maxIndex--; index < maxIndex; index++)
        [optionLineNumbers replaceObjectAtIndex:index withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] - 1]];
}

- (NSArray *) optionNames
/*"
 * Returns all option names, active or not. The same option name can appear
 * multiple times.
"*/
{
    return optionNames;
}

- (NSArray *) optionValues
/*"
 * Returns all option values, active or not. There are as many option values
 * as option names returned by #{-optionNames}.
"*/
{
    return optionValues;
}

- (NSArray *) optionStates
/*"
 * Returns all option states as an array of NSNumber instances (boolean
 * values). There are as many option states as option names returned by
 * #{-optionNames}.
"*/
{
    return optionStates;
}

- (NSString *) optionValueForName:(NSString *)name
/*"
 * Returns the option value named name, used by %GnuPG. In case of multiple
 * occurences of the a named option, returns the used one. Note that option
 * might be inactive!
"*/
{
    int			anIndex = [optionNames count] - 1;
    NSString	*lastValue = nil;
    BOOL		lastValueIsActive = NO;

    for(; anIndex >= 0; anIndex--)
        if([[optionNames objectAtIndex:anIndex] isEqualToString:name]){
            if(lastValue == nil){
                lastValue = [optionValues objectAtIndex:anIndex];
                lastValueIsActive = [[optionStates objectAtIndex:anIndex] boolValue];
            }
            else if(!lastValueIsActive && [[optionStates objectAtIndex:anIndex] boolValue]){
                lastValue = [optionValues objectAtIndex:anIndex];
                lastValueIsActive = YES;
            }
        }
    return lastValue;
}

- (NSArray *) optionValuesForName:(NSString *)name activeOnly:(BOOL)activeOnly
/*"
 *
"*/
{
    int				anIndex = 0;
    int				max = [optionNames count];
    NSMutableArray	*values = [NSMutableArray array];

    for(; anIndex < max; anIndex++)
        if([[optionNames objectAtIndex:anIndex] isEqualToString:name] && (!activeOnly || [[optionStates objectAtIndex:anIndex] boolValue]))
            [values addObject:[optionValues objectAtIndex:anIndex]];

    return values;
}

- (NSArray *) activeOptionValuesForName:(NSString *)name
/*"
 * Returns all values set for this option name, providing that option
 * is active. First value is the used value, in case no more than one
 * value is considered by GnuPG.
"*/
{
    return [self optionValuesForName:name activeOnly:YES];
}

- (NSArray *) allOptionValuesForName:(NSString *)name
/*"
 *
"*/
{
    return [self optionValuesForName:name activeOnly:NO];
}

- (void) setEmptyOptionValueForName:(NSString *)name
/*"
 *
"*/
{
    [self setOptionValue:@"\"\"" forName:name];
}

- (void) setOptionValue:(NSString *)value forName:(NSString *)name
/*"
 *
"*/
{
    int	anIndex = 0, maxIndex = [optionNames count];
    int	deletedLineNumber = -1;

    value = [self normalizedValue:value];
    for(; anIndex < maxIndex; anIndex++){
        if(deletedLineNumber > 0)
            [optionLineNumbers replaceObjectAtIndex:anIndex withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:anIndex] unsignedIntValue] - deletedLineNumber]];

        if([[optionNames objectAtIndex:anIndex] isEqualToString:name]){
            deletedLineNumber++;
            if(value == nil || deletedLineNumber > 0){
                if(deletedLineNumber == 0)
                    deletedLineNumber++;
                [optionFileLines removeObjectAtIndex:[[optionLineNumbers objectAtIndex:anIndex] unsignedIntValue]];
                [optionNames removeObjectAtIndex:anIndex];
                [optionStates removeObjectAtIndex:anIndex];
                [optionValues removeObjectAtIndex:anIndex];
                [optionLineNumbers removeObjectAtIndex:anIndex];
                anIndex--;
                maxIndex--;
            }
            else{
                [optionValues replaceObjectAtIndex:anIndex withObject:value];
                [self updateOptionLineAtIndex:anIndex];
            }
        }
    }
    if(deletedLineNumber < 0 && value != nil){
        [optionNames addObject:name];
        [optionStates addObject:[NSNumber numberWithBool:YES]];
        [optionValues addObject:value];
        [optionLineNumbers addObject:[NSNumber numberWithUnsignedInt:[optionFileLines count]]];
        [optionFileLines addObject:[NSString stringWithFormat:@"%@ %@", name, value]];
    }
}

- (BOOL) optionStateForName:(NSString *)name
/*"
 *
"*/
{
    int	anIndex = [optionNames count] - 1;

    for(; anIndex >= 0; anIndex--)
        if([[optionNames objectAtIndex:anIndex] isEqualToString:name])
            if([[optionStates objectAtIndex:anIndex] boolValue])
                return YES;
    return NO;
}

- (void) setOptionState:(BOOL)state forName:(NSString *)name
/*"
 *
"*/
{
    int	anIndex = 0, maxIndex = [optionNames count];
    int	deletedLineNumber = -1;

    for(; anIndex < maxIndex; anIndex++){
        if(deletedLineNumber > 0)
            [optionLineNumbers replaceObjectAtIndex:anIndex withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:anIndex] unsignedIntValue] - deletedLineNumber]];

        if([[optionNames objectAtIndex:anIndex] isEqualToString:name]){
            deletedLineNumber++;
            if(deletedLineNumber > 0){
                [optionFileLines removeObjectAtIndex:[[optionLineNumbers objectAtIndex:anIndex] unsignedIntValue]];
                [optionNames removeObjectAtIndex:anIndex];
                [optionStates removeObjectAtIndex:anIndex];
                [optionValues removeObjectAtIndex:anIndex];
                [optionLineNumbers removeObjectAtIndex:anIndex];
                maxIndex--;
            }
            else{
                [optionStates replaceObjectAtIndex:anIndex withObject:[NSNumber numberWithBool:state]];
                [self updateOptionLineAtIndex:anIndex];
            }
        }
    }

    if(deletedLineNumber == -1 && state)
        [self setOptionValue:@"" forName:name];
}

- (NSArray *) _subOptionsForName:(NSString *)optionName
{
    NSString		*subOptionsString = [self optionValueForName:optionName];
    NSArray			*optionParameters = [subOptionsString componentsSeparatedByString:@","];
    NSEnumerator	*anEnum = [optionParameters objectEnumerator];
    NSMutableArray	*subOptions = [NSMutableArray array];
    NSString		*aString;

    while(aString = [anEnum nextObject])
        [subOptions addObjectsFromArray:[aString componentsSeparatedByString:@" "]];
    [subOptions removeObject:@""]; // Removes all occurences

    return subOptions;
}

- (BOOL) subOptionState:(NSString *)subOptionName forName:(NSString *)optionName
/*"
 * Returns subOptionName sub-option's state, in option named optionName.
"*/
{
    if([self optionStateForName:optionName]){
        NSArray	*optionParameters;
        int		setIndex, unsetIndex;

        optionParameters = [[[self _subOptionsForName:optionName] reverseObjectEnumerator] allObjects]; // Reversed array

        setIndex = [optionParameters indexOfObject:subOptionName];
        unsetIndex = [optionParameters indexOfObject:[@"no-" stringByAppendingString:subOptionName]];

        return (setIndex < unsetIndex);
    }
    else
        // In fact we should return the default value...
        return NO;
}

- (void) setSubOption:(NSString *)subOptionName state:(BOOL)state forName:(NSString *)optionName
/*"
 * Sets subOptionName sub-option's state, in option named optionName. 
"*/
{
    NSString		*disabledSubOptionName = [@"no-" stringByAppendingString:subOptionName];
    NSMutableArray	*subOptions = [NSMutableArray arrayWithArray:[self _subOptionsForName:optionName]];
    
    [subOptions removeObject:disabledSubOptionName];
    [subOptions removeObject:subOptionName];
    [subOptions addObject:(state ? subOptionName:disabledSubOptionName)];
    [self setOptionValue:[subOptions componentsJoinedByString:@","] forName:optionName];
    [self setOptionState:YES forName:optionName];
}

- (unsigned) moveOptionsAtIndexes:(NSArray *)indexes toIndex:(unsigned)index
/*"
 * Reorders options at indexes to new index. Returns new index.
"*/
{
    NSEnumerator	*anEnum = [indexes objectEnumerator];
    NSNumber		*anIndex;
    NSMutableArray	*lineIndexes = [NSMutableArray arrayWithCapacity:[indexes count]];
    unsigned		lineIndex;

    while(anIndex = [anEnum nextObject])
        [lineIndexes addObject:[optionLineNumbers objectAtIndex:[anIndex unsignedIntValue]]];
    if(index == [optionLineNumbers count])
        lineIndex = [optionFileLines count];
    else
        lineIndex = [[optionLineNumbers objectAtIndex:index] unsignedIntValue];
    lineIndex = [optionFileLines gpgMoveObjectsAtIndexes:lineIndexes toIndex:lineIndex];
    hasModifications = YES;
    [self saveOptions];

    return [optionLineNumbers indexOfObject:[NSNumber numberWithUnsignedInt:lineIndex]];
}

+ (NSString *) _gnupgVersion
{
    // Returns cached value, if any, else get version
    if(gnupgVersion == nil)
        return [self gnupgVersion];
    else
        return gnupgVersion;
}

+ (NSString *) outputFromGPGTaskWithArgument:(NSString *)argument
{
    NSTask		*aTask = [[NSTask alloc] init];
    NSPipe		*aPipe = [NSPipe pipe];
    NSString	*outputString = nil;

    [aTask setLaunchPath:[self gpgPath]];
    [aTask setArguments:[NSArray arrayWithObjects:@"--utf8-strings", @"--charset", @"utf8", argument, nil]];
    [aTask setStandardOutput:aPipe];

    NS_DURING
        NSData	*outputData;
        NSRange	aRange;

        [aTask launch];
//        outputData = [[aPipe fileHandleForReading] readDataToEndOfFile]; // No longer working in all cases:
//        *** -[NSConcreteFileHandle readDataOfLength:]: Interrupted system call
        [aTask waitUntilExit];
        outputData = [[aPipe fileHandleForReading] readDataToEndOfFile]; // Reading data after waitUntilExit will not block process as long as data to read does not exceed pipe buffer size, I think. If it does, maybe use readDataToEndOfFileAndNotify?

        outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        // Patch! Seems that translated strings are not displayed using passed encoding, but using ISOLatin1!
        if(outputString == nil)
            outputString = [[NSString alloc] initWithData:outputData encoding:NSISOLatin1StringEncoding];
        aRange = [outputString lineRangeForRange:NSMakeRange(0, [outputString length])];
        aRange = [outputString lineRangeForRange:NSMakeRange(aRange.location, [outputString length] - aRange.location)];
        outputString = [[outputString autorelease] substringWithRange:aRange];
        if([aTask terminationStatus] != 0)
            [NSException raise:NSGenericException format:@"### GPGOptions: error %d during execution of '%@ %@'", [aTask terminationStatus], [aTask launchPath], [[aTask arguments] componentsJoinedByString:@" "]];
    NS_HANDLER
        NSLog(@"### GPGOptions: error during execution of '%@ %@': %@ %@", [aTask launchPath], [[aTask arguments] componentsJoinedByString:@" "], localException, [localException userInfo]);
        [aTask release];
        [localException raise];
    NS_ENDHANDLER

    [aTask release];

    return outputString;
}

+ (NSString *) gnupgVersion
/*"
 * Returns current %GnuPG version, or raises an exception when %GnuPG
 * executable cannot be found or returned an error.
"*/
{
    NSString		*aVersion = nil;
    NSString		*oldVersion = gnupgVersion;

    /*
#ifdef BUILDINGGPGME
    NSEnumerator	*anEnum = [[GPGEngine availableEngines] objectEnumerator];
    GPGEngine		*anEngine;

    while(anEngine = [anEnum nextObject]){
        if([anEngine engineProtocol] == GPGOpenPGPProtocol){
            aVersion = [anEngine version];
            break;
        }
    }
    if(aVersion == nil)
#endif
     */
    aVersion = [self outputFromGPGTaskWithArgument:@"--version"];
    
    gnupgVersion = [aVersion retain];
    [oldVersion release];

    return gnupgVersion;
}

@end

@implementation NSMutableArray(GPGOptions)

- (unsigned) gpgMoveObjectsAtIndexes:(NSArray *)indexes toIndex:(unsigned)targetIndex
{
    NSEnumerator	*anEnum;
    NSNumber		*anIndex;
    NSArray			*originalArray = [NSArray arrayWithArray:self];
    unsigned		lowerOffset = 0, upperOffset = 0;
    BOOL			adding = (targetIndex == [self count]);
    unsigned		newIndex = targetIndex;
    
    indexes = [indexes sortedArrayUsingSelector:@selector(compare:)];
    anEnum = [indexes objectEnumerator];
    while(anIndex = [anEnum nextObject]){
        if(adding)
            [self addObject:[originalArray objectAtIndex:[anIndex unsignedIntValue]]];
        else
            [self insertObject:[originalArray objectAtIndex:[anIndex unsignedIntValue]] atIndex:(targetIndex + upperOffset)];
        upperOffset++;
    }
    anEnum = [indexes objectEnumerator];
    while(anIndex = [anEnum nextObject]){
        unsigned	index = [anIndex unsignedIntValue];

        if(index < targetIndex){
            [self removeObjectAtIndex:index + lowerOffset];
            newIndex--;
            lowerOffset--;
        }
        else{    
            [self removeObjectAtIndex:index + upperOffset + lowerOffset];
            upperOffset--;
        }
    }

    return newIndex;
}

@end
