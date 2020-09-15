This test demonstrates how Hg works with remote Hg bookmarks compared with
remote branches via Hg-Git.  Ideally, they would behave identically.  In
practice, some differences are unavoidable, but we should try to minimize
them.

This test should not bother testing the behavior of bookmark creation,
deletion, activation, deactivation, etc.  These behaviors, while important to
the end user, don't vary at all when Hg-Git is in use.  Only the synchonization
of bookmarks should be considered "under test", and mutation of bookmarks
locally is only to provide a test fixture.

Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ gitstate()
  > {
  >     git log --format="  %h \"%s\" refs:%d" $@ | sed 's/HEAD, //'
  > }
  $ hgstate()
  > {
  >     hg log --template "  {rev} {node|short} \"{desc}\" bookmarks: [{bookmarks}]\n" $@
  > }
  $ hggitstate()
  > {
  >     hg log --template "  {rev} {node|short} {gitnode|short} \"{desc}\" bookmarks: [{bookmarks}] ({phase})\n" $@
  > }

Initialize remote hg and git repos with equivalent initial contents
  $ hg init hgremoterepo
  $ cd hgremoterepo
  $ hg bookmark master
  $ for f in alpha beta gamma delta; do
  >     echo $f > $f; hg add $f; fn_hg_commit -m "add $f"
  > done
  $ hg bookmark -r 1 b1
  $ hgstate
    3 e13efaebbf5d "add delta" bookmarks: [master]
    2 79c2b4d7c021 "add gamma" bookmarks: []
    1 a7b2ac5cbfff "add beta" bookmarks: [b1]
    0 0221c246a567 "add alpha" bookmarks: []
  $ cd ..
  $ git init -q gitremoterepo
  $ cd gitremoterepo
  $ for f in alpha beta gamma delta; do
  >     echo $f > $f; git add $f; fn_git_commit -m "add $f"
  > done
  $ git branch b1 master~2
  $ gitstate
    a6f0c96 "add delta" refs: (HEAD -> master)
    50eec90 "add gamma" refs:
    7fe1d3e "add beta" refs: (b1)
    09d573a "add alpha" refs:
  $ cd ..

Cloning transfers all bookmarks from remote to local
  $ hg clone -q hgremoterepo purehglocalrepo
  $ cd purehglocalrepo
  $ hgstate
    3 e13efaebbf5d "add delta" bookmarks: [master]
    2 79c2b4d7c021 "add gamma" bookmarks: []
    1 a7b2ac5cbfff "add beta" bookmarks: [b1]
    0 0221c246a567 "add alpha" bookmarks: []
  $ cd ..
  $ hg clone -q gitremoterepo hggitlocalrepo --config hggit.usephases=True
  $ cd hggitlocalrepo
  $ hggitstate
    3 57bd6fdbfc89 a6f0c9606388 "add delta" bookmarks: [master] (public)
    2 8e6f0b6e003b 50eec9088321 "add gamma" bookmarks: [] (public)
    1 06243e99b1c7 7fe1d3ee3c97 "add beta" bookmarks: [b1] (public)
    0 6f6e65e2d214 09d573a23a7c "add alpha" bookmarks: [] (public)

Make sure that master is public
  $ hg phase -r master
  3: public
  $ cd ..

No changes
  $ cd purehglocalrepo
  $ hg incoming -B
  comparing with $TESTTMP/hgremoterepo
  searching for changed bookmarks
  no changed bookmarks found
  [1]
  $ hg outgoing
  comparing with $TESTTMP/hgremoterepo
  searching for changes
  no changes found
  [1]
  $ hg outgoing -B
  comparing with $TESTTMP/hgremoterepo
  searching for changed bookmarks
  no changed bookmarks found
  [1]
  $ hg push
  pushing to $TESTTMP/hgremoterepo
  searching for changes
  no changes found
  [1]
  $ cd ..
  $ cd hggitlocalrepo
  $ hg incoming -B
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
  no changed bookmarks found
  [1]
  $ hg outgoing
  comparing with $TESTTMP/gitremoterepo
  searching for changes
  no changes found
  [1]
  $ hg outgoing -B
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
  no changed bookmarks found
  [1]
  $ hg push
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  no changes found
  [1]
  $ cd ..

Bookmarks on existing revs:
- change b1 on local repo
- introduce b2 on local repo
- introduce b3 on remote repo
Bookmarks on new revs
- introduce b4 on a new rev on the remote
  $ cd hgremoterepo
  $ hg bookmark -r master b3
  $ hg bookmark -r master b4
  $ hg update -q b4
  $ echo epsilon > epsilon; hg add epsilon; fn_hg_commit -m 'add epsilon'
  $ hgstate
    4 a0deb1724eba "add epsilon" bookmarks: [b4]
    3 e13efaebbf5d "add delta" bookmarks: [b3 master]
    2 79c2b4d7c021 "add gamma" bookmarks: []
    1 a7b2ac5cbfff "add beta" bookmarks: [b1]
    0 0221c246a567 "add alpha" bookmarks: []
  $ cd ..
  $ cd purehglocalrepo
  $ hg bookmark -fr 2 b1
  $ hg bookmark -r 0 b2
  $ hgstate
    3 e13efaebbf5d "add delta" bookmarks: [master]
    2 79c2b4d7c021 "add gamma" bookmarks: [b1]
    1 a7b2ac5cbfff "add beta" bookmarks: []
    0 0221c246a567 "add alpha" bookmarks: [b2]
  $ hg incoming -B
  comparing with $TESTTMP/hgremoterepo
  searching for changed bookmarks
     b3                        e13efaebbf5d
     b4                        a0deb1724eba
  $ hg outgoing
  comparing with $TESTTMP/hgremoterepo
  searching for changes
  no changes found
  [1]
