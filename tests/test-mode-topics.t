#require evolve

Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > topic =
  > evolve =
  > [experimental]
  > hg-git-mode = topic
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

Create two branches, with a topic each:

  $ touch alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ hg branch thebranch
  marked working directory as branch thebranch
  (branches are permanent and global, did you want a bookmark?)
  $ touch beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ hg topic thetopic
  marked working directory as topic: thetopic
  $ touch gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg up default
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ hg topic thetopic
  marked working directory as topic: thetopic
  $ touch delta
  $ hg add delta
  $ fn_hg_commit -m delta
  $ hg log --graph
  @  changeset:   3:f18d640f9fd5
  |  tag:         tip
  |  topic:       thetopic
  |  parent:      0:d4b83afc35d1
  |  user:        test
  |  date:        Mon Jan 01 00:00:13 2007 +0000
  |  summary:     delta
  |
  | o  changeset:   2:839b200ca49d
  | |  branch:      thebranch
  | |  topic:       thetopic
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:12 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   1:29e8d812a2dd
  |/   branch:      thebranch
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  

We can only push topics with a single head:

  $ hg push
  pushing to $TESTTMP/repo.git
  warning: not pushing topic 'thetopic' as it has multiple heads: 839b200ca49d, f18d640f9fd5
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 2 commits with 2 trees and 1 blobs
  adding reference refs/heads/main
  adding reference refs/heads/thebranch

Renaming one of the heads fixes that:

  $ hg topic -r tip theothertopic
  switching to topic theothertopic
  changed topic on 1 changesets to "theothertopic"
  $ hg push
  pushing to $TESTTMP/repo.git
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 2 commits with 2 trees and 0 blobs
  adding reference refs/heads/theothertopic
  adding reference refs/heads/thetopic
  $ cd ..

  $ GIT_DIR=repo.git \
  > git log --all --pretty=oneline --decorate=short
  b60f1281885171f7cd1fd3bf1f5204687a3d2a9b (theothertopic) delta
  f3f837ee06184e957cc40a0b0c989e3d414b1cfe (thetopic) gamma
  57f330e50e7f0cef1a5352e5ea7c1aac9886d9f8 (thebranch) beta
  2cc4e3d19551e459a0dd606f4cf890de571c7d33 (HEAD -> main) alpha

