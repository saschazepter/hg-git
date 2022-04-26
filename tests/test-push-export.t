Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ cat >> $HGRCPATH <<EOF
  > [hggit]
  > usephases = yes
  > EOF

  $ git init -q --bare repo.git

  $ hg clone repo.git hgrepo
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd hgrepo

Create two commits:

  $ touch alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ hg book -r . master
  $ touch beta
  $ hg add beta
  $ fn_hg_commit -m beta

This should only export one commit:

  $ hg push -v
  pushing to $TESTTMP/repo.git
  finding unexported changesets
  exporting 1 changesets
  converting revision d4b83afc35d1917648f434591929197d472b1c73
  searching for changes
  1 commits found
  adding objects
  added 1 commits with 1 trees and 1 blobs
  adding reference default::refs/heads/master => GIT:2cc4e3d1
  publishing remote HEAD
  $ hg log --graph --template phases
  @  changeset:   1:62966756ea96
  |  tag:         tip
  |  phase:       draft
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     bookmark:    master
     tag:         default/master
     phase:       public
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  

And even if we bookmark it, it still shouldn't be exported, unless
specified:

  $ hg book -r tip not-master
  $ hg push -v -B master
  pushing to $TESTTMP/repo.git
  finding unexported changesets
  exporting 0 changesets
  searching for changes
  publishing remote HEAD
  no changes found
  [1]
  $ hg push -v
  pushing to $TESTTMP/repo.git
  finding unexported changesets
  exporting 1 changesets
  converting revision 62966756ea96e8edda6911302d577a82c5865af3
  searching for changes
  1 commits found
  adding objects
  added 1 commits with 1 trees and 0 blobs
  adding reference default::refs/heads/not-master => GIT:45ff5145
  publishing remote HEAD

Now try the same with the gexport command:

  $ hg debug-remove-hggit-state
  clearing out the git cache data
  $ hg gexport -r master -v
  finding unexported changesets
  exporting 1 changesets
  converting revision d4b83afc35d1917648f434591929197d472b1c73
  $ hg gexport -v
  finding unexported changesets
  exporting 1 changesets
  converting revision 62966756ea96e8edda6911302d577a82c5865af3
