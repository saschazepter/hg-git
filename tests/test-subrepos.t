Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init --bare repo.git
  Initialized empty Git repository in $TESTTMP/repo.git/

  $ git init gitsubrepo
  Initialized empty Git repository in $TESTTMP/gitsubrepo/.git/
  $ cd gitsubrepo
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'
  $ cd ..

  $ git clone repo.git gitrepo
  Cloning into 'gitrepo'...
  warning: You appear to have cloned an empty repository.
  done.
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m 'add alpha'
  $ git submodule add ../gitsubrepo subrepo1
  Cloning into '*subrepo1'... (glob)
  done.
  $ fn_git_commit -m 'add subrepo1'
  $ git submodule add ../gitsubrepo xyz/subrepo2
  Cloning into '*xyz/subrepo2'... (glob)
  done.
  $ fn_git_commit -m 'add subrepo2'
  $ git push
  To $TESTTMP/repo.git
   * [new branch]      master -> master
  $ cd ..
Ensure gitlinks are transformed to .hgsubstate on hg pull from git
  $ hg clone -u tip repo.git hgrepo 2>&1 | egrep -v '^(Cloning into|done)'
  importing 3 git commits
  new changesets e532b2bfda10:88c5e06a2a29 (3 drafts)
  updating to branch default
  cloning subrepo subrepo1 from $TESTTMP/gitsubrepo
  cloning subrepo xyz/subrepo2 from $TESTTMP/gitsubrepo
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd hgrepo
  $ hg bookmarks -f -r default master
1. Ensure gitlinks are transformed to .hgsubstate on hg <- git pull
.hgsub shall list two [git] subrepos
  $ cat .hgsub
  subrepo1 = [git]../gitsubrepo
  xyz/subrepo2 = [git]../gitsubrepo
.hgsubstate shall list two idenitcal revisions
  $ cat .hgsubstate
  56f0304c5250308f14cfbafdc27bd12d40154d17 subrepo1
  56f0304c5250308f14cfbafdc27bd12d40154d17 xyz/subrepo2
hg status shall NOT report .hgsub and .hgsubstate as untracked - either ignored or unmodified
  $ hg status --unknown .hgsub .hgsubstate
  $ hg status --modified .hgsub .hgsubstate
  $ cd ..

2. Check gitmodules are preserved during hg -> git push
  $ cd gitsubrepo
  $ echo gamma > gamma
  $ git add gamma
  $ fn_git_commit -m 'add gamma'
  $ cd ..
  $ cd hgrepo
  $ cd xyz/subrepo2
  $ git pull --ff-only | sed 's/files/file/;s/insertions/insertion/;s/, 0 deletions.*//' | sed 's/|  */| /'
  From $TESTTMP/gitsubrepo
     56f0304..aabf7cd  master     -> origin/master
  Updating 56f0304..aabf7cd
  Fast-forward
   gamma | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 gamma
  $ cd ../..
  $ echo xxx >> alpha
  $ fn_hg_commit -m 'Update subrepo2 from hg' | grep -v "committing subrepository" || true
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  adding objects
  added 1 commits with 2 trees and 1 blobs
  updating reference refs/heads/master
  $ cd ..
  $ cd gitrepo
  $ git pull --ff-only
  From $TESTTMP/repo
     89c22d7..275b0a5  master     -> origin/master
  Fetching submodule xyz/subrepo2
  From $TESTTMP/gitsubrepo
     56f0304..aabf7cd  master     -> origin/master
  Updating 89c22d7..275b0a5
  Fast-forward
   alpha        | 1 +
   xyz/subrepo2 | 2 +-
   2 files changed, 2 insertions(+), 1 deletion(-)
there shall be two gitlink entries, with values matching that in .hgsubstate
  $ git ls-tree -r HEAD^{tree} | grep 'commit'
  160000 commit 56f0304c5250308f14cfbafdc27bd12d40154d17	subrepo1
  160000 commit aabf7cd015089aff0b84596e69aa37b24a3d090a	xyz/subrepo2
