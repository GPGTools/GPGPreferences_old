//
//  GPGOptions.m
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

#import "GPGOptions.h"


@implementation GPGOptions

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
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@".gnupg"];
}

+ (NSString *) currentHomeDirectory
{
    NSString	*homeDirectory = [self currentEnvironmentVariableValueForName:@"GNUPGHOME"];

    if(homeDirectory == nil)
        return [self defaultHomeDirectory];
    else
        return homeDirectory;
}

+ (NSString *) homeDirectory
{
    NSString	*homeDirectory = [self futureEnvironmentVariableValueForName:@"GNUPGHOME"];

    if(homeDirectory == nil)
        return [self defaultHomeDirectory];
    else
        return homeDirectory;
}

+ (void) setHomeDirectory:(NSString *)homeDirectory
{
    if(homeDirectory != nil && [homeDirectory rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].length > 0)
        [self setFutureEnvironmentVariableValue:homeDirectory forName:@"GNUPGHOME"];
    else
        [self setFutureEnvironmentVariableValue:nil forName:@"GNUPGHOME"];
}

+ (BOOL) homeDirectoryChanged
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
{
    NSString	*httpProxy = [self currentEnvironmentVariableValueForName:@"http_proxy"];

    return httpProxy;
}

+ (NSString *) httpProxy
{
    NSString	*httpProxy = [self futureEnvironmentVariableValueForName:@"http_proxy"];

    return httpProxy;
}

+ (void) setHttpProxy:(NSString *)httpProxy
{
    if([httpProxy rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length > 0)
        [self setFutureEnvironmentVariableValue:httpProxy forName:@"http_proxy"];
    else
        [self setFutureEnvironmentVariableValue:nil forName:@"http_proxy"];
}

+ (BOOL) httpProxyChanged
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
{
    return @"/usr/local/bin/gpg";
}

+ (NSString *) optionsFilename
{
    return [[self homeDirectory] stringByAppendingPathComponent:@"options"];
}

- (void) reloadOptions
{
    NSString	*filename = [[self class] optionsFilename];
    unsigned	i, lineCount;
    NSString	*optionsAsString;

    [optionFileLines removeAllObjects];
    [optionNames removeAllObjects];
    [optionValues removeAllObjects];
    [optionStates removeAllObjects];
    [optionLineNumbers removeAllObjects];

    optionsAsString = [[NSString alloc] initWithData:[[[NSData alloc] initWithContentsOfFile:filename] autorelease] encoding:NSUTF8StringEncoding];
    NSAssert1(optionsAsString != nil, @"No file at path %@", filename);
    // Check that encoding was UTF8 (or ASCII)

    [optionFileLines setArray:[optionsAsString componentsSeparatedByString:@"\n"]];
    lineCount = [optionFileLines count];
    for(i = 0; i < lineCount; i++){
        NSString	*aLine = [optionFileLines objectAtIndex:i];
        unsigned	lineLength = [aLine length];

        if(lineLength > 0){
            BOOL		isCommented = ([aLine characterAtIndex:0] == '#');
            unsigned	startIndex, endIndex;

            if(isCommented && lineLength == 1)
                continue;

            if(isCommented && isspace([aLine characterAtIndex:1]))
                // A line beginning with a # followed by a space (and ...) is considered as a comment
                continue;
            // else we consider it as a disabled option
            // Note that an option value cannot begin or end with a space, nor can it contain a carriage return.

            // Option name terminates at the first non spacer character or at end of line

            // First we skip prepending spaces
            for(startIndex = (isCommented ? 1:0); startIndex < lineLength; startIndex++){
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
            [optionValues addObject:[aLine substringWithRange:NSMakeRange(startIndex, endIndex - startIndex + 1)]];

        }
    }
    [optionsAsString release];
    hasModifications = NO;
}

- (id) init
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

- (void) saveOptions
{
#warning TODO: Save only if modified
    NSString	*filename = [[self class] optionsFilename];

    NSAssert1([[optionFileLines componentsJoinedByString:@"\n"] writeToFile:filename atomically:YES], @"Unable to save options in %@", filename);
#warning TODO: Test new options file by running gpg (gpg: /Users/kindov/.gnupg/options:21: invalid option)
    [self reloadOptions];
}

- (void) updateOptionLineAtIndex:(unsigned)index
{
    NSString	*newLine = [NSString stringWithFormat:@"%@%@ %@", ([[optionStates objectAtIndex:index] boolValue] ? @"":@"#"), [optionNames objectAtIndex:index], [optionValues objectAtIndex:index]];
    
    [optionFileLines replaceObjectAtIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] withObject:newLine];
}

- (void) setOptionValue:(NSString *)value atIndex:(unsigned)index
{
    [optionValues replaceObjectAtIndex:index withObject:value];
    [self updateOptionLineAtIndex:index];
}

- (void) setOptionName:(NSString *)name atIndex:(unsigned)index
{
    [optionNames replaceObjectAtIndex:index withObject:name];
    [self updateOptionLineAtIndex:index];
}

- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index
{
    [optionStates replaceObjectAtIndex:index withObject:[NSNumber numberWithBool:flag]];
    [self updateOptionLineAtIndex:index];
}

- (void) addOptionNamed:(NSString *)name
{
    [optionNames addObject:name];
    [optionValues addObject:@""];
    [optionStates addObject:[NSNumber numberWithBool:NO]];
    [optionLineNumbers addObject:[NSNumber numberWithUnsignedInt:[optionFileLines count]]];
    [optionFileLines addObject:[@"#" stringByAppendingString:name]];
}

- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index
{
    int	maxIndex = [optionNames count];
    
    [optionNames insertObject:name atIndex:index];
    [optionValues insertObject:@"" atIndex:index];
    [optionStates insertObject:[NSNumber numberWithBool:NO] atIndex:index];
    [optionFileLines insertObject:[@"#" stringByAppendingString:name] atIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue]];
    [optionLineNumbers insertObject:[optionLineNumbers objectAtIndex:index] atIndex:index];

    for(index++, maxIndex++; index < maxIndex; index++)
        [optionLineNumbers replaceObjectAtIndex:index withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] + 1]];
}

