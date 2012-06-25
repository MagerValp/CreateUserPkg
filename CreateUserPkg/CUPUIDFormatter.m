//
//  CUPNumberOnly.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-19.
//  Copyright (c) 2012 Per Olofsson. All rights reserved.
//

#import "CUPUIDFormatter.h"

@implementation CUPUIDFormatter

- (BOOL)isPartialStringValid:(NSString *)partialString
            newEditingString:(NSString **)newString
            errorDescription:(NSString **)error
{
	NSRange inRange;
	NSCharacterSet *allowedChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
	inRange = [partialString rangeOfCharacterFromSet:allowedChars];
	
	if(inRange.location != NSNotFound)
	{
		*error = @"Only numbers are allowed.";
		NSBeep();
		return NO;
	}
	
	*newString = partialString;
	return YES;     
}


@end
