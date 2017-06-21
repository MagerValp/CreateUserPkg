//
//  CUPKeys.h
//  CreateUserPkg
//
//  Created by Tom Burgin on 6/20/17.
//  Copyright © 2017 University of Gothenburg. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CUPKeys : NSObject

+ (NSData *)calculateShadowHashData:(NSString *)pwd;
+ (NSData *)calculateKCPasswordData:(NSString *)pwd;

@end
