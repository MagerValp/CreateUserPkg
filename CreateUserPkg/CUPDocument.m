//
//  CUPDocument.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "CUPDocument.h"
#import "CUPUIDFormatter.h"
#import "CUPUserNameFormatter.h"
#import "CUPUUIDFormatter.h"

@implementation CUPDocument

@synthesize docWindow;

@synthesize fullName = _fullName;
@synthesize accountName = _accountName;
@synthesize image = _image;
@synthesize password = _password;
@synthesize verifyPassword = _verifyPassword;
@synthesize userID = _userID;
@synthesize groupID = _groupID;
@synthesize homeDirectory = _homeDirectory;
@synthesize uuid = _uuid;
@synthesize automaticLogin = _automaticLogin;

@synthesize packageID = _packageID;
@synthesize version = _version;

@synthesize shadowHash = _shadowHash;
@synthesize kcPassword = _kcPassword;
@synthesize docState = _docState;


- (id)init
{
    self = [super init];
    if (self) {
        _docState = [[NSMutableDictionary alloc] init];
        _shadowHash = [[NSMutableString alloc] initWithString:@""];
        _kcPassword = nil;
    }
    return self;
}

- (void)dealloc
{
    self.docState = nil;
    self.shadowHash = nil;
    self.kcPassword = nil;
    [super dealloc];
}

- (NSError *)cocoaError:(NSInteger)code withReason:(NSString *)reason
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:[NSDictionary dictionaryWithObject:reason forKey:NSLocalizedFailureReasonErrorKey]];
}

- (NSString *)windowNibName
{
    return @"CUPDocument";
}

- (void)showHelp:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/MagerValp/CreateUserPkg#createuserpkg"]];
}

