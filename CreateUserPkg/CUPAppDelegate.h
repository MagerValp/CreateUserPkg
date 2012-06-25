//
//  CUPAppDelegate.h
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-19.
//  Copyright (c) 2012 Per Olofsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CUPAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *_window;
    NSTextField *_fullName;
    NSTextField *_accountName;
    NSSecureTextField *_password;
    NSSecureTextField *_verifyPassword;
    NSTextField *_userID;
    NSTextField *_groupID;
    NSTextField *_homeDirectory;
    NSTextField *_uuid;
    NSTextField *_packageID;
    NSTextField *_version;
    NSProgressIndicator *_spinner;
    NSArray *_bestHost;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *fullName;
@property (assign) IBOutlet NSTextField *accountName;
@property (assign) IBOutlet NSSecureTextField *password;
@property (assign) IBOutlet NSSecureTextField *verifyPassword;
@property (assign) IBOutlet NSTextField *userID;
@property (assign) IBOutlet NSTextField *groupID;
@property (assign) IBOutlet NSTextField *homeDirectory;
@property (assign) IBOutlet NSTextField *uuid;
@property (assign) IBOutlet NSTextField *packageID;
@property (assign) IBOutlet NSTextField *version;
@property (assign) IBOutlet NSProgressIndicator *spinner;

@property (atomic, retain) NSArray *bestHost;

- (void)findBestHost:(id)unused;
- (IBAction)didClickCreate:(id)sender;
- (IBAction)didLeaveFullName:(id)sender;
- (IBAction)didLeaveAccountName:(id)sender;
- (NSDictionary *)validatedFields;
- (BOOL)createPackage:(NSString *)pkgPath args:(NSDictionary *)argDict output:(NSString * __strong *)errorMsg;
//- (BOOL)authenticateAndCreatePackage:(NSString *)pkgPath withArgs:(NSDictionary *)argDict;

@end
