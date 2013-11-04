//
//  CUPBestHostFinder.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import "CUPBestHostFinder.h"

@implementation CUPBestHostFinder

@synthesize bestHost = _bestHost;

- (id)init
{
    self = [super init];
    if (self) {
        self.bestHost = @[@"host", @"example", @"com"];
    }
    return self;
}


+ (CUPBestHostFinder *)bestHostFinder
{
    static CUPBestHostFinder *sharedSingleton;
    @synchronized(self) {
        if (!sharedSingleton) {
            sharedSingleton = [[CUPBestHostFinder alloc] init];
            [sharedSingleton performSelectorInBackground:@selector(findBestHost) withObject:nil];
        }
        return sharedSingleton;
    }
}

- (void)findBestHost
{
    // Try to find a full domain name for the current host.
    
    // Iterate over all host names.
    for (NSString *name in [[NSHost currentHost] names]) {
        // Split host name by ".".
        NSArray *splitHost = [name componentsSeparatedByString:@"."];
        // Don't bother with unqualified host names.
        if ([splitHost count] > 1) {
            // Ignore .local.
            if (! [[splitHost lastObject] isEqualToString:@"local"]) {
                // Whatever we found, it's probably better than what we have.
                self.bestHost = splitHost;
                // Return as soon as we've got a result.
                return;
            }
        }
    }
}

@end
