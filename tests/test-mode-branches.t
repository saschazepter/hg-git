Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > hg-git-mode = branches
  > [hggit]
  > usephases = yes
  > [git]
  > defaultbranch = main
  > EOF
  $ cat >> $TESTTMP/.gitconfig <<EOF
  > [init]
  > defaultBranch = main
  > EOF
  $ git init --bare repo.git
  Initialized empty Git repository in $TESTTMP/repo.git/

#if no-git228
prior to Git 2.28, bare repositories had no HEAD, so define one
  $ GIT_DIR=repo.git git symbolic-ref HEAD refs/heads/main
#endif

  $ hg clone repo.git hgrepo
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd hgrepo

Create two commits, one secret:

  $ touch alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ touch beta
  $ hg add beta
  $ hg branch -fq thebranch
  $ fn_hg_commit --secret -m beta
  $ hg up 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg branch -fq thebranch
  $ touch gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg phase 'all()'
  0: draft
  1: secret
  2: draft

Push only pushes the two draft commits, and publishes default:

  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 2 commits with 2 trees and 1 blobs
  adding reference refs/heads/main
  adding reference refs/heads/thebranch
  $ hg bookmarks
  no bookmarks set
  $ hg phase -r default
  0: public
  $ hg pull
  pulling from $TESTTMP/repo.git
  no changes found
  $ hg phase -r default
  0: public
  $ hg log --graph --template=phases
  @  changeset:   2:8904f9a8e8d8
  |  branch:      thebranch
  |  tag:         default/thebranch
  |  tag:         tip
  |  phase:       draft
  |  parent:      0:d4b83afc35d1
  |  user:        test
  |  date:        Mon Jan 01 00:00:12 2007 +0000
  |  summary:     gamma
  |
  | o  changeset:   1:29e8d812a2dd
  |/   branch:      thebranch
  |    phase:       secret
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     tag:         default/main
     phase:       public
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  
  $ cd ..

  $ GIT_DIR=repo.git \
  > git log --all --pretty=oneline --decorate=short
  0d62b9c0b45df42951e0d78ef57e550f828db686 (thebranch) gamma
  2cc4e3d19551e459a0dd606f4cf890de571c7d33 (HEAD -> main) alpha

Try pushing a branch with multiple heads:

  $ cd hgrepo
  $ hg phase -d 1
  $ hg heads thebranch
  changeset:   2:8904f9a8e8d8
  branch:      thebranch
  tag:         default/thebranch
  tag:         tip
  parent:      0:d4b83afc35d1
  user:        test
  date:        Mon Jan 01 00:00:12 2007 +0000
  summary:     gamma
  
  changeset:   1:29e8d812a2dd
  branch:      thebranch
  user:        test
  date:        Mon Jan 01 00:00:11 2007 +0000
  summary:     beta
  
  $ hg push
  pushing to $TESTTMP/repo.git
  warning: not pushing branch 'thebranch' as it has multiple heads: 29e8d812a2dd, 8904f9a8e8d8
  searching for changes
  no changes found
  [1]
  $ hg up 1
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg commit --close-branch -m 'close branch head'
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  no changes found
  [1]
  $ cd ..

Now try creating new commits on the Git side of things:

  $ git clone repo.git gitrepo
  Cloning into 'gitrepo'...
  done.
  $ cd gitrepo
  $ touch delta
  $ git add delta
  $ fn_git_commit -m delta
  $ git push
  To $TESTTMP/repo.git
     2cc4e3d..7970b24  main -> main
  $ git checkout -q thebranch
  $ touch epsilon
  $ git add epsilon
  $ fn_git_commit -m epsilon
  $ git push
  To $TESTTMP/repo.git
     0d62b9c..2a5a61e  thebranch -> thebranch
  $ cd ..

We expect it the commit to 'thebranch' to wind up on it:

  $ cd hgrepo
  $ hg pull
  pulling from $TESTTMP/repo.git
  importing 2 git commits
  new changesets db332cb6377d:f413394b4fc4 (1 drafts)
  (run 'hg heads' to see heads)
  $ hg log --graph --template=phases
  o  changeset:   5:f413394b4fc4
  |  branch:      thebranch
  |  tag:         default/thebranch
  |  tag:         tip
  |  phase:       draft
  |  parent:      2:8904f9a8e8d8
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:14 2007 +0000
  |  summary:     epsilon
  |
  | o  changeset:   4:db332cb6377d
  | |  tag:         default/main
  | |  phase:       public
  | |  parent:      0:d4b83afc35d1
  | |  user:        test <test@example.org>
  | |  date:        Mon Jan 01 00:00:13 2007 +0000
  | |  summary:     delta
  | |
  | | @  changeset:   3:d5b964fddf49
  | | |  branch:      thebranch
  | | |  phase:       draft
  | | |  parent:      1:29e8d812a2dd
  | | |  user:        test
  | | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | | |  summary:     close branch head
  | | |
  o | |  changeset:   2:8904f9a8e8d8
  |/ /   branch:      thebranch
  | |    phase:       draft
  | |    parent:      0:d4b83afc35d1
  | |    user:        test
  | |    date:        Mon Jan 01 00:00:12 2007 +0000
  | |    summary:     gamma
  | |
  | o  changeset:   1:29e8d812a2dd
  |/   branch:      thebranch
  |    phase:       draft
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     phase:       public
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  

