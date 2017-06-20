//
//  CUPUserNameFormatter.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-19.
//  Copyright (c) 2012 Per Olofsson. All rights reserved.
//

#import "CUPUserNameFormatter.h"

@interface CUPUserNameFormatter ()
@property NSMutableCharacterSet *controlSet;
@end

@implementation CUPUserNameFormatter

- (instancetype)init {
  self = [super init];
  if (self) {
    _controlSet = [[NSMutableCharacterSet alloc] init];

    NSRange lowerCaseAlphaRange;
    lowerCaseAlphaRange.location = (unsigned int)'a';
    lowerCaseAlphaRange.length = 26;
    [_controlSet addCharactersInRange:lowerCaseAlphaRange];

    NSRange digitsRange;
    digitsRange.location = (unsigned int)'0';
    digitsRange.length = 10;
    [_controlSet addCharactersInRange:digitsRange];
    [_controlSet addCharactersInString:@"-._"];
    [_controlSet invert];
  }
  return self;
}

- (NSString *)stringForObjectValue:(id)anObject {
  if (![anObject isKindOfClass:[NSString class]]) {
    return nil;
  }
  return anObject;
}

- (BOOL)getObjectValue:(id *)obj
             forString:(NSString *)string
      errorDescription:(NSString **)error {
  NSString *trimmedReplacement =
      [[string componentsSeparatedByCharactersInSet:self.controlSet] componentsJoinedByString:@""];
  *obj = trimmedReplacement;
  return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString
            newEditingString:(NSString **)newString
            errorDescription:(NSString **)error {
  NSRange inRange = [partialString rangeOfCharacterFromSet:self.controlSet];
  if(inRange.location != NSNotFound) {
    *error = @"Illegal value.";
    NSBeep();
    return NO;
  }

  *newString = partialString;
  return YES;
}

@end
