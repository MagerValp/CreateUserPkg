//
//  CUPAppDelegate.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-19.
//  Copyright (c) 2012 Per Olofsson. All rights reserved.
//

#import "CUPAppDelegate.h"
#import "CUPUIDFormatter.h"
#import "CUPUserNameFormatter.h"
#import "CUPUUIDFormatter.h"


@implementation CUPAppDelegate

@synthesize window = _window;
@synthesize fullName = _fullName;
@synthesize accountName = _accountName;
@synthesize password = _password;
@synthesize verifyPassword = _verifyPassword;
@synthesize userID = _userID;
@synthesize groupID = _groupID;
@synthesize homeDirectory = _homeDirectory;
@synthesize uuid = _uuid;
@synthesize packageID = _packageID;
@synthesize version = _version;
@synthesize spinner = _spinner;

@synthesize bestHost = _bestHost;


- (void)dealloc
{
    [_bestHost release];
    [super dealloc];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.bestHost = [NSArray arrayWithObjects:@"host", @"example", @"com", nil];
    [self performSelectorInBackground:@selector(findBestHost:) withObject:nil];
    
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
}

- (void)findBestHost:(id)unused {
    // Try to find a full domain name for the current host.
    // Iterate over all host names.
    for (NSString *name in [[NSHost currentHost] names]) {
        NSLog(@"checking %@", name);
        // Split host name by ".".
        NSArray *splitHost = [name componentsSeparatedByString:@"."];
        // Don't bother with unqualified host names.
        if ([splitHost count] > 1) {
            // Ignore .local.
            if (! [[splitHost lastObject] isEqualToString:@"local"]) {
                NSLog(@"selecting %@ as bestHost", name);
                // Whatever we found, it's probably better than what we have.
                self.bestHost = splitHost;
                // Return as soon as we've got a result.
                return;
            }
        }
    }
    NSLog(@"failed to find host name, using host.example.com");
}

- (IBAction)didLeaveFullName:(id)sender {
    if ([[self.accountName stringValue] length] == 0 && [[self.fullName stringValue] length] != 0) {
        NSString *lcString = [[self.fullName stringValue] lowercaseString];
        NSData *asciiData = [lcString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *asciiString = [[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding];
        [self.accountName setStringValue:asciiString];
        [asciiString release];
    }
}

- (IBAction)didLeaveAccountName:(id)sender {
    if ([[self.homeDirectory stringValue] length] == 0 && [[self.accountName stringValue] length] != 0) {
        [self.homeDirectory setStringValue:[NSString stringWithFormat:@"/Users/%@", [self.accountName stringValue]]];
    }
    if ([[self.packageID stringValue] length] == 0 && [[self.accountName stringValue] length] != 0) {
        NSMutableArray *host = [NSMutableArray arrayWithArray:self.bestHost];
        [host removeObjectAtIndex:0];
        
        NSString *reverseDomain = [[[host reverseObjectEnumerator] allObjects] componentsJoinedByString:@"."];
        [self.packageID setStringValue:[NSString stringWithFormat:@"%@.create_%@.pkg", reverseDomain, [self.accountName stringValue]]];
    }
}

- (IBAction)didClickCreate:(id)sender
{
    NSDictionary *validatedArgs = [self validatedFields];
	if (validatedArgs == nil) {
        return;
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"pkg"]];
    [savePanel setNameFieldStringValue:[NSString stringWithFormat:@"create_%@-%@.pkg", [self.accountName stringValue], [self.version stringValue]]];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [savePanel orderOut:self];
            [self.spinner startAnimation:self];
            NSString *outputMsg;
            BOOL result = [self createPackage:[[savePanel URL] path] args:validatedArgs output:&outputMsg];
            [self.spinner stopAnimation:self];
            if (result == YES) {
                if (NSRunAlertPanel(@"Created package", outputMsg, @"Reveal", @"OK", nil) == NSAlertDefaultReturn) {
                    [[NSWorkspace sharedWorkspace] selectFile:[[savePanel URL] path] inFileViewerRootedAtPath:@""];
                }
            } else {
                NSRunCriticalAlertPanel(@"Package creation failed", outputMsg, @"OK", nil, nil);
            }
        }
    }];
}

