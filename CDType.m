// This file is part of APPNAME, SHORT DESCRIPTION
// Copyright (C) 2003 Steve Nygard.  All rights reserved.

#import "CDType.h"

#import <Foundation/Foundation.h>
#import "NSString-Extensions.h"
#import "CDTypeLexer.h" // For T_NAMED_OBJECT

@implementation CDType

- (id)init;
{
    if ([super init] == nil)
        return nil;

    type = 0; // ??
    subtype = nil;
    typeName = nil;
    members = nil;
    variableName = nil;
    bitfieldSize = nil;
    arraySize = nil;

    return self;
}

- (id)initSimpleType:(int)aTypeCode;
{
    if ([self init] == nil)
        return nil;

    if (aTypeCode == '*') {
        type = '^';
        subtype = [[CDType alloc] initSimpleType:'c'];
    } else {
        type = aTypeCode;
    }

    return self;
}

- (id)initIDType:(NSString *)aName;
{
    if ([self init] == nil)
        return nil;

    if (aName != nil) {
        type = '^';
        subtype = [[CDType alloc] initNamedType:aName];
    } else {
        type = '@';
    }

    return self;
}

- (id)initNamedType:(NSString *)aName;
{
    if ([self init] == nil)
        return nil;

    type = T_NAMED_OBJECT;
    typeName = [aName retain];

    return self;
}

- (id)initStructType:(NSString *)aName members:(NSArray *)someMembers;
{
    if ([self init] == nil)
        return nil;

    type = '{';
    typeName = [aName retain];
    members = [someMembers retain];

    return self;
}

- (id)initUnionType:(NSString *)aName members:(NSArray *)someMembers;
{
    if ([self init] == nil)
        return nil;

    type = '(';
    typeName = [aName retain];
    members = [someMembers retain];

    return self;
}

- (id)initBitfieldType:(NSString *)aBitfieldSize;
{
    if ([self init] == nil)
        return nil;

    type = 'b';
    bitfieldSize = [aBitfieldSize retain];

    return self;
}

- (id)initArrayType:(CDType *)aType count:(NSString *)aCount;
{
    if ([self init] == nil)
        return nil;

    type = '[';
    arraySize = [aCount retain];
    subtype = [aType retain];

    return self;
}

- (id)initPointerType:(CDType *)aType;
{
    if ([self init] == nil)
        return nil;

    type = '^';
    subtype = [aType retain];

    return self;
}

- (id)initModifier:(int)aModifier type:(CDType *)aType;
{
    if ([self init] == nil)
        return nil;

    type = aModifier;
    subtype = [aType retain];

    return self;
}

- (void)dealloc;
{
    [subtype release];
    [typeName release];
    [members release];
    [variableName release];
    [bitfieldSize release];
    [arraySize release];

    [super dealloc];
}

- (NSString *)variableName;
{
    return variableName;
}

- (void)setVariableName:(NSString *)newVariableName;
{
    if (newVariableName == variableName)
        return;

    [variableName release];
    variableName = [newVariableName retain];
}

- (int)type;
{
    return type;
}

- (BOOL)isIDType;
{
    return type == '@' && typeName == nil;
}

- (BOOL)isModifierType;
{
    return type == 'r' || type == 'n' || type == 'N' || type == 'o' || type == 'O' || type == 'R' || type == 'V';
}

- (int)typeIgnoringModifiers;
{
    if ([self isModifierType] == YES && subtype != nil)
        return [subtype typeIgnoringModifiers];

    return type;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"[%@] type: %d('%c'), name: %@, subtype: %@, bitfieldSize: %@, arraySize: %@, members: %@, variableName: %@",
                     NSStringFromClass([self class]), type, type, typeName, subtype, bitfieldSize, arraySize, members, variableName];
}