- (IBAction)didLeaveFullName:(id)sender {
    // If the user has entered a fullName convert the full name to lower case, strip
    // illegal chars, and use that to fill the accountName.
    if ([[self.accountName stringValue] length] == 0 && [[self.fullName stringValue] length] != 0) {
        NSString *lcString = [[self.fullName stringValue] lowercaseString];
        NSData *asciiData = [lcString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *asciiString = [[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding];
        [self.accountName setStringValue:asciiString];
        [asciiString release];
    }
}

- (IBAction)didLeaveAccountName:(id)sender {
    // If the user has entered an accountName fill homeDirectory and packageID.
    if ([[self.homeDirectory stringValue] length] == 0 && [[self.accountName stringValue] length] != 0) {
        [self.homeDirectory setStringValue:[NSString stringWithFormat:@"/Users/%@", [self.accountName stringValue]]];
    }
    if ([[self.packageID stringValue] length] == 0 && [[self.accountName stringValue] length] != 0) {
        NSMutableArray *host = [NSMutableArray arrayWithArray:[[CUPBestHostFinder bestHostFinder] bestHost]];
        [host removeObjectAtIndex:0];
        
        NSString *reverseDomain = [[[host reverseObjectEnumerator] allObjects] componentsJoinedByString:@"."];
        [self.packageID setStringValue:[NSString stringWithFormat:@"%@.create_%@.pkg", reverseDomain, [self.accountName stringValue]]];
    }
}

- (IBAction)didLeavePassword:(id)sender {
    if ([[self.password stringValue] length] != 0) {
        if ([[self.password stringValue] isEqualToString:[self.verifyPassword stringValue]]) {
            if ([[self.password stringValue] isEqualToString:CUP_PASSWORD_PLACEHOLDER] == NO) {
                [self calculateShadowHash:[self.password stringValue]];
                [self calculateKCPassword:[self.password stringValue]];
                [self.automaticLogin setEnabled:YES];
            }
        }
    }
}

- (void)calculateShadowHash:(NSString *)pwd
{
    CC_SHA1_CTX ctx;
    unsigned char salted_sha1_hash[24];
    union _salt {
        unsigned char bytes[4];
        u_int32_t value;
    } *salt = (union _salt *)&salted_sha1_hash[0];
    unsigned char *hash = &salted_sha1_hash[4];
    
    // Calculate salted sha1 hash.
    CC_SHA1_Init(&ctx);
    salt->value = arc4random();
    CC_SHA1_Update(&ctx, salt->bytes, sizeof(salt->bytes));
    CC_SHA1_Update(&ctx, [pwd UTF8String], (CC_LONG)[pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    CC_SHA1_Final(hash, &ctx);
    
    // Generate new shadow hash.
    [self.shadowHash setString:@""];
    [self.shadowHash appendFormat:@"%0168X", 0];
    assert([self.shadowHash length] == SALTED_SHA1_OFFSET);
    for (int i = 0; i < sizeof(salted_sha1_hash); i++) {
        [self.shadowHash appendFormat:@"%02X", salted_sha1_hash[i]];
    }
    while ([self.shadowHash length] < SHADOW_HASH_LEN) {
        [self.shadowHash appendFormat:@"%064X", 0];
    }
    assert([self.shadowHash length] == SHADOW_HASH_LEN);
}

#define KCKEY_LEN 11
const char kcPasswordKey[KCKEY_LEN] = {0x7D, 0x89, 0x52, 0x23, 0xD2, 0xBC, 0xDD, 0xEA, 0xA3, 0xB9, 0x1F};

- (void)calculateKCPassword:(NSString *)pwd
{
    int i;
    NSUInteger pwdlen = [pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    // kcpassword stores the password plus null terminator, rounded up to the nearest 12 bytes.
    NSUInteger rounded12len = ((pwdlen + 12) / 12) * 12;
    unsigned char *kcbuf = malloc(rounded12len);
    
    // Get UTF-8 encoded data and xor it with the key.
    const unsigned char *pwdbuf = [[pwd dataUsingEncoding:NSUTF8StringEncoding] bytes];
    for (i = 0; i < pwdlen; i++) {
        kcbuf[i] = pwdbuf[i] ^ kcPasswordKey[i % KCKEY_LEN];
    }
    kcbuf[i] = kcPasswordKey[i % KCKEY_LEN];
    
    self.kcPassword = [NSData dataWithBytes:kcbuf length:rounded12len];
    
    free(kcbuf);
}

- (void)setTextField:(NSTextField *)field withKey:(NSString *)key
{
    NSString *value = [self.docState objectForKey:key];
    if (key != nil && value != nil) {
        [field setStringValue:value];
    }
}

#define UPDATE_TEXT_FIELD(FIELD) [self setTextField:self.FIELD withKey:@#FIELD]

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    
    // Initialize form with default values.
    CUPUIDFormatter *uidFormatter = [[CUPUIDFormatter alloc] init];
    [self.userID setFormatter:uidFormatter];
    [self.groupID setFormatter:uidFormatter];
    [uidFormatter release];
    [self.userID setStringValue:@"499"];
    [self.groupID setStringValue:@"80"];
    CUPUserNameFormatter *userNameFormatter = [[CUPUserNameFormatter alloc] init];
    [self.accountName setFormatter:userNameFormatter];
    [userNameFormatter release];
    CUPUUIDFormatter *uuidFormatter = [[CUPUUIDFormatter alloc] init];
    [self.uuid setFormatter:uuidFormatter];
    [uuidFormatter release];
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *uuidString = (NSString *)CFUUIDCreateString(NULL, theUUID);
    [self.uuid setStringValue:uuidString];
    [uuidString release];
    CFRelease(theUUID);
    [self.version setStringValue:@"1.0"];
    
    [self.fullName becomeFirstResponder];
    
    // Load values from document state.
    UPDATE_TEXT_FIELD(fullName);
    UPDATE_TEXT_FIELD(accountName);
    UPDATE_TEXT_FIELD(userID);
    UPDATE_TEXT_FIELD(groupID);
    UPDATE_TEXT_FIELD(homeDirectory);
    UPDATE_TEXT_FIELD(uuid);
    UPDATE_TEXT_FIELD(packageID);
    UPDATE_TEXT_FIELD(version);
    if ([self.docState objectForKey:@"shadowHash"] != nil) {
        [self.password setStringValue:CUP_PASSWORD_PLACEHOLDER];
        [self.verifyPassword setStringValue:CUP_PASSWORD_PLACEHOLDER];
    }
    [self.automaticLogin setEnabled:YES];
    if ([self.docState objectForKey:@"kcPassword"] != nil) {
        [self.automaticLogin setState:NSOnState];
    } else {
        [self.automaticLogin setState:NSOffState];
        if ([[self.password stringValue] isEqualToString:CUP_PASSWORD_PLACEHOLDER]) {
            [self.automaticLogin setEnabled:NO];
        }
    }
    self.image.imageData = [self.docState objectForKey:@"imageData"];
    self.image.imagePath = [self.docState objectForKey:@"imagePath"];
    [self.image displayImageData];
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

- (BOOL)isDocumentEdited
{
    return NO;
}

- (NSString *)displayName
{
    // This is used to provide a default name for the save dialog.
    // If accountName and version are set, return create_NAME-VER instead of Untitled.
    NSString *orgDisplayName = [super displayName];
    if ([[orgDisplayName lowercaseString] hasPrefix:@"untitled"]) {
        if ([[self.accountName stringValue] length] > 0 && [[self.version stringValue] length] > 0) {
            return [NSString stringWithFormat:@"create_%@-%@", [self.accountName stringValue], [self.version stringValue]];
        }
    }
    return orgDisplayName;
}

- (BOOL)validateField:(NSControl *)field validator:(BOOL (^)(NSControl *))valFunc errorMsg:(NSString *)msg
{
    if (valFunc(field) == NO) {
        [field becomeFirstResponder];
        NSRunCriticalAlertPanel(msg, @"", @"OK", nil, nil);
        return NO;
    }
    return YES;
}

#define VALIDATE(...) if ((__VA_ARGS__) == NO) {return NO;}
#define SET_DOC_STATE(KEY) [self.docState setObject:[[self KEY] stringValue] forKey:@#KEY]

- (BOOL)validateDocumentAndUpdateState
{
    BOOL (^validateNotEmpty)(NSControl *) = ^(NSControl *field){
        return (BOOL)([[field stringValue] length] != 0);
    };
    BOOL (^validateSameAsPassword)(NSControl *) = ^(NSControl *field){
        return [[field stringValue] isEqualToString:[self.password stringValue]];
    };
    BOOL (^validateHomeDir)(NSControl *) = ^(NSControl *field){
        return (BOOL)([[self.homeDirectory stringValue] length] != 0 && [[self.homeDirectory stringValue] characterAtIndex:0] == L'/');
    };
    BOOL (^validateUUID)(NSControl *) = ^(NSControl *field){
        return (BOOL)([[field stringValue] length] == 36);
    };
    
    VALIDATE([self validateField:self.fullName       validator:validateNotEmpty       errorMsg:@"Please enter a full name"]);
    VALIDATE([self validateField:self.accountName    validator:validateNotEmpty       errorMsg:@"Please enter an account name"]);
    VALIDATE([self validateField:self.password       validator:validateNotEmpty       errorMsg:@"Please enter a password"]);
    VALIDATE([self validateField:self.verifyPassword validator:validateSameAsPassword errorMsg:@"Password verification doesn't match"]);
    VALIDATE([self validateField:self.userID         validator:validateNotEmpty       errorMsg:@"Please enter a user ID"]);
    VALIDATE([self validateField:self.groupID        validator:validateNotEmpty       errorMsg:@"Please enter a group ID"]);
    VALIDATE([self validateField:self.homeDirectory  validator:validateHomeDir        errorMsg:@"Please enter a home directory path"]);
    VALIDATE([self validateField:self.uuid           validator:validateUUID           errorMsg:@"Please enter a valid UUID"]);
    VALIDATE([self validateField:self.packageID      validator:validateNotEmpty       errorMsg:@"Please enter a package ID"]);
    VALIDATE([self validateField:self.version        validator:validateNotEmpty       errorMsg:@"Please enter a version"]);
    
    SET_DOC_STATE(fullName);
    SET_DOC_STATE(accountName);
    SET_DOC_STATE(userID);
    SET_DOC_STATE(groupID);
    SET_DOC_STATE(homeDirectory);
    SET_DOC_STATE(uuid);
    SET_DOC_STATE(packageID);
    SET_DOC_STATE(version);
    if ([[self.password stringValue] isEqualToString:CUP_PASSWORD_PLACEHOLDER] == NO) {
        [self.docState setObject:[NSString stringWithString:self.shadowHash] forKey:@"shadowHash"];
    }
    if ([self.automaticLogin state] == NSOnState) {
        [self.docState setObject:self.kcPassword forKey:@"kcPassword"];
    }
    if (self.image.imageData != nil) {
        [self.docState setObject:self.image.imageData forKey:@"imageData"];
    }
    if (self.image.imagePath != nil) {
        [self.docState setObject:self.image.imagePath forKey:@"imagePath"];
    }
    
    return YES;
}

- (void)saveDocument:(id)sender
{
    if ([self validateDocumentAndUpdateState]) {
        [super saveDocument:sender];
    }
}

- (void)saveDocumentAs:(id)sender
{
    if ([self validateDocumentAndUpdateState]) {
        [super saveDocumentAs:sender];
    }
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    NSData *data;
    
    NSDictionary *result = [self newDictFromScript:[[NSBundle mainBundle] pathForResource:@"create_package" ofType:@"py"] withArgs:self.docState error:outError];
    if (result == nil) {
        return nil;
    }
    data = [result objectForKey:@"data"];
    [result release];
    return data;
}

- (void)setDocStateKey:(NSString *)key fromDict:(NSDictionary *)dict
{
    NSString *value = [dict objectForKey:key];
    if (value != nil) {
        [self.docState setObject:value forKey:key];
    }
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    NSDictionary *document;
    NSString *tmp_plist = [NSTemporaryDirectory() stringByAppendingFormat:@"%08x.pkg", arc4random()];
    NSDictionary *args = [NSDictionary dictionaryWithObject:tmp_plist forKey:@"input"];
    
    [data writeToFile:tmp_plist atomically:NO];
    
    document = [self newDictFromScript:[[NSBundle mainBundle] pathForResource:@"read_package" ofType:@"py"] withArgs:args error:outError];
    [[NSFileManager defaultManager] removeItemAtPath:tmp_plist error:nil];
    if (document == nil) {
        NSLog(@"Script returned nil");
        return NO;
    }
    
    [self.docState removeAllObjects];
    [self setDocStateKey:@"fullName"        fromDict:document];
    [self setDocStateKey:@"accountName"     fromDict:document];
    [self setDocStateKey:@"userID"          fromDict:document];
    [self setDocStateKey:@"groupID"         fromDict:document];
    [self setDocStateKey:@"homeDirectory"   fromDict:document];
    [self setDocStateKey:@"uuid"            fromDict:document];
    [self setDocStateKey:@"packageID"       fromDict:document];
    [self setDocStateKey:@"version"         fromDict:document];
    [self setDocStateKey:@"shadowHash"      fromDict:document];
    [self setDocStateKey:@"imageData"       fromDict:document];
    [self setDocStateKey:@"imagePath"       fromDict:document];
    [self setDocStateKey:@"kcPassword"      fromDict:document];
    
    self.kcPassword = [document objectForKey:@"kcPassword"];
    
    [document release];
    return YES;
}

- (NSDictionary *)newDictFromScript:(NSString *)path withArgs:(NSDictionary *)argDict error:(NSError **)outError
{
    NSTask *task;
    NSPipe *stdoutPipe;
    NSPipe *stderrPipe;
    NSPipe *stdinPipe;
    NSFileHandle *stdoutFile;
    NSFileHandle *stderrFile;
    NSFileHandle *stdinFile;
    NSData *stdoutData;
    NSData *stderrData;
    NSData *stdinData;
	NSDictionary *result;
    NSString *errorMsg = nil;
    
    // Create a task to execute the script.
    task = [[NSTask alloc] init];
    [task setLaunchPath:path];
    //[task setArguments:args];
    
    // Set up stdout/err/in pipes and get the file handles.
    stdoutPipe = [NSPipe pipe];
    stderrPipe = [NSPipe pipe];
    stdinPipe = [NSPipe pipe];
    [task setStandardOutput:stdoutPipe];
    [task setStandardError:stderrPipe];
    [task setStandardInput:stdinPipe];
    stdoutFile = [stdoutPipe fileHandleForReading];
    stderrFile = [stderrPipe fileHandleForReading];
    stdinFile = [stdinPipe fileHandleForWriting];
    
    // Execute and collect output.
    [task launch];
    
    stdinData = [NSPropertyListSerialization dataFromPropertyList:argDict format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorMsg];
    if (stdinData == nil) {
        if (outError != NULL) {
            *outError = [self cocoaError:NSFileReadUnknownError withReason:[NSString stringWithFormat:@"Couldn't create input for %@: %@", [path lastPathComponent], errorMsg]];
        }
    }
    [stdinFile writeData:stdinData];
    [stdinFile closeFile];
    stdoutData = [stdoutFile readDataToEndOfFile];
    stderrData = [stderrFile readDataToEndOfFile];
    
    [task waitUntilExit];
	NSInteger terminationStatus = [task terminationStatus];
    
    [task release];
    
    if ([stderrData length] != 0) {
        NSLog(@"%@ stderr: %@", path, [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease]);
    }
    
    if (terminationStatus == 0) {
        result = [NSPropertyListSerialization propertyListFromData:stdoutData
                                                  mutabilityOption:0
                                                            format:NULL
                                                  errorDescription:&errorMsg];
        if (result == nil) {
            if ([stdoutData length] != 0) {
                NSLog(@"%@ stdout: %@", path, [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease]);
            }
            if (outError != NULL) {
                *outError = [self cocoaError:NSFileReadUnknownError withReason:[NSString stringWithFormat:@"Couldn't read output from %@: %@", [path lastPathComponent], errorMsg]];
            }
            return nil;
        }
        return [result retain];
    } else {
        if ([stdoutData length] != 0) {
            NSLog(@"%@ stdout: %@", path, [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease]);
        }
        if (outError != NULL) {
            *outError = [self cocoaError:NSFileReadUnknownError withReason:[NSString stringWithFormat:@"%@ exited with return code %ld", [path lastPathComponent], terminationStatus]];
        }
        return nil;
    }
}

@end
