//
//  CUPDocument.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-27.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import "CUPDocument.h"

#import <Security/Security.h>

#import "CUPKeys.h"
#import "CUPImageSelector.h"
#import "CUPUIDFormatter.h"
#import "CUPUUIDFormatter.h"
#import "CUPUserNameFormatter.h"

#define CUP_PASSWORD_PLACEHOLDER @"SEIPHATSXSTX$D418JMPC000"

enum {
  ACCOUNT_TYPE_STANDARD = 0,
  ACCOUNT_TYPE_ADMIN
};

@interface CUPDocument ()

@property(weak) IBOutlet NSWindow *docWindow;

@property(weak) IBOutlet NSTextField *fullName;
@property(weak) IBOutlet NSTextField *accountName;
@property(weak) IBOutlet CUPImageSelector *image;
@property(weak) IBOutlet NSSecureTextField *password;
@property(weak) IBOutlet NSSecureTextField *verifyPassword;
@property(weak) IBOutlet NSTextField *userID;
@property(weak) IBOutlet NSPopUpButton *accountType;
@property(weak) IBOutlet NSTextField *homeDirectory;
@property(weak) IBOutlet NSTextField *uuid;
@property(weak) IBOutlet NSButton *automaticLogin;

@property(weak) IBOutlet NSTextField *packageID;
@property(weak) IBOutlet NSTextField *version;

@property NSData *shadowHashData;
@property NSData *kcPasswordData;
@property NSMutableDictionary *docState;
@property(readonly) NSArray *bestHost;

- (IBAction)didLeaveFullName:(id)sender;
- (IBAction)didLeaveAccountName:(id)sender;
- (IBAction)didLeavePassword:(id)sender;

@end

@implementation CUPDocument

- (instancetype)init {
  self = [super init];
  if (self) {
    _docState = [[NSMutableDictionary alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
      [self bestHost];
    });
  }
  return self;
}

- (NSArray *)bestHost {
  // Cache names for the lifetime of the process
  static NSArray *names;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    names = [[NSHost currentHost] names];
  });

  // Try to find a full domain name for the current host.
  // Iterate over all host names.
  for (NSString *name in names) {
    // Split host name by ".".
    NSArray *splitHost = [name componentsSeparatedByString:@"."];
    // Don't bother with unqualified host names.
    if ([splitHost count] > 1) {
      // Ignore .local.
      if (![[splitHost lastObject] isEqualToString:@"local"]) {
        // Whatever we found, it's probably better than what we have.
       return splitHost;
      }
    }
  }

  return @[@"host", @"example", @"com"];
}

- (NSError *)cocoaError:(NSInteger)code withReason:(NSString *)reason {
  return [NSError errorWithDomain:NSCocoaErrorDomain
                             code:code
                         userInfo:@{ NSLocalizedFailureReasonErrorKey: reason }];
}

- (NSString *)windowNibName {
  return @"CUPDocument";
}

