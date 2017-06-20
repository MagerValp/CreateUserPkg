//
//  CUPKeys.m
//  CreateUserPkg
//
//  Created by Tom Burgin on 6/20/17.
//  Copyright © 2017 University of Gothenburg. All rights reserved.
//

#import "CUPKeys.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#define PBKDF2_SALT_LEN 32
#define PBKDF2_ENTROPY_LEN 128
#define KCKEY_LEN 11
const char kcPasswordKey[KCKEY_LEN] =
    {0x7D, 0x89, 0x52, 0x23, 0xD2, 0xBC, 0xDD, 0xEA, 0xA3, 0xB9, 0x1F};

@implementation CUPKeys

+ (NSData *)calculateShadowHashData:(NSString *)pwd {
  unsigned char salt[PBKDF2_SALT_LEN];
  int status = SecRandomCopyBytes(kSecRandomDefault, PBKDF2_SALT_LEN, salt);
  if (status == 0) {
    unsigned char key[PBKDF2_ENTROPY_LEN];
    // calculate the number of iterations to use
    unsigned int rounds = CCCalibratePBKDF(kCCPBKDF2,
                                           [pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                           PBKDF2_SALT_LEN, kCCPRFHmacAlgSHA512, PBKDF2_ENTROPY_LEN, 100);
    // derive our SALTED-SHA512-PBKDF2 key
    CCKeyDerivationPBKDF(kCCPBKDF2,
                         [pwd UTF8String],
                         (CC_LONG)[pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                         salt, PBKDF2_SALT_LEN,
                         kCCPRFHmacAlgSHA512, rounds, key, PBKDF2_ENTROPY_LEN);
    // Make a dictionary containing the needed fields
    NSDictionary *dictionary = @{
                                 @"SALTED-SHA512-PBKDF2" : @{
                                     @"entropy" : [NSData dataWithBytes: key length: PBKDF2_ENTROPY_LEN],
                                     @"iterations" : [NSNumber numberWithUnsignedInt: rounds],
                                     @"salt" : [NSData dataWithBytes: salt length: PBKDF2_SALT_LEN]
                                     }
                                 };
    // convert to binary plist data
    NSError *error = NULL;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList: dictionary
                                                                   format: NSPropertyListBinaryFormat_v1_0
                                                                  options: 0
                                                                    error: &error];
    return plistData;
  }
  return nil;
}

+ (NSData *)calculateKCPasswordData:(NSString *)pwd {
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

  free(kcbuf);

  return [NSData dataWithBytes:kcbuf length:rounded12len];
}


@end
