//
//  CUPAppDelegate.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import "CUPAppDelegate.h"
#import "CUPBestHostFinder.h"

@implementation CUPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [CUPBestHostFinder bestHostFinder];
}

@end
