This project is no longer maintained
====================================

Please see the [blog post](https://magervalp.github.io/2016/12/07/createuserpkg-up-for-adoption.html).

Download
========

Download CreateUserPkg from the project homepage at [http://magervalp.github.com/CreateUserPkg/](http://magervalp.github.com/CreateUserPkg/)


Overview
========

This utility creates packages that create local user accounts when installed. The packages can create users on 10.5+, and they are compatible with all workflows that can install standard installer pkgs. For the details on how the packages work, see Greg Neagle's article in the [May 2012 issue of MacTech](http://www.mactech.com/issue-TOCs-2012).


Security Notes
--------------

Packages created using this utility encrypts the password as a salted SHA1 hash, which is how 10.5 and 10.6 normally stores it. Using a dictionary based attack they are reasonably easy to crack on modern machines, so make sure you pick a good, strong password. In 10.7 and up this is converted to PBKDF2 upon first login, which is much harder to crack, but the SHA1 hash can still be extracted from the package.

If you enable automatic login the password is stored in a kcpassword file, which is merely obfuscated and not encrypted - extracting the password (no matter how strong) is trivial.


Credits
-------

* Code by Per Olofsson, <per.olofsson@gu.se>
* User deployment method by Greg Neagle
* Bash plist modification code by Michael Lynn


Version History
---------------

* 1.2.5 (in beta)
    * Fixed automatic login on 10.9+ (thanks to Greg Neagle).
* 1.2.4
    * Fixed permissions for users to change their name, password, picture, etc (thanks to Greg Collen).
* 1.2.3
    * Allow packages with empty password (thanks to Dan Keller).
* 1.2.2
    * Fixed automatic logins that only worked on 2nd boot (thanks to Joseph Chilcote).
* 1.2.1
    * Fixed empty password hash when you clicked Save without leaving the Password/Verify field (thanks to ih84ds).
* 1.2
    * Added automatic login using kcpassword.
    * Package now adds users to admin group instead of using primary group 80 (thanks to Michael Lynn, Jason Bush, Greg Neagle). Primary group is always 20.
* 1.1
    * create_user.pkg files can now be opened for editing.
    * Added user picture.
    * App is now sandboxed.
* 1.0.3
    * Fixed Package ID and Version being set incorrectly.
* 1.0.2
    * Fixed ownership of items in package Payload.
    * Changed salted sha1 shadow hash to upper case which fixes authentication on 10.5 and 10.6 (thanks to Allister Banks).
* 1.0.1
    * Fixed postinstall script for 10.6 (thanks to Allister Banks).
* 1.0
    * Initial release.


License
-------

    Copyright 2012 Per Olofsson
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
        http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
