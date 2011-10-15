h1. The Blob Server

h2. What is it?

 * A RESTful http service for storing blobs of data and getting them back again
 * A helper script for interacting with that service from the shell

h2. Why?

To avoid storing WFE tarball binaries in SVN.

 * quicker svn checkouts, updates, and merges
 * when we start using git-svn, the resulting git repository will be that much smaller

h2. The server

The base of the URL is hard-wired into the "blob" script.  You'll almost certainly need to update it (BASE_URL) before use.

Its interface is:

h3. PUT $BASE_URL/blob/upload

Stores the request body as a blob.  Generates a blob ID (it's the SHA1 checksum) and creates the resource $BASE_URL/blob/<ID>.  Returns 201 Created, Location: $BASE_URL/blob/<ID>; the body of the 201 response is the blob ID (plus a newline), type=text/plain.

h3. GET $BASE_URL/blob/<id>

Fetches a previously-stored blob.  Responds 200 OK with the blob content if it exists; 404 Not Found if not.

h3. Source

Here's an implementation in Apache2 + mod_perl: https://github.com/rvedotrc/blob-server

h2. The helper script

The helper script is bin/blob inside the blob-server codebase.

wfedev@pc-s043863:~$ blob help
Usage:
    blob put < somefile         # store blob, show ID
    blob get ID                 # show blob
    blob mv somefile newfile    # store somefile as blob, make newfile a link to it
    blob fetch [DIR]            # resolve dangling blob symlinks by fetching blobs
    blob tidy [DIR]             # remove any fetched blobs not referred to by symlinks
    blob help                   # show this help


So for example:

wfedev@pc-s043863:~$ echo 'Hello, world!' | blob put
09fac8dbfd27bd9b4d23a00eb648aa751789536d
wfedev@pc-s043863:~$ blob get 09fac8dbfd27bd9b4d23a00eb648aa751789536d
Hello, world!
wfedev@pc-s043863:~$

The idea of the symlinks is that instead of storing large files in SVN we store symlinks referring to blobs.  An svn checkout checks out the symlinks, which initially "dangle"; the blob tool then retrieves the blobs, thus resolving the symlinks so they don't dangle any more.

A blob-ref symlink is one whose target is "blob.<ID>".

wfedev@pc-s043863:$ ls -l
total 0
lrwxrwxrwx 1 wfedev wfedev 45 2011-06-09 12:44 i86pc-solaris-thread-multi.tar.gz -> blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev 45 2011-06-09 12:44 x86_64-linux-thread-multi.tar.gz -> blob.801edecb8ddd2b4dd806394b4421eca740f6f303
wfedev@pc-s043863:$ wc -c *.tar.gz
wc: i86pc-solaris-thread-multi.tar.gz: No such file or directory
wc: x86_64-linux-thread-multi.tar.gz: No such file or directory
0 total
wfedev@pc-s043863:$ 

We can then use "blob fetch" to retrieve the missing blobs:

wfedev@pc-s043863:$ blob fetch
wfedev@pc-s043863:$ ls -l
total 30612
-rw-r--r-- 1 wfedev wfedev 16259252 2011-06-09 14:33 blob.801edecb8ddd2b4dd806394b4421eca740f6f303
-rw-r--r-- 1 wfedev wfedev 15040932 2011-06-09 14:33 blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 12:44 i86pc-solaris-thread-multi.tar.gz -> blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 12:44 x86_64-linux-thread-multi.tar.gz -> blob.801edecb8ddd2b4dd806394b4421eca740f6f303
wfedev@pc-s043863:$ wc -c *.tar.gz
15040932 i86pc-solaris-thread-multi.tar.gz
16259252 x86_64-linux-thread-multi.tar.gz
31300184 total
wfedev@pc-s043863:$ 

To create or modify a symlinked blob, use "blob mv":
wfedev@pc-s043863:$ echo 'Hello, world!' > hello-world
wfedev@pc-s043863:$ blob mv hello-world x86_64-linux-thread-multi.tar.gz
wfedev@pc-s043863:$ ls -l
total 30616
-rw-r--r-- 1 wfedev wfedev       14 2011-06-09 14:34 blob.09fac8dbfd27bd9b4d23a00eb648aa751789536d
-rw-r--r-- 1 wfedev wfedev 16259252 2011-06-09 14:33 blob.801edecb8ddd2b4dd806394b4421eca740f6f303
-rw-r--r-- 1 wfedev wfedev 15040932 2011-06-09 14:33 blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 12:44 i86pc-solaris-thread-multi.tar.gz -> blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 14:34 x86_64-linux-thread-multi.tar.gz -> blob.09fac8dbfd27bd9b4d23a00eb648aa751789536d
wfedev@pc-s043863:$

You would then svn add / svn commit the symlink (and not the blob).

To remove any blobs which aren't referenced by blob-ref symlinks, use "blob tidy":
wfedev@pc-s043863:$ blob tidy
wfedev@pc-s043863:$ ls -l
total 14716
-rw-r--r-- 1 wfedev wfedev       14 2011-06-09 14:34 blob.09fac8dbfd27bd9b4d23a00eb648aa751789536d
-rw-r--r-- 1 wfedev wfedev 15040932 2011-06-09 14:33 blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 12:44 i86pc-solaris-thread-multi.tar.gz -> blob.9c27e2cafe3a2dbace9136bb17ed8759e27dda56
lrwxrwxrwx 1 wfedev wfedev       45 2011-06-09 14:34 x86_64-linux-thread-multi.tar.gz -> blob.09fac8dbfd27bd9b4d23a00eb648aa751789536d
wfedev@pc-s043863:$


