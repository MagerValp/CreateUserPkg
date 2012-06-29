#!/usr/bin/python
#
#  create_package.py
#  CreateUserPkg
#
#  Created by Per Olofsson on 2012-06-20.
#  Copyright (c) 2012 Per Olofsson. All rights reserved.


import os
import sys
import optparse
import plistlib
import hashlib
import tempfile
import subprocess
import shutil
import stat
import gzip


REQUIRED_KEYS = set((
    u"fullName",
    u"accountName",
    u"shadowHash",
    u"userID",
    u"groupID",
    u"homeDirectory",
    u"uuid",
    u"packageID",
    u"version",
))

POSTINSTALL = """#!/bin/sh
#
# postinstall for local account install

if [ "$3" == "/" ]; then
    # we're operating on the boot volume
    # kill local directory service so it will see our local
    # file changes -- it will automatically restart
    os_major_ver=`/usr/bin/uname -r | /usr/bin/cut -d. -f1`
    if [ $os_major_ver -le 10 ]; then
        # Snow Leopard or Leopard
        echo "Restarting DirectoryService"
        /usr/bin/killall DirectoryService
    else
        # Lion or later
        echo "Restarting opendirectoryd"
        /usr/bin/killall opendirectoryd
    fi
fi
exit 0
"""
PACKAGE_INFO = """
<pkg-info format-version="2" identifier="_BUNDLE_ID_" version="_VERSION_" install-location="/" auth="root">
    <payload installKBytes="_KBYTES_" numberOfFiles="_NFILES_"/>
    <scripts>
        <postinstall file="./postinstall"/>
    </scripts>
</pkg-info>"""


ODC_HDR_SIZES = (6, 6, 6, 6, 6, 6, 6, 6, 11, 6, 11)

def fix_cpio_owners(f, new_uid=lambda x: 0, new_gid=lambda x: 0):
    """
    Change ownership of items in a cpio archive. new_uid and new_gid are
    functions that take an archive path as the argument, and return the
    new uid and gid. By default they are set to 0 (root:wheel). Returns
    a list of strings suitable for writelines().
    """
    output = list()
    while True:
        # Read and decode ODC header
        header = f.read(sum(ODC_HDR_SIZES))
        values = list()
        offset = 0
        for size in ODC_HDR_SIZES:
            values.append(int(header[offset:offset+size], 8))
            offset += size
        (magic, 
         dev,
         ino,
         mode,
         uid,
         gid,
         nlink,
         rdev,
         mtime,
         namesize,
         filesize) = values
        # Read name and data
        name = f.read(namesize)
        data = f.read(filesize)
        # Generate a new record, replacing uid and gid
        output.append("%06o%06o%06o%06o%06o%06o%06o%06o%011o%06o%011o" % (
                      magic,
                      dev,
                      ino,
                      mode,
                      new_uid(name[:-1]),
                      new_gid(name[:-1]),
                      nlink,
                      rdev,
                      mtime,
                      namesize,
                      filesize))
        output.append(name)
        output.append(data)
        # TRAILER!!! indicates the end of the archive
        if name == "TRAILER!!!\x00":
            break
    # Append padding
    output.append(f.read())
    return output
    

def get_bom_info(path):
    st = os.lstat(path)
    info = [
            path,
            "%o" % st.st_mode,
            "0/0", # "%d/%d" % (st.st_uid, st.st_gid),
            ]
    if not stat.S_ISDIR(st.st_mode):
        info.append("%d" % st.st_size)
        p = subprocess.Popen(["/usr/bin/cksum", path.encode("utf-8")],
                             stdout=subprocess.PIPE)
        out, _ = p.communicate()
        cksum, space, rest = out.partition(" ")
        info.append(cksum)
    return info


def generate_bom_lines(root_path):
    bom = list()
    old_cd = os.getcwd()
    os.chdir(root_path)
    bom.append("\t".join(get_bom_info(".")))
    for (dirpath, dirnames, filenames) in os.walk("."):
        for path in [os.path.join(dirpath, p) for p in sorted(dirnames + filenames)]:
            bom.append("\t".join(get_bom_info(path)))
    os.chdir(old_cd)
    return bom


def shell(*args):
    sys.stdout.flush()
    return subprocess.call(args)
    

