//
//  CUPDocument.h
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CUPBestHostFinder.h"
#import "CUPImageSelector.h"


@interface CUPDocument : NSDocument {
    NSWindow *__unsafe_unretained docWindow;
    
    CUPImageSelector *__unsafe_unretained _image;
    NSTextField *__unsafe_unretained _fullName;
    NSTextField *__unsafe_unretained _accountName;
    NSSecureTextField *__unsafe_unretained _password;
    NSSecureTextField *__unsafe_unretained _verifyPassword;
    NSTextField *__unsafe_unretained _userID;
    NSPopUpButton *__unsafe_unretained _accountType;
    NSTextField *__unsafe_unretained _homeDirectory;
    NSTextField *__unsafe_unretained _uuid;
    NSButton *__unsafe_unretained _automaticLogin;
    
    NSTextField *__unsafe_unretained _packageID;
    NSTextField *__unsafe_unretained _version;
    
    NSMutableString *_shadowHash;
    NSData *_kcPassword;
    NSMutableDictionary *_docState;
}

@property (unsafe_unretained) IBOutlet NSWindow *docWindow;

@property (unsafe_unretained) IBOutlet NSTextField *fullName;
@property (unsafe_unretained) IBOutlet NSTextField *accountName;
@property (unsafe_unretained) IBOutlet CUPImageSelector *image;
@property (unsafe_unretained) IBOutlet NSSecureTextField *password;
@property (unsafe_unretained) IBOutlet NSSecureTextField *verifyPassword;
@property (unsafe_unretained) IBOutlet NSTextField *userID;
@property (unsafe_unretained) IBOutlet NSPopUpButton *accountType;
@property (unsafe_unretained) IBOutlet NSTextField *homeDirectory;
@property (unsafe_unretained) IBOutlet NSTextField *uuid;
@property (unsafe_unretained) IBOutlet NSButton *automaticLogin;

@property (unsafe_unretained) IBOutlet NSTextField *packageID;
@property (unsafe_unretained) IBOutlet NSTextField *version;

@property (strong) NSMutableString *shadowHash;
@property (strong) NSData *kcPassword;
@property (strong) NSMutableDictionary *docState;

- (IBAction)didLeaveFullName:(id)sender;
- (IBAction)didLeaveAccountName:(id)sender;
- (IBAction)didLeavePassword:(id)sender;

- (void)calculateShadowHash:(NSString *)pwd;
- (void)calculateKCPassword:(NSString *)pwd;
- (void)setTextField:(NSTextField *)field withKey:(NSString *)key;
- (void)setDocStateKey:(NSString *)key fromDict:(NSDictionary *)dict;
- (BOOL)validateField:(NSControl *)field validator:(BOOL (^)(NSControl *))valFunc errorMsg:(NSString *)msg;
- (BOOL)validateDocumentAndUpdateState;
- (NSDictionary *)newDictFromScript:(NSString *)path withArgs:(NSDictionary *)argDict error:(NSError **)outError;

#define SALTED_SHA1_LEN 48
#define SALTED_SHA1_OFFSET (64 + 40 + 64)
#define SHADOW_HASH_LEN 1240

#define CUP_PASSWORD_PLACEHOLDER @"SEIPHATSXSTX$D418JMPC000"

enum {
    ACCOUNT_TYPE_STANDARD = 0,
    ACCOUNT_TYPE_ADMIN
};

@end