- (void)showHelp:(id)sender {
  NSString *url = @"https://github.com/MagerValp/CreateUserPkg#createuserpkg";
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)didLeaveFullName:(id)sender {
  // If the user has entered a fullName convert the full name to lower case, strip
  // illegal chars, and use that to fill the accountName.
  if (!self.accountName.stringValue.length && self.fullName.stringValue.length) {
    NSString *lc = self.fullName.stringValue.lowercaseString;
    NSData *data = [lc dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *asciiString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    self.accountName.stringValue = asciiString;
  }
}

- (IBAction)didLeaveAccountName:(id)sender {
  // If the user has entered an accountName fill homeDirectory and packageID.
  if (!self.homeDirectory.stringValue.length && self.accountName.stringValue.length) {
    self.homeDirectory.stringValue =
        [NSString stringWithFormat:@"/Users/%@", self.accountName.stringValue];
  }
  if (!self.packageID.stringValue.length && self.accountName.stringValue.length) {
    NSMutableArray *host = [self.bestHost reverseObjectEnumerator].allObjects.mutableCopy;
    [host removeLastObject];
    NSString *reverseDomain = [host componentsJoinedByString:@"."];
    self.packageID.stringValue = [NSString stringWithFormat:@"%@.create_%@.pkg",
                                     reverseDomain, self.accountName.stringValue];
  }
}

- (IBAction)didLeavePassword:(id)sender {
  if (self.password.stringValue.length) {
    if ([self.password.stringValue isEqualToString:self.verifyPassword.stringValue]) {
      if (![self.password.stringValue isEqualToString:CUP_PASSWORD_PLACEHOLDER]) {
        self.shadowHashData = [CUPKeys calculateShadowHashData:[self.password stringValue]];
        self.kcPasswordData = [CUPKeys calculateKCPasswordData:[self.password stringValue]];
        [self.automaticLogin setEnabled:YES];
      }
    }
  }
}

- (void)setTextField:(NSTextField *)field withKey:(NSString *)key {
  NSString *value = self.docState[key];
  if (value) [field setStringValue:value];
}

#define UPDATE_TEXT_FIELD(FIELD) [self setTextField:self.FIELD withKey:@#FIELD]

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
  [super windowControllerDidLoadNib:aController];

  // Initialize form with default values.
  self.accountName.formatter = [[CUPUserNameFormatter alloc] init];

  self.userID.formatter = [[CUPUIDFormatter alloc] init];
  self.userID.stringValue = @"899";

  self.uuid.formatter = [[CUPUUIDFormatter alloc] init];
  self.uuid.stringValue = [NSUUID UUID].UUIDString;

  self.version.stringValue = @"1.0";

  [self.fullName becomeFirstResponder];

  // Load values from document state.
  UPDATE_TEXT_FIELD(fullName);
  UPDATE_TEXT_FIELD(accountName);
  UPDATE_TEXT_FIELD(userID);
  UPDATE_TEXT_FIELD(homeDirectory);
  UPDATE_TEXT_FIELD(uuid);
  UPDATE_TEXT_FIELD(packageID);
  UPDATE_TEXT_FIELD(version);

  if (self.docState[@"shadowHashData"]) {
    self.password.stringValue = CUP_PASSWORD_PLACEHOLDER;
    self.verifyPassword.stringValue = CUP_PASSWORD_PLACEHOLDER;
  }

  self.automaticLogin.enabled = YES;

  if (self.docState[@"kcPassword"]) {
    self.automaticLogin.state = NSOnState;
  } else {
    self.automaticLogin.state = NSOffState;
    if ([self.password.stringValue isEqualToString:CUP_PASSWORD_PLACEHOLDER]) {
      self.automaticLogin.enabled = NO;
    }
  }

  self.image.imageData = self.docState[@"imageData"];
  self.image.imagePath = self.docState[@"imagePath"];
  [self.image displayImageData];

  if (self.docState[@"isAdmin"]) {
    [self.accountType selectItemAtIndex:
        [self.docState[@"isAdmin"] boolValue] ? ACCOUNT_TYPE_ADMIN : ACCOUNT_TYPE_STANDARD];
  } else {
    [self.accountType selectItemAtIndex:ACCOUNT_TYPE_ADMIN];
  }
}

+ (BOOL)autosavesInPlace {
  return NO;
}

- (BOOL)isDocumentEdited {
  return NO;
}

- (NSString *)displayName {
  // This is used to provide a default name for the save dialog.
  // If accountName and version are set, return create_NAME-VER instead of Untitled.
  NSString *orgDisplayName = [super displayName];
  if ([orgDisplayName.lowercaseString hasPrefix:@"untitled"]) {
    if (self.accountName.stringValue.length && self.version.stringValue.length) {
      return [NSString stringWithFormat:@"create_%@-%@",
                 self.accountName.stringValue, self.version.stringValue];
    }
  }
  return orgDisplayName;
}

- (BOOL)validateField:(NSControl *)field
            validator:(BOOL (^)(NSControl *))valFunc
             errorMsg:(NSString *)msg {
  if (valFunc(field) == NO) {
    [field becomeFirstResponder];
    NSRunCriticalAlertPanel(msg, @"", @"OK", nil, nil);
    return NO;
  }
  return YES;
}

#define VALIDATE(...) if ((__VA_ARGS__) == NO) {return NO;}
#define SET_DOC_STATE(KEY) [self.docState setObject:[[self KEY] stringValue] forKey:@#KEY]

