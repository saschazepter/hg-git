Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m "add alpha"
  $ git checkout -b not-master
  Switched to a new branch 'not-master'

  $ cd ..
  $ hg clone gitrepo hgrepo
  importing 1 git commits
  new changesets ff7a2f2d8d70 (1 drafts)
  updating to bookmark not-master
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd hgrepo
  $ hg co master
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg mv alpha beta
  $ fn_hg_commit -m 'rename alpha to beta'
  $ hg push
  pushing to $TESTTMP/gitrepo
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 1 commits with 1 trees and 0 blobs
  updating reference refs/heads/master

  $ hg branch gamma | grep -v 'permanent and global'
  marked working directory as branch gamma
  $ fn_hg_commit -m 'started branch gamma'
  $ hg push
  pushing to $TESTTMP/gitrepo
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 1 commits with 1 trees and 0 blobs
  updating reference refs/heads/master

  $ hg log --graph
  @  changeset:   2:400db38f4f64
  |  branch:      gamma
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:12 2007 +0000
  |  summary:     started branch gamma
  |
  o  changeset:   1:3baa67317a4d
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     rename alpha to beta
  |
  o  changeset:   0:ff7a2f2d8d70
     bookmark:    not-master
     tag:         default/not-master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  

  $ cd ..
  $ hg clone -U gitrepo hgrepo2
  importing 3 git commits
  new changesets ff7a2f2d8d70:400db38f4f64 (3 drafts)
  $ hg -R hgrepo2 log --graph
  o  changeset:   2:400db38f4f64
  |  branch:      gamma
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:12 2007 +0000
  |  summary:     started branch gamma
  |
  o  changeset:   1:3baa67317a4d
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     rename alpha to beta
  |
  o  changeset:   0:ff7a2f2d8d70
     bookmark:    not-master
     tag:         default/not-master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  
