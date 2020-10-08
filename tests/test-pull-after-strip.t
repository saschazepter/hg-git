Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m 'add alpha'

  $ git tag alpha

  $ git checkout -b beta 2>&1 | sed s/\'/\"/g
  Switched to a new branch "beta"
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'


  $ cd ..
clone a tag
  $ hg clone -r alpha gitrepo hgrepo-a
  importing git objects into hg
  updating to bookmark master (hg57 !)
  updating to branch default (no-hg57 !)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R hgrepo-a log --graph
  @  changeset:   0:ff7a2f2d8d70
     bookmark:    master
     tag:         alpha
     tag:         default/master
     tag:         tip
     git node:    7eeab2ea75ec
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  
clone a branch
  $ hg clone -r beta gitrepo hgrepo-b
  importing git objects into hg
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R hgrepo-b log --graph
  @  changeset:   1:7fe02317c63d
  |  bookmark:    beta
  |  tag:         default/beta
  |  tag:         tip
  |  git node:    9497a4ee62e1
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     add beta
  |
  o  changeset:   0:ff7a2f2d8d70
     bookmark:    master
     tag:         alpha
     tag:         default/master
     git node:    7eeab2ea75ec
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  
  $ cd gitrepo
  $ echo beta line 2 >> beta
  $ git add beta
  $ fn_git_commit -m 'add to beta'

  $ cd ..
  $ cd hgrepo-b
  $ hg strip tip 2>&1 | grep -v saving | grep -v backup
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg pull -r beta
  pulling from $TESTTMP/gitrepo
  importing git objects into hg
  abort: you appear to have run strip - please run hg git-cleanup
  [255]
  $ hg git-cleanup
  git commit map cleaned
pull works after 'hg git-cleanup'
"adding remote bookmark" message was added in Mercurial 2.3
  $ hg pull -r beta | grep -v "adding remote bookmark"
  pulling from $TESTTMP/gitrepo
  importing git objects into hg
  updating bookmark beta
  (run 'hg update' to get a working copy)
  $ hg log --graph
  o  changeset:   2:cc1e605d90db
  |  bookmark:    beta
  |  tag:         default/beta
  |  tag:         tip
  |  git node:    c4c17f3e3a70
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:12 2007 +0000
  |  summary:     add to beta
  |
  o  changeset:   1:7fe02317c63d
  |  git node:    9497a4ee62e1
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     add beta
  |
  @  changeset:   0:ff7a2f2d8d70
     bookmark:    master
     tag:         alpha
     tag:         default/master
     git node:    7eeab2ea75ec
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  

  $ cd ..
