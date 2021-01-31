Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init --bare repo.git
  Initialized empty Git repository in $TESTTMP/repo.git/

  $ git clone repo.git gitrepo
  Cloning into 'gitrepo'...
  warning: You appear to have cloned an empty repository.
  done.
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m "add alpha"
  $ git push --set-upstream origin master
  To $TESTTMP/repo.git
   * [new branch]      master -> master
  Branch 'master' set up to track remote branch 'master' from 'origin'.

  $ cd ..
  $ hg clone -U repo.git hgrepo
  importing git objects into hg

  $ cd hgrepo
  $ hg co master | egrep -v '^\(activating bookmark master\)$'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ fn_hg_tag alpha
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  updating reference refs/heads/master
  adding reference refs/tags/alpha

  $ hg log --graph
  @  changeset:   1:e8b150f84560
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     Added tag alpha for changeset ff7a2f2d8d70
  |
  o  changeset:   0:ff7a2f2d8d70
     tag:         alpha
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  

  $ cd ..
  $ cd gitrepo
git should have the tag alpha
  $ git fetch origin
  From $TESTTMP/repo
     7eeab2e..bbae830  master     -> origin/master
   * [new tag]         alpha      -> alpha
  $ cd ..

  $ hg clone repo.git hgrepo2
  importing git objects into hg
  updating to branch default (no-hg57 !)
  updating to bookmark master (hg57 !)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R hgrepo2 log --graph
  @  changeset:   1:e8b150f84560
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     Added tag alpha for changeset ff7a2f2d8d70
  |
  o  changeset:   0:ff7a2f2d8d70
     tag:         alpha
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  

the tag should be in .hgtags
  $ cat hgrepo2/.hgtags
  ff7a2f2d8d7099694ae1e8b03838d40575bebb63 alpha