def main(argv):
    
    input_data = plistlib.readPlist(sys.stdin)
    
    # Ensure all required keys are given on the command line.
    for key in REQUIRED_KEYS:
        if key not in input_data:
            print >>sys.stderr, "Missing key: %s" % repr(key)
            return 1
    
    # Create a dictionary with user attributes.
    user_plist = dict()
    user_plist[u"authentication_authority"] = [u";ShadowHash;"]
    user_plist[u"generateduid"] = [input_data[u"uuid"]]
    user_plist[u"gid"] = [input_data[u"groupID"]]
    user_plist[u"home"] = [input_data[u"homeDirectory"]]
    user_plist[u"name"] = [input_data[u"accountName"]]
    user_plist[u"passwd"] = [u"********"]
    user_plist[u"realname"] = [input_data[u"fullName"]]
    user_plist[u"shell"] = [u"/bin/bash"]
    user_plist[u"uid"] = [input_data[u"userID"]]
    if u"imagePath" in input_data:
        user_plist[u"picture"] = [input_data[u"imagePath"]]
    if u"imageData" in input_data:
        user_plist[u"jpegphoto"] = [input_data[u"imageData"]]
    
    # Get name, version, package ID, and shadow hash.
    utf8_username = input_data[u"accountName"].encode("utf-8")
    pkg_version = input_data[u"version"]
    pkg_name = "create_%s-%s" % (utf8_username, pkg_version)
    pkg_id = input_data[u"packageID"]
    shadow_hash = input_data[u"shadowHash"]
    
    # Create a package with the plist for our user and a shadow hash file.
    tmp_path = tempfile.mkdtemp()
    try:
        # Create a root for the package.
        pkg_root_path = os.path.join(tmp_path, "create_user")
        os.mkdir(pkg_root_path)
        # Create package structure inside root.
        os.makedirs(os.path.join(pkg_root_path, "private/var/db/dslocal/nodes"), 0755)
        os.makedirs(os.path.join(pkg_root_path, "private/var/db/dslocal/nodes/Default/users"), 0700)
        os.makedirs(os.path.join(pkg_root_path, "private/var/db/shadow/hash"), 0700)
        # Save user plist.
        user_plist_name = "%s.plist" % utf8_username
        user_plist_path = os.path.join(pkg_root_path,
                                       "private/var/db/dslocal/nodes/Default/users",
                                       user_plist_name)
        plistlib.writePlist(user_plist, user_plist_path)
        os.chmod(user_plist_path, 0600)
        # Save shadow hash.
        shadow_hash_name = input_data[u"uuid"]
        shadow_hash_path = os.path.join(pkg_root_path,
                                        "private/var/db/shadow/hash",
                                        shadow_hash_name)
        f = open(shadow_hash_path, "w")
        f.write(shadow_hash)
        f.close()
        os.chmod(shadow_hash_path, 0600)
        
        # Create a flat package structure.
        flat_pkg_path = os.path.join(tmp_path, pkg_name + "_pkg")
        scripts_path = os.path.join(flat_pkg_path, "Scripts")
        os.makedirs(scripts_path, 0755)
        # Create postinstall script.
        postinstall_path = os.path.join(scripts_path, "postinstall")
        f = open(postinstall_path, "w")
        f.write(POSTINSTALL)
        f.close()
        os.chmod(postinstall_path, 0755)
        # Create Bom.
        tmp_bom_path = os.path.join(tmp_path, "Bom.txt")
        f = open(tmp_bom_path, "w")
        f.write("\n".join(generate_bom_lines(pkg_root_path)))
        f.write("\n")
        f.close()
        bom_path = os.path.join(flat_pkg_path, "Bom")
        if shell("/usr/bin/mkbom", "-i", tmp_bom_path, bom_path) != 0:
            return 2
        # Create Payload.
        tmp_payload_path = os.path.join(tmp_path, "Payload")
        if shell("/usr/bin/ditto", "-cz", pkg_root_path, tmp_payload_path) != 0:
            return 2
        payload_path = os.path.join(flat_pkg_path, "Payload")
        user_payload_f = gzip.open(tmp_payload_path)
        root_payload_f = gzip.open(payload_path, "wb")
        root_payload_f.writelines(fix_cpio_owners(user_payload_f))
        root_payload_f.close()
        user_payload_f.close()
        # Create PackageInfo
        package_info_path = os.path.join(flat_pkg_path, "PackageInfo")
        package_info = PACKAGE_INFO
        package_info = package_info.replace("_BUNDLE_ID_", pkg_id)
        package_info = package_info.replace("_VERSION_", pkg_version)
        package_info = package_info.replace("_KBYTES_", "8") # FIXME: calculate
        package_info = package_info.replace("_NFILES_", "12") # FIXME: calculate
        f = open(package_info_path, "w")
        f.write(package_info)
        f.close()
        # Flatten package with pkgutil.
        pkg_path = os.path.join(tmp_path, pkg_name + ".pkg")
        if shell("/usr/sbin/pkgutil", "--flatten", flat_pkg_path, pkg_path) != 0:
            return 2
        # Write the flattened pkg to stdout as a plist.
        f = open(pkg_path)
        output_data = {
            u"data": plistlib.Data(f.read())
        }
        f.close()
        plistlib.writePlist(output_data, sys.stdout)

    except (OSError, IOError), e:
        print >>sys.stderr, "Package creation failed: %s" % e
        return 2
    finally:
        shutil.rmtree(tmp_path, ignore_errors=True)
    
    return 0
    

if __name__ == '__main__':
    sys.exit(main(sys.argv))
    