#define VALDEF(FIELD, ERRORMSG, VALFUNC) \
    [NSArray arrayWithObjects:           \
     _##FIELD,                           \
     @#FIELD,                            \
     ERRORMSG,                           \
     VALFUNC,                            \
     nil]

enum {
    VAL_FIELD,
    VAL_KEY,
    VAL_ERRORMSG,
    VAL_FUNC
};

- (NSDictionary *)validatedFields
{
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
    
    BOOL (^validateNotEmpty)(NSTextField *) = ^(NSTextField *field){
        return (BOOL)([[field stringValue] length] != 0);
    };
    BOOL (^validateSameAsPassword)(NSTextField *) = ^(NSTextField *field){
        return [[field stringValue] isEqualToString:[self.password stringValue]];
    };
    BOOL (^validateHomeDir)(NSTextField *) = ^(NSTextField *field){
        return (BOOL)([[self.homeDirectory stringValue] length] != 0 && [[self.homeDirectory stringValue] characterAtIndex:0] == L'/');
    };
    BOOL (^validateUUID)(NSTextField *) = ^(NSTextField *field){
        return (BOOL)([[field stringValue] length] == 36);
    };
    
    NSArray *validators = [[NSArray arrayWithObjects:
        VALDEF(fullName,       @"Please enter a full name",            validateNotEmpty),
        VALDEF(accountName,    @"Please enter an account name",        validateNotEmpty),
        VALDEF(password,       @"Please enter a password",             validateNotEmpty),
        VALDEF(verifyPassword, @"Password verification doesn't match", validateSameAsPassword),
        VALDEF(userID,         @"Please enter a user ID",              validateNotEmpty),
        VALDEF(groupID,        @"Please enter a group ID",             validateNotEmpty),
        VALDEF(homeDirectory,  @"Please enter a home directory path",  validateHomeDir),
        VALDEF(uuid,           @"Please enter a valid UUID",           validateUUID),
        VALDEF(packageID,      @"Please enter a package ID",           validateNotEmpty),
        VALDEF(version,        @"Please enter a version",              validateNotEmpty),
        nil] retain];
    
    for (NSArray *validator in validators) {
        BOOL (^valFunc)(NSTextField *) = [validator objectAtIndex:VAL_FUNC];
        if (valFunc([validator objectAtIndex:VAL_FIELD]) == YES) {
            if ([validator objectAtIndex:VAL_KEY] != nil) {
                [fields setObject:[[validator objectAtIndex:VAL_FIELD] stringValue] forKey:[validator objectAtIndex:VAL_KEY]];
            }
        } else {
            NSRunCriticalAlertPanel([validator objectAtIndex:VAL_ERRORMSG],
                                    @"",
                                    @"OK",
                                    nil,
                                    nil);
            [[validator objectAtIndex:VAL_FIELD] becomeFirstResponder];
            [fields release];
            return nil;
        }
    }
    
    return [fields autorelease];
}

- (BOOL)createPackage:(NSString *)pkgPath args:(NSDictionary *)argDict output:(NSString **)outputMsg
{
    NSData *data;
    NSTask *task;
    NSPipe *pipe;
    NSFileHandle *file;
	
    // Convert argument dictionary to an array of --key=value strings
    NSMutableArray *args = [[NSMutableArray alloc] init];
    for (NSString *key in argDict) {
        [args addObject:[NSString stringWithFormat:@"--%@=%@", key, [argDict objectForKey:key]]];
    }
    [args addObject:[NSString stringWithFormat:@"--pkgPath=%@", pkgPath]];
    
    task = [[NSTask alloc] init];
    [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"create_package" ofType:@"py"]];
    [task setArguments:args];
    //[args release];
    
    pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    [task setStandardInput:[NSPipe pipe]];
    
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    data = [file readDataToEndOfFile];
    
    *outputMsg = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"create_package.py output:\n%@", *outputMsg);
    
    [task waitUntilExit];
	NSInteger terminationStatus = [task terminationStatus];
    [task release];
    
    return (BOOL)(terminationStatus == 0);
}

@end
