//
//  CUPBestHostFinder.h
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CUPBestHostFinder : NSObject {
    NSArray *_bestHost;
}

@property (atomic, strong) NSArray *bestHost;

+ (CUPBestHostFinder *)bestHostFinder;
- (void)findBestHost;

@end
