Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m 'add alpha'

  $ git checkout -b branch1 2>&1 | sed s/\'/\"/g
  Switched to a new branch "branch1"
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'

  $ git checkout -b branch2 master 2>&1 | sed s/\'/\"/g
  Switched to a new branch "branch2"
  $ echo gamma > gamma
  $ git add gamma
  $ fn_git_commit -m 'add gamma'

  $ git checkout -b branch3 master 2>&1 | sed s/\'/\"/g
  Switched to a new branch "branch3"
  $ echo epsilon > epsilon
  $ git add epsilon
  $ fn_git_commit -m 'add epsilon'

  $ git checkout -b branch4 master 2>&1 | sed s/\'/\"/g
  Switched to a new branch "branch4"
  $ echo zeta > zeta
  $ git add zeta
  $ fn_git_commit -m 'add zeta'

  $ git checkout master 2>&1 | sed s/\'/\"/g
  Switched to branch "master"
  $ echo delta > delta
  $ git add delta
  $ fn_git_commit -m 'add delta'

  $ git merge -m "Merge branches 'branch1' and 'branch2'" branch1 branch2 | sed "s/the '//;s/' strategy//" | sed 's/^Merge.*octopus.*$/Merge successful/;s/, 0 deletions.*//'  | sed 's/|  */| /'
  Trying simple merge with branch1
  Trying simple merge with branch2
  Merge successful
   beta  | 1 +
   gamma | 1 +
   2 files changed, 2 insertions(+)
   create mode 100644 beta
   create mode 100644 gamma

  $ git merge -m "Merge branches 'branch3' and 'branch4'" branch3 branch4 | sed "s/the '//;s/' strategy//" | sed 's/^Merge.*octopus.*$/Merge successful/;s/, 0 deletions.*//'  | sed 's/|  */| /'
  Trying simple merge with branch3
  Trying simple merge with branch4
  Merge successful
   epsilon | 1 +
   zeta    | 1 +
   2 files changed, 2 insertions(+)
   create mode 100644 epsilon
   create mode 100644 zeta

  $ cd ..
  $ git init -q --bare repo.git

  $ hg clone gitrepo hgrepo
  importing 8 git commits
  new changesets ff7a2f2d8d70:307506d6ae8a (10 drafts)
  updating to bookmark master
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd hgrepo
  $ hg log --graph --style compact | sed 's/\[.*\]//g'
  @    9:7,8   307506d6ae8a   2007-01-01 00:00 +0000   test
  |\     Merge branches 'branch3' and 'branch4'
  | |
  | o    8:3,4   2b07220e422e   2007-01-01 00:00 +0000   test
  | |\     Merge branches 'branch3' and 'branch4'
  | | |
  o | |    7:5,6   ccf2d65d982c   2007-01-01 00:00 +0000   test
  |\ \ \     Merge branches 'branch1' and 'branch2'
  | | | |
  | o | |    6:1,2   690b40256117   2007-01-01 00:00 +0000   test
  | |\ \ \     Merge branches 'branch1' and 'branch2'
  | | | | |
  o | | | |  5:0   e459c0629ca4   2007-01-01 00:00 +0000   test
  | | | | |    add delta
  | | | | |
  +-------o  4:0   e857c9a04474   2007-01-01 00:00 +0000   test
  | | | |      add zeta
  | | | |
  +-----o  3:0   0071dec0de0e   2007-01-01 00:00 +0000   test
  | | |      add epsilon
  | | |
  +---o  2:0   205a004356ef   2007-01-01 00:00 +0000   test
  | |      add gamma
  | |
  | o  1   7fe02317c63d   2007-01-01 00:00 +0000   test
  |/     add beta
  |
  o  0   ff7a2f2d8d70   2007-01-01 00:00 +0000   test
       add alpha
  
  $ hg gverify -r 9
  verifying rev 307506d6ae8a against git commit b32ff845df61df998206b630e4370a44f9b36845
  $ hg gverify -r 8
  abort: no git commit found for rev 2b07220e422e
  (if this is an octopus merge, verify against the last rev)
  [255]

  $ hg debug-remove-hggit-state
  clearing out the git cache data
  $ hg push ../repo.git
  pushing to ../repo.git
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 8 commits with 8 trees and 6 blobs
  adding reference refs/heads/branch1
  adding reference refs/heads/branch2
  adding reference refs/heads/branch3
  adding reference refs/heads/branch4
  adding reference refs/heads/master
  $ cd ..

  $ git --git-dir=repo.git log --pretty=medium | sed s/\\.\\.\\.//g
  commit b32ff845df61df998206b630e4370a44f9b36845
  Merge: 9ac68f9 7e9cd9f e695849
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:15 2007 +0000
  
      Merge branches 'branch3' and 'branch4'
  
  commit 9ac68f982ae7426d9597ff16c74afb4e6053c582
  Merge: d40f375 9497a4e e5023f9
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:15 2007 +0000
  
      Merge branches 'branch1' and 'branch2'
  
  commit d40f375a81b7d033e92cbad89487115fe2dd472f
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:15 2007 +0000
  
      add delta
  
  commit e695849087f6c320c1a447620492b29a82ca41b1
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:14 2007 +0000
  
      add zeta
  
  commit 7e9cd9f90b6d2c60579375eb796ce706d2d8bbe6
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:13 2007 +0000
  
      add epsilon
  
  commit e5023f9e5cb24fdcec7b6c127cec45d8888e35a9
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:12 2007 +0000
  
      add gamma
  
  commit 9497a4ee62e16ee641860d7677cdb2589ea15554
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:11 2007 +0000
  
      add beta
  
  commit 7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03
  Author: test <test@example.org>
  Date:   Mon Jan 1 00:00:10 2007 +0000
  
      add alpha
