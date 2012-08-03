#!/usr/bin/python
#
#  read_package.py
#  CreateUserPkg
#
#  Created by Per Olofsson on 2012-06-27.
#  Copyright (c) 2012 University of Gothenburg. All rights reserved.


import os
import sys
import plistlib
import subprocess
import tempfile
import shutil
import glob
from xml.etree import ElementTree


REQUIRED_KEYS = set((u"input",))


def shell(*args):
    sys.stdout.flush()
    return subprocess.call(args)


def main(argv):
    
    input = plistlib.readPlist(sys.stdin)

    # Decode arguments as --key=value to a dictionary.
    #args = dict()
    #for arg in [a.decode("utf-8") for a in argv[1:]]:
    #    if not arg.startswith(u"--"):
    #        print >>sys.stderr, "Invalid argument: %s" % repr(arg)
    #        return 1
    #    (key, equal, value) = arg[2:].partition(u"=")
    #    if not equal:
    #        print >>sys.stderr, "Invalid argument: %s" % repr(arg)
    #        return 1
    #    args[key] = value
    
    # Ensure all required keys are given on the command line.
    for key in REQUIRED_KEYS:
        if key not in input:
            print >>sys.stderr, "Missing key: %s" % repr(key)
            return 1
    
    # Create a temporary work directory, which is cleaned up in a finally clause.
    tmp_path = tempfile.mkdtemp()
    try:
        # Expand pkg with pkgutil.
        expanded_pkg_path = os.path.join(tmp_path, "expanded_pkg")
        if shell("/usr/sbin/pkgutil", "--expand", input[u"input"], expanded_pkg_path) != 0:
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
        # Read the PackageInfo.
        pkginfo_path = os.path.join(expanded_pkg_path, "PackageInfo")
        et = ElementTree.parse(pkginfo_path)
        pkg_info = et.getroot()
        # Read the shadow hash.
        shadow_hash_path = os.path.join(payload_path, "private/var/db/shadow/hash", user[u"generateduid"][0])
        f = open(shadow_hash_path)
        shadow_hash = f.read()
        f.close()
        # Read kcpassword.
        kcpassword_path = os.path.join(payload_path, "private/etc/kcpassword")
        try:
            f = open(kcpassword_path)
            kcpassword = f.read()
            f.close()
        except IOError:
            kcpassword = None
        # Check if user is admin.
        is_admin = False
        if int(user[u"gid"][0]) == 80:
            is_admin = True
        try:
            f = open(os.path.join(expanded_pkg_path, "Scripts/postinstall"))
            postinstall = f.read()
            f.close()
        except IOError:
            pass
        if "ACCOUNT_TYPE=ADMIN" in postinstall:
            is_admin = True
        # Write the extracted document data to stdout as a plist.
        output_data = {
            u"fullName":         user[u"realname"][0],
            u"accountName":      user[u"name"][0],
            u"userID":           user[u"uid"][0],
            u"isAdmin":          is_admin,
            u"homeDirectory":    user[u"home"][0],
            u"uuid":             user[u"generateduid"][0],
            u"packageID":        pkg_info.get("identifier"),
            u"version":          pkg_info.get("version"),
            u"shadowHash":       shadow_hash,
        }
        if u"picture" in user and len(user[u"picture"]):
            output_data[u"imagePath"] = user[u"picture"][0]
        if u"jpegphoto" in user and len(user[u"jpegphoto"]):
            output_data[u"imageData"] = user[u"jpegphoto"][0]
        if kcpassword:
            output_data[u"kcPassword"] = plistlib.Data(kcpassword)
        plistlib.writePlist(output_data, sys.stdout)
        
    finally:
        shutil.rmtree(tmp_path, ignore_errors=True)
    
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