- (void) removeOptionAtIndex:(unsigned)index
{
    int	maxIndex = [optionNames count];
    
    [optionNames removeObjectAtIndex:index];
    [optionValues removeObjectAtIndex:index];
    [optionFileLines removeObjectAtIndex:[[optionLineNumbers objectAtIndex:index] unsignedIntValue]];
    [optionLineNumbers removeObjectAtIndex:index];
    [optionStates removeObjectAtIndex:index];

    for(maxIndex--; index < maxIndex; index++)
        [optionLineNumbers replaceObjectAtIndex:index withObject:[NSNumber numberWithUnsignedInt:[[optionLineNumbers objectAtIndex:index] unsignedIntValue] - 1]];
}

- (NSArray *) optionNames
{
    return optionNames;
}

- (NSArray *) optionValues
{
    return optionValues;
}

- (NSArray *) optionStates
{
    return optionStates;
}

- (NSString *) optionValueForName:(NSString *)name
{
    int	anIndex = [optionNames count] - 1;

    for(; anIndex >= 0; anIndex--)
        if([[optionNames objectAtIndex:anIndex] isEqualToString:name])
            return [optionValues objectAtIndex:anIndex];
    return nil;
}

- (void) setOptionValue:(NSString *)value forName:(NSString *)name
{
    int	anIndex = 0, maxIndex = [optionNames count];
    int	deletedLineNumber = -1;

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
{
    int	anIndex = [optionNames count] - 1;

    for(; anIndex >= 0; anIndex--)
        if([[optionNames objectAtIndex:anIndex] isEqualToString:name])
            return [[optionStates objectAtIndex:anIndex] boolValue];
    return NO;
}

- (void) setOptionState:(BOOL)state forName:(NSString *)name
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

@end
