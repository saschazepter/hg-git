Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m "add alpha"
  $ git branch alpha
  $ git show-ref
  7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03 refs/heads/alpha
  7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03 refs/heads/master

  $ cd ..
  $ hg clone gitrepo hgrepo
  importing 1 git commits
  new changesets ff7a2f2d8d70 (1 drafts)
  updating to bookmark master
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd hgrepo
  $ hg book
     alpha                     0:ff7a2f2d8d70
   * master                    0:ff7a2f2d8d70
  $ hg update -q master
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m 'add beta'


  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m 'add gamma'

  $ hg book -r 1 beta

  $ hg outgoing | grep -v 'searching for changes'
  comparing with $TESTTMP/gitrepo
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  tag:         tip
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  
  $ hg outgoing -r beta
  comparing with $TESTTMP/gitrepo
  searching for changes
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  $ hg outgoing -r master
  comparing with $TESTTMP/gitrepo
  searching for changes
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  tag:         tip
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  

  $ cd ..

some more work on master from git
  $ cd gitrepo

Check state of refs after outgoing
  $ git show-ref
  7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03 refs/heads/alpha
  7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03 refs/heads/master

  $ git checkout master 2>&1 | sed s/\'/\"/g
  Already on "master"
  $ echo delta > delta
  $ git add delta
  $ fn_git_commit -m "add delta"

  $ cd ..

  $ cd hgrepo
this will fail # maybe we should try to make it work
  $ hg outgoing
  comparing with $TESTTMP/gitrepo
  abort: branch 'refs/heads/master' changed on the server, please pull and merge before pushing
  [255]
let's pull and try again
  $ hg pull
  pulling from */gitrepo (glob)
  importing 1 git commits
  not updating diverged bookmark master
  new changesets 25eed24f5e8f (1 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg log --graph
  o  changeset:   3:25eed24f5e8f
  |  tag:         default/master
  |  tag:         tip
  |  parent:      0:ff7a2f2d8d70
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:13 2007 +0000
  |  summary:     add delta
  |
  | @  changeset:   2:953796e1cfd8
  | |  bookmark:    master
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:12 2007 +0000
  | |  summary:     add gamma
  | |
  | o  changeset:   1:47580592d3d6
  |/   bookmark:    beta
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     add beta
  |
  o  changeset:   0:ff7a2f2d8d70
     bookmark:    alpha
     tag:         default/alpha
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  
  $ hg outgoing
  comparing with $TESTTMP/gitrepo
  searching for changes
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  
  $ hg outgoing -r beta
  comparing with $TESTTMP/gitrepo
  searching for changes
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  $ hg outgoing -r master
  comparing with $TESTTMP/gitrepo
  searching for changes
  changeset:   1:47580592d3d6
  bookmark:    beta
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  


  $ cd ..