As of 2.3, Mercurial's outgoing -B doesn't actually show changed bookmarks
It only shows "new" bookmarks.  Thus, b1 doesn't show up.
This changed in 3.4 to start showing changed and deleted bookmarks again.
  $ hg outgoing -B | grep -v -E -w 'b1|b3|b4'
  comparing with $TESTTMP/hgremoterepo
  searching for changed bookmarks
     b2                        0221c246a567
  $ cd ..

  $ cd gitremoterepo
  $ git branch b3 master
  $ git checkout -b b4 master
  Switched to a new branch 'b4'
  $ echo epsilon > epsilon
  $ git add epsilon
  $ fn_git_commit -m 'add epsilon'
  $ gitstate
    0692ae9 "add epsilon" refs: (HEAD -> b4)
    a6f0c96 "add delta" refs: (master, b3)
    50eec90 "add gamma" refs:
    7fe1d3e "add beta" refs: (b1)
    09d573a "add alpha" refs:
  $ cd ..
  $ cd hggitlocalrepo
  $ hg bookmark -fr 2 b1
  $ hg bookmark -r 0 b2
  $ hgstate
    3 57bd6fdbfc89 "add delta" bookmarks: [master]
    2 8e6f0b6e003b "add gamma" bookmarks: [b1]
    1 06243e99b1c7 "add beta" bookmarks: []
    0 6f6e65e2d214 "add alpha" bookmarks: [b2]
  $ hg incoming -B
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
     b3                        57bd6fdbfc89
     b4                        0692ae9f6aef
  $ hg outgoing
  comparing with $TESTTMP/gitremoterepo
  searching for changes
  no changes found
  [1]
As of 2.3, Mercurial's outgoing -B doesn't actually show changed bookmarks
It only shows "new" bookmarks.  Thus, b1 doesn't show up.
This changed in 3.4 to start showing changed and deleted bookmarks again.
  $ hg outgoing -B
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
     b1                        8e6f0b6e003b
     b2                        6f6e65e2d214
     b3                                    
     b4                                    
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  importing git objects into hg
  not updating diverged bookmark b1
  adding bookmark b3
  adding bookmark b4
  (run 'hg update' to get a working copy)
  $ cd ..

Delete a branch, but with the bookmark elsewhere, it remains

  $ cd gitremoterepo
  $ git branch -d b1
  Deleted branch b1 (was 7fe1d3e).
  $ cd ../hggitlocalrepo
  $ hg book -fr b2 b1
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  not deleting diverged bookmark b1
  $ hggitstate
    4 5a854f9ca5d9 0692ae9f6aef "add epsilon" bookmarks: [b4] (draft)
    3 57bd6fdbfc89 a6f0c9606388 "add delta" bookmarks: [b3 master] (public)
    2 8e6f0b6e003b 50eec9088321 "add gamma" bookmarks: [] (public)
    1 06243e99b1c7 7fe1d3ee3c97 "add beta" bookmarks: [] (public)
    0 6f6e65e2d214 09d573a23a7c "add alpha" bookmarks: [b1 b2] (public)
  $ cd ..

But with the bookmark unmoved, it disappears!

  $ cd gitremoterepo
  $ git branch b1 master~2
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  updating bookmark b1
  $ cd ../gitremoterepo
  $ git branch -d b1
  Deleted branch b1 (was 7fe1d3e).
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  deleting bookmark b1
  $ hggitstate
    4 5a854f9ca5d9 0692ae9f6aef "add epsilon" bookmarks: [b4] (draft)
    3 57bd6fdbfc89 a6f0c9606388 "add delta" bookmarks: [b3 master] (public)
    2 8e6f0b6e003b 50eec9088321 "add gamma" bookmarks: [] (public)
    1 06243e99b1c7 7fe1d3ee3c97 "add beta" bookmarks: [] (public)
    0 6f6e65e2d214 09d573a23a7c "add alpha" bookmarks: [b2] (public)
  $ cd ..

Now push the new branch

  $ cd hggitlocalrepo
  $ hg push
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  not adding bookmark b2
  no changes found
  [1]
  $ hg push -B b2
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  adding reference refs/heads/b2
  $ cd ..

