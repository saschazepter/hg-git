#testcases bookmarks branches topic

Pushing to Git
==============

Detached HEAD
-------------

Most remote Git repositories reside on a hosting service, such as
Github or GitLab, and have HEAD pointing to the default branch,
usually `master` or `main`. Local repositories, can end up in a
detached state, where HEAD rather than being a symref pointing to
another ref, is a direct ref pointing to a commit.

This test excercises that specific edge case: Pushing to a repository
with a detached head. With publishing-on-push, there are two possible
failure modes we want to prevent.

1) Did we assume that HEAD is a symref?
2) What happens when you push to a descendent of HEAD, but HEAD is draft?


Load commonly used test logic
  $ . "$TESTDIR/testutil"

#if branches
  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > hg-git-mode = branches
  > EOF
#endif
#if topic no-evolve
  $ echo 'requires evolve extensions'
  $ exit 80
#endif
#if topic
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > topic =
  > [experimental]
  > hg-git-mode = topic
  > EOF
#endif

Create a Git repository with a detached head

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m "add alpha"
  $ git checkout --detach master
  HEAD is now at 7eeab2e add alpha
  $ git log --graph --all --decorate=short
  * commit 7eeab2ea75ec1ac0ff3d500b5b6f8a3447dd7c03 (HEAD, master)
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        add alpha
  $ cd ..

Verify that we can push to a Git repository that has a detached HEAD

With detection of HEAD on push, it is easy to implicitly assume that
HEAD is a symref. To prevent this, we specifically verify that pushing
in this case continues to work.

  $ hg clone gitrepo hgrepo
  importing 1 git commits
  new changesets ff7a2f2d8d70 (1 drafts)
  warning: the git source repository has a detached head (no-bookmarks !)
  (you may want to update to another commit) (no-bookmarks !)
  updating to branch default (no-bookmarks !)
  updating to bookmark master (bookmarks !)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd hgrepo
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m "add beta"

Pushing that changeset, with phases, publishes the detached HEAD.
Whether this should happen is debatable, but it's a side effect from
the fact that pushing to the remote HEAD, with HEAD being the usual
symref, should publish it.

  $ hg push
  pushing to $TESTTMP/gitrepo
  searching for changes
  adding objects
  remote: found 0 deltas to reuse
  added 1 commits with 1 trees and 1 blobs
  updating reference refs/heads/master
  $ hg push -v --config hggit.usephases=yes
  pushing to $TESTTMP/gitrepo
  finding unexported changesets
  searching for changes
  publishing remote HEAD
  no changes found
  [1]
  $ hg log --graph --style=phases
  @  changeset:   1:47580592d3d6
  |  bookmark:    master (bookmarks !)
  |  tag:         default/master
  |  tag:         tip
  |  phase:       draft
  |  user:        test
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     add beta
  |
  o  changeset:   0:ff7a2f2d8d70
     phase:       public
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  
  $ cd ..

