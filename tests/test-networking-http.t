Our script to serve a Git repository over HTTP uses os.fork(), so no
Windows for this test.

#require serve no-windows

Load commonly used test logic
  $ . "$TESTDIR/testutil"

Allow password prompts without a TTY:

  $ cat << EOF > get_pass.py
  > from __future__ import generator_stop
  > from mercurial import pycompat
  > import getpass, os, sys
  > def newgetpass(args):
  >     try:
  >       passwd = os.environb.get(b'PASSWD', b'nope')
  >       print(passwd.encode())
  >     except AttributeError: # python 2.7
  >       passwd = os.environ.get('PASSWD', 'nope')
  >       print(passwd)
  >     sys.stdout.flush()
  >     return passwd
  > getpass.getpass = newgetpass
  > EOF
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > getpass = $TESTTMP/get_pass.py
  > EOF

Create a test repository

  $ git init --quiet --bare repo.git
  $ hg init hgrepo
  $ cd hgrepo
  $ echo foo>foo
  $ mkdir foo.d foo.d/bAr.hg.d foo.d/baR.d.hg
  $ echo foo>foo.d/foo
  $ echo bar>foo.d/bAr.hg.d/BaR
  $ echo bar>foo.d/baR.d.hg/bAR
  $ hg book master
  $ hg commit -A -m 1
  adding foo
  adding foo.d/bAr.hg.d/BaR
  adding foo.d/baR.d.hg/bAR
  adding foo.d/foo
  $ cd ..

Serve it!

  $ $PYTHON $TESTDIR/git-serve.py $TESTTMP/repo.git $HGPORT2 > /dev/null 2>&1 &

Clone it!

  $ hg clone git+http://localhost:$HGPORT2/ hggitrepo
  abort: http authorization required for http://localhost:$HGPORT2/
  [255]
  $ hg clone git+http://user:secret@localhost:$HGPORT2/ hggitrepo
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

The credentials aren't persisted

  $ hg -R hggitrepo pull
  pulling from git+http://user@localhost:$HGPORT2/
  abort: http authorization required for http://user@localhost:$HGPORT2/
  [255]

We can specify them manually

  $ echo user | PASSWD=secret hg -R hggitrepo --config ui.interactive=yes pull git+http://user@localhost:$HGPORT2/
  pulling from git+http://user@localhost:$HGPORT2/
  http authorization required for http://user@localhost:$HGPORT2/
  realm: Git (no-dulwich0203 !)
  realm: The Test Suite (dulwich0203 !)
  user: user
  password: secret

...and in an auth config

  $ hg -R hggitrepo pull git+http://localhost:$HGPORT2/ \
  >    --config auth.git.prefix=http://localhost:$HGPORT2/ \
  >    --config auth.git.username=user \
  >    --config auth.git.password=secret
  pulling from git+http://localhost:$HGPORT2/

Is this a bug?

  $ hg -R hggitrepo pull \
  >    --config auth.git.prefix=http://localhost:$HGPORT2/ \
  >    --config auth.git.username=user \
  >    --config auth.git.password=secret
  pulling from git+http://user@localhost:$HGPORT2/
  abort: http authorization required for http://user@localhost:$HGPORT2/
  [255]

#if dulwich0200
Try using git credentials, only supported on Dulwich 0.20+

NB: the use of printf is deliberate; otherwise the test fails due to
dulwich considering the newline part of the url

  $ printf http://user:secret@localhost:$HGPORT2/ > $TESTTMP/.git-credentials
  $ hg -R hggitrepo pull
  pulling from git+http://user@localhost:$HGPORT2/
  $ rm -f $TESTTMP/.git-credentials
#endif

Now try pushing

  $ hg -R hggitrepo pull -u hgrepo
  pulling from hgrepo
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  adding remote bookmark master
  added 1 changesets with 4 changes to 4 files
  new changesets 8b6053c928fe
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R hggitrepo push
  pushing to git+http://user@localhost:$HGPORT2/
  abort: http authorization required for http://user@localhost:$HGPORT2/
  [255]

Not even "user" can do that

  $ echo user | PASSWD=secret hg -R hggitrepo --config ui.interactive=yes push
  pushing to git+http://user@localhost:$HGPORT2/
  http authorization required for http://user@localhost:$HGPORT2/
  realm: The Test Suite (dulwich0200 !)
  realm: Git (no-dulwich0200 !)
  user: user
  password: secret
  searching for changes
  adding objects
  abort: git remote error: unexpected http resp 403 for http://user@localhost:$HGPORT2/git-receive-pack
  [255]

I have the power!!!!

  $ echo admin | PASSWD=secret hg -R hggitrepo --config ui.interactive=yes push
  pushing to git+http://user@localhost:$HGPORT2/
  http authorization required for http://user@localhost:$HGPORT2/
  realm: The Test Suite (dulwich0200 !)
  realm: Git (no-dulwich0200 !)
  user: admin
  password: secret
  searching for changes
  adding objects
  added 1 commits with 4 trees and 2 blobs
  adding reference refs/heads/master
