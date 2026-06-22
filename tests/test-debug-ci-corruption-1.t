  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ for i in $(seq 10)
  > do
  >   for f in $(seq 10)
  >   do
  >     n=$(expr $i \* $f)
  >     echo $n > $f
  >     git add $f
  >     fn_git_commit -m $n
  >   done
  >   fn_git_tag -m $i v$i
  > done

  $ hg version
  Mercurial Distributed SCM (version *) (glob)
  (see https://mercurial-scm.org for more information)
  
  Copyright (C) 2005-* Olivia Mackall and others (glob)
  This is free software; see the source for copying conditions. There is NO
  warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
