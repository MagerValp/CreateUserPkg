#!/usr/bin/python
#
#  test_package.py
#  CreateUserPkg
#
#  Created by Per Olofsson on 2012-08-02.
#  Copyright (c) 2012 Per Olofsson. All rights reserved.


### FIXME: replace this with a proper unit test


import os
import sys
import plistlib
import optparse
import subprocess
import tempfile
import shutil
import glob
import hashlib
import binascii
from xml.etree import ElementTree


def shell(*args):
    sys.stdout.flush()
    return subprocess.call(args)


def decode_kcpassword(pwd):
    key = (0x7D, 0x89, 0x52, 0x23, 0xD2, 0xBC, 0xDD, 0xEA, 0xA3, 0xB9, 0x1F)
    decoded = []
    for i, c in enumerate(pwd):
        n = ord(c)
        k = key[i % len(key)]
        if n ^ k == 0:
            break
        decoded.append(chr(n ^k))
    return "".join(decoded)
    

def verify_shadowhash(shadowhash, pwd):
    salted_offset = 64 + 40 + 64
    salted_sha1_str = shadowhash[salted_offset:salted_offset + 48]
    salt_str = salted_sha1_str[:8]
    hash_str = salted_sha1_str[8:]
    hashed_pwd = hashlib.sha1(binascii.unhexlify(salt_str) + pwd).hexdigest().upper()
    return hashed_pwd == hash_str
    

def main(argv):
    p = optparse.OptionParser()
    p.set_usage("""Usage: %prog [options] -p password createuserpackage.pkg""")
    p.add_option("-v", "--verbose", action="store_true", help="Verbose output.")
    p.add_option("-p", "--password", action="store", help="Password to verify against (required).")
    options, argv = p.parse_args(argv)
    if len(argv) != 2:
        print >>sys.stderr, p.get_usage()
        return 1
    if not options.password:
        print >>sys.stderr, p.get_usage()
        return 1
    
    pkg_path = argv[1]
    
    # Create a temporary work directory, which is cleaned up in a finally clause.
    tmp_path = tempfile.mkdtemp()
    try:
        # Expand pkg with pkgutil.
        expanded_pkg_path = os.path.join(tmp_path, "expanded_pkg")
        if shell("/usr/sbin/pkgutil", "--expand", pkg_path, expanded_pkg_path) != 0:
            return 2
        # Unpack the payload using ditto.
        compressed_payload_path = os.path.join(expanded_pkg_path, "Payload")
        payload_path = os.path.join(tmp_path, "payload")
        if shell("/usr/bin/ditto", "-x", compressed_payload_path, payload_path) != 0:
            return 2
        # Find the user plist inside.
        users_dir = os.path.join(payload_path, "private/var/db/dslocal/nodes/Default/users")
        user_plists = glob.glob(os.path.join(users_dir, "*.plist"))
        if len(user_plists) != 1:
            print >>sys.stderr, "Incompatible package"
            return 2
        user_plist_path = user_plists[0]
        # Read the plist.
        user = plistlib.readPlist(user_plist_path)
        if options.verbose:
            print "Account:"
            print "    Full Name: %s" % user["realname"][0]
            print "    Account name: %s" % user["name"][0]
            print "    Password: %s" % user["passwd"][0]
            print "    User ID: %s" % user["uid"][0]
            print "    Group ID: %s" % user["gid"][0]
            print "    Home directory: %s" % user["realname"][0]
            print "    UUID: %s" % user["generateduid"][0]
            print
        # Read the PackageInfo.
        pkginfo_path = os.path.join(expanded_pkg_path, "PackageInfo")
        et = ElementTree.parse(pkginfo_path)
        pkg_info = et.getroot()
        if options.verbose:
            print "Package:"
            print "    Package ID: %s" % pkg_info.get("identifier")
            print "    Version: %s" % pkg_info.get("version")
            print
        
        # Verify the payload.
        try:
            # Verify the shadow hash.
            shadow_hash_path = os.path.join(payload_path, "private/var/db/shadow/hash", user[u"generateduid"][0])
            f = open(shadow_hash_path)
            shadow_hash = f.read()
            f.close()
            if verify_shadowhash(shadow_hash, options.password):
                if options.verbose:
                    print "shadowhash: OK"
            else:
                print "shadowhash: FAILED"
                return 2
            # Verify kcpassword.
            kcpassword_path = os.path.join(payload_path, "private/etc/kcpassword")
            try:
                f = open(kcpassword_path)
                kcpassword = f.read()
                f.close()
                if options.password == decode_kcpassword(kcpassword):
                    if options.verbose:
                        print "kcpassword: OK"
                else:
                    print "kcpassword: FAILED"
                    return 2
            except IOError:
                kcpassword = None
        except BaseException, e:
            print >>sys.stderr, "Exception when verifying payload: %s" % e
            return 2
    
    finally:
        shutil.rmtree(tmp_path, ignore_errors=True)
    
    return 0
    

if __name__ == '__main__':
    sys.exit(main(sys.argv))
    