- (NSString *)formattedString:(NSString *)previousName expand:(BOOL)shouldExpand level:(int)level;
{
    NSString *result, *currentName;
    NSString *baseType, *memberString;

    assert(variableName == nil || previousName == nil);
    if (variableName != nil)
        currentName = variableName;
    else
        currentName = previousName;

    switch (type) {
      case T_NAMED_OBJECT:
          assert(typeName != nil);
          if (currentName == nil)
              result = typeName;
          else
              result = [NSString stringWithFormat:@"%@ %@", typeName, currentName];
          break;

      case '@':
          if (currentName == nil)
              result = @"id";
          else
              result = [NSString stringWithFormat:@"id %@", currentName];
          break;

      case 'b':
          if (currentName == nil)
              result = [NSString stringWithFormat:@"int :%@", bitfieldSize]; // I don't expect this to happen
          else
              result = [NSString stringWithFormat:@"int %@:%@", currentName, bitfieldSize];
          break;

      case '[':
          if (currentName == nil)
              result = [NSString stringWithFormat:@"[%@]", arraySize];
          else
              result = [NSString stringWithFormat:@"%@[%@]", currentName, arraySize];

          result = [subtype formattedString:result expand:shouldExpand level:level];
          break;

      case '(':
          if (typeName == nil)
              baseType = @"union";
          else
              baseType = [NSString stringWithFormat:@"union %@", typeName];

          if (shouldExpand == YES && [members count] > 0) // TODO: What about a struct with no members, though?
              memberString = [NSString stringWithFormat:@" {\n%@%@}",
                                       [self formattedStringForMembersAtLevel:level + 1], [NSString spacesIndentedToLevel:level spacesPerLevel:4]];
          else
              memberString = @"";

          baseType = [baseType stringByAppendingString:memberString];

          if (currentName == nil || [currentName hasPrefix:@"?"] == YES) // Not sure about this
              result = baseType;
          else
              result = [NSString stringWithFormat:@"%@ %@", baseType, currentName];
          break;

      case '{':
          if (typeName == nil)
              baseType = @"struct";
          else
              baseType = [NSString stringWithFormat:@"struct %@", typeName];

          if (shouldExpand == YES && [members count] > 0)
              memberString = [NSString stringWithFormat:@" {\n%@%@}",
                                       [self formattedStringForMembersAtLevel:level + 1], [NSString spacesIndentedToLevel:level spacesPerLevel:4]];
          else
              memberString = @"";

          baseType = [baseType stringByAppendingString:memberString];

          if (currentName == nil || [currentName hasPrefix:@"?"] == YES) // Not sure about this
              result = baseType;
          else
              result = [NSString stringWithFormat:@"%@ %@", baseType, currentName];
          break;

      case '^':
          if (currentName == nil)
              result = @"*";
          else
              result = [@"*" stringByAppendingString:currentName];

          if (subtype != nil && [subtype type] == '[')
              result = [NSString stringWithFormat:@"(%@)", result];

          result = [subtype formattedString:result expand:shouldExpand level:level];
          break;

      case 'r':
      case 'n':
      case 'N':
      case 'o':
      case 'O':
      case 'R':
      case 'V':
          result = [NSString stringWithFormat:@"%@ %@",
                             [self formattedStringForSimpleType], [subtype formattedString:currentName expand:shouldExpand level:level]];
          break;

      default:
          if (currentName == nil)
              result = [self formattedStringForSimpleType];
          else
              result = [NSString stringWithFormat:@"%@ %@", [self formattedStringForSimpleType], currentName];
          break;
    }

    return result;
}

- (NSString *)formattedStringForMembersAtLevel:(int)level;
{
    NSMutableString *str;
    int count, index;

    assert(type == '{' || type == '(');
    str = [NSMutableString string];

    count = [members count];
    for (index = 0; index < count; index++) {
        [str appendString:[NSString spacesIndentedToLevel:level spacesPerLevel:4]];
        [str appendString:[[members objectAtIndex:index] formattedString:nil expand:YES level:level]];
        [str appendString:@";\n"];
    }

    return str;
}

- (NSString *)formattedStringForSimpleType;
{
    // Ugly but simple:
    switch (type) {
      case 'c': return @"char";
      case 'i': return @"int";
      case 's': return @"short";
      case 'l': return @"long";
      case 'q': return @"long long";
      case 'C': return @"unsigned char";
      case 'I': return @"unsigned int";
      case 'S': return @"unsigned short";
      case 'L': return @"unsigned long";
      case 'Q': return @"unsigned long long";
      case 'f': return @"float";
      case 'd': return @"double";
      case 'B': return @"_Bool"; /* C99 _Bool or C++ bool */
      case 'v': return @"void";
      case '*': return @"STR";
      case '#': return @"Class";
      case ':': return @"SEL";
      case '%': return @"NXAtom";
          //case '?': return @"void /*UNKNOWN*/";
      case '?': return @"UNKNOWN"; // For easier regression testing.  TODO (2003-12-14): Change this back to void
      case 'r': return @"const";
      case 'n': return @"in";
      case 'N': return @"inout";
      case 'o': return @"out";
      case 'O': return @"bycopy";
      case 'R': return @"byref";
      case 'V': return @"oneway";
      default:
          break;
    }

    return nil;
}

@end