And indeed it does!

  $ hg id --branch -r default/thebranch
  thebranch
  $ cd ..

And we can push safely:

  $ cd hgrepo
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  no changes found
  [1]
  $ cd ..

  $ cd hgrepo
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  no changes found
  [1]
  $ hg merge default/thebranch
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ fn_hg_commit -m "merge with git"
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 3 commits with 2 trees and 0 blobs
  updating reference refs/heads/thebranch
  $ cd ..

Now try creating a tag that on a detached head:

  $ cd gitrepo
  $ git pull --ff-only
  From $TESTTMP/repo
     2a5a61e..b5d24d4  thebranch  -> origin/thebranch
  Updating 2a5a61e..b5d24d4
  Fast-forward
   beta | 0
   1 file changed, 0 insertions(+), 0 deletions(-)
   create mode 100644 beta
  $ git checkout --quiet HEAD
  $ touch zeta
  $ git add zeta
  $ fn_git_commit -m zeta
  $ git tag thetag
  $ git push origin thetag
  To $TESTTMP/repo.git
   * [new tag]         thetag -> thetag
  $ cd ..

  $ cd hgrepo
  $ hg pull
  pulling from $TESTTMP/repo.git
  importing 1 git commits
  new changesets e5e9a57e8b04
  5 local changesets published
  (run 'hg update' to get a working copy)
  $ hg log --graph --template=phases
  o  changeset:   7:e5e9a57e8b04
  |  tag:         thetag
  |  tag:         tip
  |  phase:       public
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:16 2007 +0000
  |  summary:     zeta
  |
  @    changeset:   6:561bd24d482d
  |\   branch:      thebranch
  | |  tag:         default/thebranch
  | |  phase:       public
  | |  parent:      3:d5b964fddf49
  | |  parent:      5:f413394b4fc4
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:15 2007 +0000
  | |  summary:     merge with git
  | |
  | o  changeset:   5:f413394b4fc4
  | |  branch:      thebranch
  | |  phase:       public
  | |  parent:      2:8904f9a8e8d8
  | |  user:        test <test@example.org>
  | |  date:        Mon Jan 01 00:00:14 2007 +0000
  | |  summary:     epsilon
  | |
  | | o  changeset:   4:db332cb6377d
  | | |  tag:         default/main
  | | |  phase:       public
  | | |  parent:      0:d4b83afc35d1
  | | |  user:        test <test@example.org>
  | | |  date:        Mon Jan 01 00:00:13 2007 +0000
  | | |  summary:     delta
  | | |
  _ | |  changeset:   3:d5b964fddf49
  | | |  branch:      thebranch
  | | |  phase:       public
  | | |  parent:      1:29e8d812a2dd
  | | |  user:        test
  | | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | | |  summary:     close branch head
  | | |
  | o |  changeset:   2:8904f9a8e8d8
  | |/   branch:      thebranch
  | |    phase:       public
  | |    parent:      0:d4b83afc35d1
  | |    user:        test
  | |    date:        Mon Jan 01 00:00:12 2007 +0000
  | |    summary:     gamma
  | |
  o |  changeset:   1:29e8d812a2dd
  |/   branch:      thebranch
  |    phase:       public
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     phase:       public
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  no changes found
  [1]
  $ cd ..

  $ hg clone repo.git hgrepo-clone
  importing 8 git commits
  new changesets d4b83afc35d1:e5e9a57e8b04
  updating to branch default
  5 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg log --graph -R hgrepo-clone
  @  changeset:   7:e5e9a57e8b04
  |  tag:         thetag
  |  tag:         tip
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:16 2007 +0000
  |  summary:     zeta
  |
  o    changeset:   6:561bd24d482d
  |\   branch:      thebranch
  | |  tag:         default/thebranch
  | |  parent:      3:d5b964fddf49
  | |  parent:      5:f413394b4fc4
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:15 2007 +0000
  | |  summary:     merge with git
  | |
  | o  changeset:   5:f413394b4fc4
  | |  branch:      thebranch
  | |  user:        test <test@example.org>
  | |  date:        Mon Jan 01 00:00:14 2007 +0000
  | |  summary:     epsilon
  | |
  | o  changeset:   4:8904f9a8e8d8
  | |  branch:      thebranch
  | |  parent:      0:d4b83afc35d1
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:12 2007 +0000
  | |  summary:     gamma
  | |
  _ |  changeset:   3:d5b964fddf49
  | |  branch:      thebranch
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  summary:     close branch head
  | |
  o |  changeset:   2:29e8d812a2dd
  |/   branch:      thebranch
  |    parent:      0:d4b83afc35d1
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  | o  changeset:   1:db332cb6377d
  |/   tag:         default/main
  |    user:        test <test@example.org>
  |    date:        Mon Jan 01 00:00:13 2007 +0000
  |    summary:     delta
  |
  o  changeset:   0:d4b83afc35d1
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  
  $ rm -rf hgrepo-clone