Verify that phase restriction works as expected

  $ cd gitremoterepo
  $ gitstate
    0692ae9 "add epsilon" refs: (HEAD -> b4)
    a6f0c96 "add delta" refs: (master, b3)
    50eec90 "add gamma" refs:
    7fe1d3e "add beta" refs:
    09d573a "add alpha" refs: (b2)
  $ git checkout -b b5 b2
  Switched to a new branch 'b5'
  $ echo zeta > zeta; git add zeta; fn_git_commit -m 'add zeta'
  $ cd ../hggitlocalrepo
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > rebase =
  > [experimental]
  > evolution.createmarkers = yes
  > # required by mercurial 4.3
  > evolution = all
  > [hggit]
  > usephases = yes
  > [git]
  > public = master
  > EOF
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  importing git objects into hg
  adding bookmark b5
  (run 'hg heads' to see heads, 'hg merge' to merge)

The new branches shouldn't be published!

  $ hggitstate
    5 9d36e6184837 29550a664fc6 "add zeta" bookmarks: [b5] (draft)
    4 5a854f9ca5d9 0692ae9f6aef "add epsilon" bookmarks: [b4] (draft)
    3 57bd6fdbfc89 a6f0c9606388 "add delta" bookmarks: [b3 master] (public)
    2 8e6f0b6e003b 50eec9088321 "add gamma" bookmarks: [] (public)
    1 06243e99b1c7 7fe1d3ee3c97 "add beta" bookmarks: [] (public)
    0 6f6e65e2d214 09d573a23a7c "add alpha" bookmarks: [b2] (public)

Now, do a fast-forward merge one of them, and verify that it gets
published, but that nothing else does

  $ cd ../gitremoterepo
  $ git checkout master
  Switched to branch 'master'
  $ git merge -q b4
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  updating bookmark master
  $ hg phase b5
  5: draft
  $ hg phase master
  4: public

Now, merge the other

  $ cd ../gitremoterepo
  $ git checkout master
  Already on 'master'
  $ git merge -q b5
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  importing git objects into hg
  updating bookmark master
  (run 'hg update' to get a working copy)
  $ hggitstate
    6 78d000decab1 58fcef5c774c "Merge branch 'b5'" bookmarks: [master] (public)
    5 9d36e6184837 29550a664fc6 "add zeta" bookmarks: [b5] (public)
    4 5a854f9ca5d9 0692ae9f6aef "add epsilon" bookmarks: [b4] (public)
    3 57bd6fdbfc89 a6f0c9606388 "add delta" bookmarks: [b3] (public)
    2 8e6f0b6e003b 50eec9088321 "add gamma" bookmarks: [] (public)
    1 06243e99b1c7 7fe1d3ee3c97 "add beta" bookmarks: [] (public)
    0 6f6e65e2d214 09d573a23a7c "add alpha" bookmarks: [b2] (public)
  $ cd ..

Push a branch, rebase it, and verify that it doesn't break anything

  $ cd hggitlocalrepo
  $ hg up b2
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark b2)
  $ echo eta > eta
  $ hg add eta
  $ fn_hg_commit -m 'add eta'
  $ hg push --new-branch
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  updating reference refs/heads/b2
  $ hg rebase -r b2 -d 1
  rebasing 7:5cbe87f37299 * (glob)
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  not updating diverged bookmark b2
  $ hg book -d b2
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  adding bookmark b2
  $ hg log -r b2 --template '{obsolete}\n'
  obsolete
  $ hg book -f -r tip b2
  $ hg push
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  abort: pushing refs/heads/b2 overwrites c8aac37d39f5
  [255]
  $ hg push -fr b2
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  updating reference refs/heads/b2
  $ cd ..

Verify that pulling already existing, published changesets from git
doesn't unpublish changesets. This is a three-step operation: 1) Pull
and publish changesets from Git. 2) Transfer those changesets to
another Mercurial repository, which loses the hg-git state. 3) Pull
from Git, but without publishing enabled. Previously, the final
operation would cause the changesets to revert to draft state.

First, enact the full workflow:

  $ hg clone -q hggitlocalrepo hggitlocalrepo-2
  $ hg -R hggitlocalrepo-2 phase tip
  7: public
  $ hg -R hggitlocalrepo-2 pull gitremoterepo
  pulling from gitremoterepo
  importing git objects into hg
  (run 'hg update' to get a working copy)
  $ hg -R hggitlocalrepo-2 phase tip
  7: public
  $ rm -rf hggitlocalrepo-2

Then, reproduce explicitly:

  $ cd hggitlocalrepo
  $ hg phase -r master
  6: public
  $ hg gclear
  clearing out the git cache data
  $ hg pull --config hggit.usephases=no
  pulling from $TESTTMP/gitremoterepo
  importing git objects into hg
  (run 'hg update' to get a working copy)
  $ hg phase -r master
  6: public
  $ cd ..

Try pushing the currently active bookmark

  $ cd gitremoterepo
  $ git branch -q -D b2
  $ cd ../hggitlocalrepo
  $ hg up -q b2
  $ hg push -B .
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  adding reference refs/heads/b2
  $ hg book -i
  $ hg push -B .
  abort: no active bookmark!? (re)
  [255]
  $ cd ..
