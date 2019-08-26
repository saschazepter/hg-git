Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m "add alpha"

  $ cd ..
  $ hg init hgrepo-empty
  $ hg -R hgrepo-empty incoming gitrepo | grep -v 'no changes found'
  comparing with gitrepo
  changeset:   0:7eeab2ea75ec
  bookmark:    master
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:10 2007 +0000
  summary:     add alpha
  

  $ hg clone gitrepo hgrepo | grep -v '^updating'
  importing git objects into hg
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg -R hgrepo incoming | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo

  $ cd gitrepo
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'
  $ cd ..

  $ hg -R hgrepo incoming | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset:   1:9497a4ee62e1
  bookmark:    master
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  

  $ cd gitrepo
  $ git checkout -b b1 HEAD^
  Switched to a new branch 'b1'
  $ mkdir d
  $ echo gamma > d/gamma
  $ git add d/gamma
  $ fn_git_commit -m'add d/gamma'
  $ git tag t1

  $ echo gamma 2 >> d/gamma
  $ git add d/gamma
  $ fn_git_commit -m'add d/gamma line 2'
  $ cd ../hgrepo
  $ hg incoming -p | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset:   1:9497a4ee62e1
  bookmark:    master
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  diff -r ff7a2f2d8d70 -r 9497a4ee62e1 beta
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/beta	Mon Jan 01 00:00:11 2007 +0000
  @@ -0,0 +1,1 @@
  +beta
  
  changeset:   2:9865e289be73
  tag:         t1
  parent:      0:ff7a2f2d8d70
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add d/gamma
  
  diff -r ff7a2f2d8d70 -r 9865e289be73 d/gamma
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/d/gamma	Mon Jan 01 00:00:12 2007 +0000
  @@ -0,0 +1,1 @@
  +gamma
  
  changeset:   3:5202f48c20c9
  bookmark:    b1
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:13 2007 +0000
  summary:     add d/gamma line 2
  
  diff -r 9865e289be73 -r 5202f48c20c9 d/gamma
  --- a/d/gamma	Mon Jan 01 00:00:12 2007 +0000
  +++ b/d/gamma	Mon Jan 01 00:00:13 2007 +0000
  @@ -1,1 +1,2 @@
   gamma
  +gamma 2
  

  $ hg incoming -r master --template 'changeset: {rev}:{node|short}\ngitnode:   {gitnode}\n' | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset: 1:9497a4ee62e1
  gitnode:   9497a4ee62e16ee641860d7677cdb2589ea15554

incoming -r
  $ hg incoming -r master | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset:   1:9497a4ee62e1
  bookmark:    master
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     add beta
  
  $ hg incoming -r b1 | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset:   1:9865e289be73
  tag:         t1
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add d/gamma
  
  changeset:   2:5202f48c20c9
  bookmark:    b1
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:13 2007 +0000
  summary:     add d/gamma line 2
  
  $ hg incoming -r t1 | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
  changeset:   1:9865e289be73
  tag:         t1
  user:        test <test@example.org>
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     add d/gamma
  

nothing incoming after pull
"adding remote bookmark" message was added in Mercurial 2.3
  $ hg pull | grep -v "adding remote bookmark"
  pulling from $TESTTMP/gitrepo
  importing git objects into hg
  adding bookmark b1
  updating bookmark master
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg incoming | grep -v 'no changes found'
  comparing with $TESTTMP/gitrepo