Now try creating new commits on the Git side of things:

  $ git clone repo.git gitrepo
  Cloning into 'gitrepo'...
  done.
  $ cd gitrepo
  $ touch epsilon
  $ git add epsilon
  $ fn_git_commit -m epsilon
  $ git push
  To $TESTTMP/repo.git
     2cc4e3d..494bb39  main -> main
  $ git checkout -q thetopic
  $ touch eta
  $ git add eta
  $ fn_git_commit -m eta
  $ git push
  To $TESTTMP/repo.git
     f3f837e..ca835e2  thetopic -> thetopic
  $ git checkout -q thebranch
  $ touch zeta
  $ git add zeta
  $ fn_git_commit -m zeta
  $ git push
  To $TESTTMP/repo.git
     57f330e..bdc508a  thebranch -> thebranch
  $ cd ..

  $ GIT_DIR=repo.git \
  > git log --all --graph --pretty=oneline --decorate=short
  * bdc508a97ddfd70f54047ec8f1d9f683b27e1afc (thebranch) zeta
  | * ca835e2ac394a7833889a9a9db8cca9392370b0a (thetopic) eta
  | * f3f837ee06184e957cc40a0b0c989e3d414b1cfe gamma
  |/  
  * 57f330e50e7f0cef1a5352e5ea7c1aac9886d9f8 beta
  | * 494bb3957b2525ad9c0cf64184bc8e575a68746d (HEAD -> main) epsilon
  |/  
  | * b60f1281885171f7cd1fd3bf1f5204687a3d2a9b (theothertopic) delta
  |/  
  * 2cc4e3d19551e459a0dd606f4cf890de571c7d33 alpha

  $ cd hgrepo
  $ hg pull
  pulling from $TESTTMP/repo.git
  importing 3 git commits
  new changesets 7a8f9e29247a:d6543dbee12a (2 drafts)
  (run 'hg heads' to see heads)
  $ hg log --graph
  o  changeset:   7:d6543dbee12a
  |  tag:         default/thebranch
  |  tag:         tip
  |  topic:       thebranch
  |  parent:      1:29e8d812a2dd
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:16 2007 +0000
  |  summary:     zeta
  |
  | o  changeset:   6:6424bacef6b4
  | |  tag:         default/thetopic
  | |  topic:       thetopic
  | |  parent:      2:839b200ca49d
  | |  user:        test <test@example.org>
  | |  date:        Mon Jan 01 00:00:15 2007 +0000
  | |  summary:     eta
  | |
  | | o  changeset:   5:7a8f9e29247a
  | | |  tag:         default/main
  | | |  parent:      0:d4b83afc35d1
  | | |  user:        test <test@example.org>
  | | |  date:        Mon Jan 01 00:00:14 2007 +0000
  | | |  summary:     epsilon
  | | |
  | | | @  changeset:   4:9ddf491dbcab
  | | |/   tag:         default/theothertopic
  | | |    topic:       theothertopic
  | | |    parent:      0:d4b83afc35d1
  | | |    user:        test
  | | |    date:        Mon Jan 01 00:00:13 2007 +0000
  | | |    summary:     delta
  | | |
  | o |  changeset:   2:839b200ca49d
  |/ /   branch:      thebranch
  | |    topic:       thetopic
  | |    user:        test
  | |    date:        Mon Jan 01 00:00:12 2007 +0000
  | |    summary:     gamma
  | |
  o |  changeset:   1:29e8d812a2dd
  |/   branch:      thebranch
  |    user:        test
  |    date:        Mon Jan 01 00:00:11 2007 +0000
  |    summary:     beta
  |
  o  changeset:   0:d4b83afc35d1
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     alpha
  
  $ cd ..

Try an octopus merge:

  $ cd gitrepo
  $ git checkout main
  Switched to branch 'main'
  Your branch is up to date with 'origin/main'.
  $ git switch -c octopus
  Switched to a new branch 'octopus'
  $ git merge -q -s ours -m 'octopus merge' origin/theothertopic origin/thetopic origin/thebranch
  $ git push --set-upstream origin octopus
  To $TESTTMP/repo.git
   * [new branch]      octopus -> octopus
  branch 'octopus' set up to track 'origin/octopus'.
  $ cd ../hgrepo
  $ hg pull
  pulling from $TESTTMP/repo.git
  importing 1 git commits
  new changesets a0bb1c61db41:4982550363fd (3 drafts)
  (run 'hg update' to get a working copy)
  $ hg log -G -v -r 'topic(octopus)'
  o    changeset:   10:4982550363fd
  |\   tag:         default/octopus
  | ~  tag:         tip
  |    topic:       octopus
  |    parent:      5:7a8f9e29247a
  |    parent:      9:509adbbe5db3
  |    user:        test <test@example.org>
  |    date:        Mon Jan 01 00:00:16 2007 +0000
  |    description:
  |    octopus merge
  |
  |
  o    changeset:   9:509adbbe5db3
  |\   topic:       octopus
  | ~  parent:      4:9ddf491dbcab
  |    parent:      8:a0bb1c61db41
  |    user:        test <test@example.org>
  |    date:        Mon Jan 01 00:00:16 2007 +0000
  |    description:
  |    octopus merge
  |
  |
  o    changeset:   8:a0bb1c61db41
  |\   topic:       octopus
  ~ ~  parent:      6:6424bacef6b4
       parent:      7:d6543dbee12a
       user:        test <test@example.org>
       date:        Mon Jan 01 00:00:16 2007 +0000
       description:
       octopus merge
  
  
  $ cd ..
