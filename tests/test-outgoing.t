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
  importing git objects into hg
  updating to bookmark master (hg57 !)
  updating to branch default (no-hg57 !)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd hgrepo
  $ hg update -q master
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m 'add beta'


  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m 'add gamma'

  $ hg book -r 1 beta

  $ hg outgoing | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  tag:         tip
  git node:    f8e6765efc7a
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  
  $ hg outgoing -r beta | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  $ hg outgoing -r master | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  tag:         tip
  git node:    f8e6765efc7a
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
  comparing with */gitrepo (glob)
  abort: branch 'refs/heads/master' changed on the server, please pull and merge before pushing
  [255]
let's pull and try again
  $ hg pull 2>&1 | grep -v 'divergent bookmark'
  pulling from */gitrepo (glob)
  importing git objects into hg
  not updating diverged bookmark master
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg outgoing | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  git node:    f8e6765efc7a
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  
  $ hg outgoing -r beta | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  $ hg outgoing -r master | grep -v 'searching for changes'
  comparing with */gitrepo (glob)
  changeset:   1:47580592d3d6
  bookmark:    beta
  git node:    0f378ab6c2c6
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  changeset:   2:953796e1cfd8
  bookmark:    master
  git node:    f8e6765efc7a
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add gamma
  


  $ cd ..
