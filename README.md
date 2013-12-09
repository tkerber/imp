IMP (IMP Manager for Passwords)
===============================

A small and simple console based password manager.

Uses 256-bit AES encryption to encrypt a tree struction of saved passwords
with a master password. Provides a basic interactive environment to print
and copy these passwords.

Allows working with encrypted passwords without them ever appearing on-screen
(due to the copy functionality) as they would if using a simple encrypted
password file, but without the bloat of larger password managers.

##TODO

* More descriptive --help message.
* Create tests. Seriously. (I have to figure out how/if to test the heavily
  I/O based classes)