- (BOOL)validateDocumentAndUpdateState {
  BOOL (^validateNotEmpty)(NSControl *) = ^(NSControl *field) {
    return (BOOL)(field.stringValue.length);
  };
  BOOL (^validateSameAsPassword)(NSControl *) = ^(NSControl *field) {
    return [field.stringValue isEqualToString:self.password.stringValue];
  };
  BOOL (^validateHomeDir)(NSControl *) = ^(NSControl *field) {
    return (BOOL)(self.homeDirectory.stringValue.length &&
                  [self.homeDirectory.stringValue characterAtIndex:0] == L'/');
  };
  BOOL (^validateUUID)(NSControl *) = ^(NSControl *field){
    return (BOOL)(field.stringValue.length == 36);
  };

  VALIDATE([self validateField:self.fullName
                     validator:validateNotEmpty
                      errorMsg:@"Please enter a full name"]);
  VALIDATE([self validateField:self.accountName
                     validator:validateNotEmpty
                      errorMsg:@"Please enter an account name"]);
  if (!self.password.stringValue.length) {
    if (NSRunAlertPanel(@"Are you sure you want to create a user with an empty password?",
                        @"Anyone will be able to log in, even remotely, without being asked for a password.",
                        @"Cancel",
                        @"Use Empty Password",
                        nil) == NSAlertDefaultReturn) {
      [self.password becomeFirstResponder];
      return NO;
    }
  }
  VALIDATE([self validateField:self.verifyPassword
                     validator:validateSameAsPassword
                      errorMsg:@"Password verification doesn't match"]);
  VALIDATE([self validateField:self.userID
                     validator:validateNotEmpty
                      errorMsg:@"Please enter a user ID"]);
  VALIDATE([self validateField:self.homeDirectory
                     validator:validateHomeDir
                      errorMsg:@"Please enter a home directory path"]);
  VALIDATE([self validateField:self.uuid
                     validator:validateUUID
                      errorMsg:@"Please enter a valid UUID"]);
  VALIDATE([self validateField:self.packageID
                     validator:validateNotEmpty
                      errorMsg:@"Please enter a package ID"]);
  VALIDATE([self validateField:self.version
                     validator:validateNotEmpty
                      errorMsg:@"Please enter a version"]);

  SET_DOC_STATE(fullName);
  SET_DOC_STATE(accountName);
  SET_DOC_STATE(userID);
  SET_DOC_STATE(homeDirectory);
  SET_DOC_STATE(uuid);
  SET_DOC_STATE(packageID);
  SET_DOC_STATE(version);

  if (![self.password.stringValue isEqualToString:CUP_PASSWORD_PLACEHOLDER]) {
    if (!self.shadowHashData) {
      NSLog(@"shadowHash is empty, calculating new hash");
      self.shadowHashData = [CUPKeys calculateShadowHashData:[self.password stringValue]];
    }
    self.docState[@"shadowHashData"] = self.shadowHashData;
  }
  if (self.automaticLogin.state == NSOnState) {
    if (!self.kcPasswordData.length) {
      NSLog(@"kcPassword is empty, calculating new hash");
      self.kcPasswordData = [CUPKeys calculateKCPasswordData:[self.password stringValue]];
    }
    self.docState[@"kcPassword"] = self.kcPasswordData;
  }
  if (self.image.imageData) {
    self.docState[@"imageData"] = self.image.imageData;
  }
  if (self.image.imagePath) {
    self.docState[@"imagePath"] = self.image.imagePath;
  }
  self.docState[@"isAdmin"] =
      [NSNumber numberWithBool:([self.accountType indexOfSelectedItem] == ACCOUNT_TYPE_ADMIN)];

  return YES;
}

- (void)saveDocument:(id)sender {
  if ([self validateDocumentAndUpdateState]) {
    [super saveDocument:sender];
  }
}

- (void)saveDocumentAs:(id)sender {
  if ([self validateDocumentAndUpdateState]) {
    [super saveDocumentAs:sender];
  }
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"create_package" ofType:@"py"];
  NSDictionary *result = [self newDictFromScript:path withArgs:self.docState error:outError];
  return result[@"data"];
}