bring working copy to HEAD state (it's not bare repo)
  $ git reset --hard
  HEAD is now at 275b0a5 Update subrepo2 from hg
  $ cd ..

3. Check .hgsub and .hgsubstate from git repository are merged, not overwritten
  $ hg init hgsub
  $ cd hgsub
  $ echo delta > delta
  $ hg add delta
  $ fn_hg_commit -m "add delta"
  $ hg tip --template '{node} hgsub\n' > ../gitrepo/.hgsubstate
  $ cat > ../gitrepo/.hgsub <<EOF
  > hgsub = ../hgsub
  > EOF
  $ cd ../gitrepo
  $ git add .hgsubstate .hgsub
  $ fn_git_commit -m "Test3. Prepare .hgsub and .hgsubstate sources"
  $ git push
  To $TESTTMP/repo.git
     275b0a5..e31d576  master -> master

  $ cd ../hgrepo
  $ hg pull
  pulling from $TESTTMP/repo.git
  importing 1 git commits
  updating bookmark master
  new changesets [0-9a-f]{12,12} \(1 drafts\) (re)
  (run 'hg update' to get a working copy)
  $ hg checkout -C
  updating to active bookmark master
  cloning subrepo hgsub from $TESTTMP/hgsub
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd ..
pull shall bring .hgsub entry which was added to the git repo
  $ cat hgrepo/.hgsub
  hgsub = ../hgsub
  subrepo1 = [git]../gitsubrepo
  xyz/subrepo2 = [git]../gitsubrepo
.hgsubstate shall list revision of the subrepo added through git repo
  $ cat hgrepo/.hgsubstate
  481ec30d580f333ae3a77f94c973ce37b69d5bda hgsub
  56f0304c5250308f14cfbafdc27bd12d40154d17 subrepo1
  aabf7cd015089aff0b84596e69aa37b24a3d090a xyz/subrepo2

4. Try changing the subrepos from the Mercurial side

  $ cd hgrepo
  $ cat >> .hgsub <<EOF
  > subrepo2 = [git]../gitsubrepo
  > EOF
  $ git clone ../gitsubrepo subrepo2
  Cloning into 'subrepo2'...
  done.
  $ fn_hg_commit -m 'some stuff'
  $ hg push
  pushing to $TESTTMP/repo.git
  no changes made to subrepo hgsub since last push to $TESTTMP/hgsub
  searching for changes
  adding objects
  added 1 commits with 1 trees and 0 blobs
  updating reference refs/heads/master
  $ cd ..

5. But we actually do something quite weird in this case: If a
.gitmodules file exists in the repository, it always wins! In this
case, we break the bidirectional convention, and modify the repository
data. That's odd, so show it:

  $ hg id hgrepo
  e8ddf4fb3ed4 default/master/tip master
  $ hg clone -U repo.git hgrepo2
  importing 6 git commits
  new changesets e532b2bfda10:36bc272d4273 (6 drafts)
  $ hg -R hgrepo2 up :master
  Cloning into '$TESTTMP/hgrepo2/subrepo1'...
  done.
  cloning subrepo hgsub from $TESTTMP/hgsub
  cloning subrepo subrepo1 from $TESTTMP/gitsubrepo
  checking out detached HEAD in subrepository "subrepo1"
  check out a git branch if you intend to make changes
  Cloning into '$TESTTMP/hgrepo2/xyz/subrepo2'...
  done.
  cloning subrepo xyz/subrepo2 from $TESTTMP/gitsubrepo
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved

We broke bidirectionality :(

  $ git diff --stat hgrepo/.hgsub hgrepo2/.hgsub
   {hgrepo => hgrepo2}/.hgsub | 1 -
   1 file changed, 1 deletion(-)
  [1]
  $ hg id hgrepo
  e8ddf4fb3ed4 default/master/tip master
  $ hg id hgrepo2
  36bc272d4273+ default/master/tip master

And even have something weird in the new clone:

  $ hg diff -R hgrepo2
  diff -r 36bc272d4273 .hgsubstate
  --- a/.hgsubstate	Mon Jan 01 00:00:17 2007 +0000
  +++ b/.hgsubstate	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,4 +1,3 @@
   481ec30d580f333ae3a77f94c973ce37b69d5bda hgsub
   56f0304c5250308f14cfbafdc27bd12d40154d17 subrepo1
  -aabf7cd015089aff0b84596e69aa37b24a3d090a subrepo2
   aabf7cd015089aff0b84596e69aa37b24a3d090a xyz/subrepo2
