//
//  CUPDocument.h
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CUPBestHostFinder.h"

@interface CUPDocument : NSDocument {
    NSWindow *docWindow;
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
    NSMutableString *_shadowHash;
    NSMutableDictionary *_docState;
}

@property (assign) IBOutlet NSWindow *docWindow;

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

@property (retain) NSMutableString *shadowHash;
@property (retain) NSMutableDictionary *docState;

- (IBAction)didLeaveFullName:(id)sender;
- (IBAction)didLeaveAccountName:(id)sender;
- (IBAction)didLeavePassword:(id)sender;

- (void)calculateShadowHash:(NSString *)password;
- (void)setTextField:(NSTextField *)field withKey:(NSString *)key;
- (void)setDocStateKey:(NSString *)key fromDict:(NSDictionary *)dict;
- (BOOL)validateField:(NSControl *)field validator:(BOOL (^)(NSControl *))valFunc errorMsg:(NSString *)msg;
- (BOOL)validateDocumentAndUpdateState;
- (NSDictionary *)newDictFromScript:(NSString *)path withArgs:(NSDictionary *)argDict error:(NSError **)outError;

#define SALTED_SHA1_LEN 48
#define SALTED_SHA1_OFFSET (64 + 40 + 64)
#define SHADOW_HASH_LEN 1240

#define CUP_PASSWORD_PLACEHOLDER @"SEI PHA TSX STX $D418 JMP LOOP"

@end