- (void)setDocStateKey:(NSString *)key fromDict:(NSDictionary *)dict {
  NSString *value = dict[key];
  if (value) self.docState[key] = value;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
  NSString *tmpPlist = [NSTemporaryDirectory() stringByAppendingFormat:@"%08x.pkg", arc4random()];
  NSDictionary *args = @{ @"input" : tmpPlist };

  [data writeToFile:tmpPlist atomically:NO];

  NSString *path = [[NSBundle mainBundle] pathForResource:@"read_package" ofType:@"py"];
  NSDictionary *document = [self newDictFromScript:path withArgs:args error:outError];
  [[NSFileManager defaultManager] removeItemAtPath:tmpPlist error:NULL];
  if (!document) {
    NSLog(@"Script returned nil");
    return NO;
  }

  [self.docState removeAllObjects];
  [self setDocStateKey:@"fullName"        fromDict:document];
  [self setDocStateKey:@"accountName"     fromDict:document];
  [self setDocStateKey:@"userID"          fromDict:document];
  [self setDocStateKey:@"isAdmin"         fromDict:document];
  [self setDocStateKey:@"homeDirectory"   fromDict:document];
  [self setDocStateKey:@"uuid"            fromDict:document];
  [self setDocStateKey:@"packageID"       fromDict:document];
  [self setDocStateKey:@"version"         fromDict:document];
  if (document[@"shadowHashData"]) {
    // only set this if we read ShadowHashData from the package
    [self setDocStateKey:@"shadowHashData"  fromDict:document];
  }
  [self setDocStateKey:@"imageData"       fromDict:document];
  [self setDocStateKey:@"imagePath"       fromDict:document];
  [self setDocStateKey:@"kcPassword"      fromDict:document];

  self.kcPasswordData = document[@"kcPassword"];

  return YES;
}

- (NSDictionary *)newDictFromScript:(NSString *)path
                           withArgs:(NSDictionary *)argDict
                              error:(NSError **)outError {
  // Create a task to execute the script.
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  task.standardInput = [NSPipe pipe];

  // Execute and collect output.
  [task launch];

  NSError *error;
  NSData *inData = [NSPropertyListSerialization dataWithPropertyList:argDict
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&error];
  if (!inData) {
    if (outError) {
      *outError = [self cocoaError:NSFileReadUnknownError
                        withReason:[NSString stringWithFormat:@"Couldn't create input for %@: %@",
                                       [path lastPathComponent], error.description]];
    }
  }
  [[task.standardInput fileHandleForWriting] writeData:inData];
  [[task.standardInput fileHandleForWriting] closeFile];

  [task waitUntilExit];
  NSData *stdoutData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSData *stderrData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
  int terminationStatus = [task terminationStatus];

  if (stderrData.length) {
    NSLog(@"%@ stderr: %@", path, [[NSString alloc] initWithData:stderrData
                                                        encoding:NSUTF8StringEncoding]);
  }

  if (terminationStatus == 0) {
    NSDictionary *result  = [NSPropertyListSerialization propertyListWithData:stdoutData
                                                                      options:0
                                                                       format:NULL
                                                                        error:&error];
    if (!result) {
      if (stdoutData.length) {
        NSLog(@"%@ stdout: %@", path, [[NSString alloc] initWithData:stdoutData
                                                            encoding:NSUTF8StringEncoding]);
      }
      if (outError) {
        *outError = [self cocoaError:NSFileReadUnknownError
                          withReason:[NSString stringWithFormat:@"Couldn't read output from %@: %@",
                                         [path lastPathComponent], error.description]];
      }
      return nil;
    }
    return result;
  } else {
    if (stdoutData.length) {
      NSLog(@"%@ stdout: %@", path, [[NSString alloc] initWithData:stdoutData
                                                          encoding:NSUTF8StringEncoding]);
    }
    if (outError) {
      *outError = [self cocoaError:NSFileReadUnknownError
                        withReason:[NSString stringWithFormat:@"%@ exited with return code %d",
                                       [path lastPathComponent], terminationStatus]];
    }
    return nil;
  }
}

@end
