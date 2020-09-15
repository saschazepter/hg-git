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

  $ gitcount=10
  $ gitcommit()
  > {
  >     GIT_AUTHOR_DATE="2007-01-01 00:00:$gitcount +0000"
  >     GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
  >     git commit "$@" >/dev/null 2>/dev/null || echo "git commit error"
  >     gitcount=`expr $gitcount + 1`
  > }
  $ hgcount=10
  $ hgcommit()
  > {
  >     HGDATE="2007-01-01 00:00:$hgcount +0000"
  >     hg commit -u "test <test@example.org>" -d "$HGDATE" "$@" >/dev/null 2>/dev/null || echo "hg commit error"
  >     hgcount=`expr $hgcount + 1`
  > }
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
  >     echo $f > $f; hg add $f; hgcommit -m "add $f"
  > done
  $ hg bookmark -r 1 b1
  $ hgstate
    3 fc2664cac217 "add delta" bookmarks: [master]
    2 d85ced7ae9d6 "add gamma" bookmarks: []
    1 7bcd915dc873 "add beta" bookmarks: [b1]
    0 3442585be8a6 "add alpha" bookmarks: []
  $ cd ..
  $ git init -q gitremoterepo
  $ cd gitremoterepo
  $ for f in alpha beta gamma delta; do
  >     echo $f > $f; git add $f; gitcommit -m "add $f"
  > done
  $ git branch b1 9497a4e
  $ gitstate
    55b133e "add delta" refs: (*master) (glob)
    d338971 "add gamma" refs:
    9497a4e "add beta" refs: (b1)
    7eeab2e "add alpha" refs:
  $ cd ..

Cloning transfers all bookmarks from remote to local
  $ hg clone -q hgremoterepo purehglocalrepo
  $ cd purehglocalrepo
  $ hgstate
    3 fc2664cac217 "add delta" bookmarks: [master]
    2 d85ced7ae9d6 "add gamma" bookmarks: []
    1 7bcd915dc873 "add beta" bookmarks: [b1]
    0 3442585be8a6 "add alpha" bookmarks: []
  $ cd ..
  $ hg clone -q gitremoterepo hggitlocalrepo --config hggit.usephases=True
  $ cd hggitlocalrepo
  $ hggitstate
    3 03769a650ded 55b133e1d558 "add delta" bookmarks: [master] (public)
    2 ca33a262eb46 d338971a96e2 "add gamma" bookmarks: [] (public)
    1 7fe02317c63d 9497a4ee62e1 "add beta" bookmarks: [b1] (public)
    0 ff7a2f2d8d70 7eeab2ea75ec "add alpha" bookmarks: [] (public)

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
  $ echo epsilon > epsilon; hg add epsilon; hgcommit -m 'add epsilon'
  $ hgstate
    4 d979bb8e0fbb "add epsilon" bookmarks: [b4]
    3 fc2664cac217 "add delta" bookmarks: [b3 master]
    2 d85ced7ae9d6 "add gamma" bookmarks: []
    1 7bcd915dc873 "add beta" bookmarks: [b1]
    0 3442585be8a6 "add alpha" bookmarks: []
  $ cd ..
  $ cd purehglocalrepo
  $ hg bookmark -fr 2 b1
  $ hg bookmark -r 0 b2
  $ hgstate
    3 fc2664cac217 "add delta" bookmarks: [master]
    2 d85ced7ae9d6 "add gamma" bookmarks: [b1]
    1 7bcd915dc873 "add beta" bookmarks: []
    0 3442585be8a6 "add alpha" bookmarks: [b2]
  $ hg incoming -B
  comparing with $TESTTMP/hgremoterepo
  searching for changed bookmarks
     b3                        fc2664cac217
     b4                        d979bb8e0fbb
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
     b2                        3442585be8a6
  $ cd ..

  $ cd gitremoterepo
  $ git branch b3 master
  $ git checkout -b b4 master
  Switched to a new branch 'b4'
  $ echo epsilon > epsilon
  $ git add epsilon
  $ gitcommit -m 'add epsilon'
  $ gitstate
    fcfd2c0 "add epsilon" refs: (*b4) (glob)
    55b133e "add delta" refs: (master, b3)
    d338971 "add gamma" refs:
    9497a4e "add beta" refs: (b1)
    7eeab2e "add alpha" refs:
  $ cd ..
  $ cd hggitlocalrepo
  $ hg bookmark -fr 2 b1
  $ hg bookmark -r 0 b2
  $ hgstate
    3 03769a650ded "add delta" bookmarks: [master]
    2 ca33a262eb46 "add gamma" bookmarks: [b1]
    1 7fe02317c63d "add beta" bookmarks: []
    0 ff7a2f2d8d70 "add alpha" bookmarks: [b2]
  $ hg incoming -B
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
     b3                        03769a650ded
     b4                        fcfd2c0262db
  $ hg outgoing
  comparing with $TESTTMP/gitremoterepo
  searching for changes
  no changes found
  [1]
As of 2.3, Mercurial's outgoing -B doesn't actually show changed bookmarks
It only shows "new" bookmarks.  Thus, b1 doesn't show up.
This changed in 3.4 to start showing changed and deleted bookmarks again.
  $ hg outgoing -B | grep -v -E -w 'b1|b3|b4'
  comparing with $TESTTMP/gitremoterepo
  searching for changed bookmarks
     b2                        ff7a2f2d8d70
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  importing git objects into hg
  not updating changed bookmark b1
  adding bookmark b3
  adding bookmark b4
  (run 'hg update' to get a working copy)
  $ cd ..

Delete a branch, but with the bookmark elsewhere, it remains

  $ cd gitremoterepo
  $ git branch -d b1
  Deleted branch b1 (was 9497a4e).
  $ cd ../hggitlocalrepo
  $ hg book -fr b2 b1
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  not deleting changed bookmark b1
  $ hggitstate
    4 0ac7ec7b4113 fcfd2c0262db "add epsilon" bookmarks: [b4] (draft)
    3 03769a650ded 55b133e1d558 "add delta" bookmarks: [b3 master] (public)
    2 ca33a262eb46 d338971a96e2 "add gamma" bookmarks: [] (public)
    1 7fe02317c63d 9497a4ee62e1 "add beta" bookmarks: [] (public)
    0 ff7a2f2d8d70 7eeab2ea75ec "add alpha" bookmarks: [b1 b2] (public)
  $ cd ..

But with the bookmark unmoved, it disappears!

  $ cd gitremoterepo
  $ git branch b1 9497a4e
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  updating bookmark b1
  $ cd ../gitremoterepo
  $ git branch -d b1
  Deleted branch b1 (was 9497a4e).
  $ cd ../hggitlocalrepo
  $ hg pull
  pulling from $TESTTMP/gitremoterepo
  no changes found
  deleting bookmark b1
  $ hggitstate
    4 0ac7ec7b4113 fcfd2c0262db "add epsilon" bookmarks: [b4] (draft)
    3 03769a650ded 55b133e1d558 "add delta" bookmarks: [b3 master] (public)
    2 ca33a262eb46 d338971a96e2 "add gamma" bookmarks: [] (public)
    1 7fe02317c63d 9497a4ee62e1 "add beta" bookmarks: [] (public)
    0 ff7a2f2d8d70 7eeab2ea75ec "add alpha" bookmarks: [b2] (public)
  $ cd ..

Now verify that we can't push a new branch without --new-branch

  $ cd hggitlocalrepo
  $ hg push
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  adding reference refs/heads/b2
  $ hg push --new-branch
  pushing to $TESTTMP/gitremoterepo
  searching for changes
  no changes found
  [1]
  $ cd ..

Verify that phase restriction works as expected

  $ cd gitremoterepo
  $ gitstate
    fcfd2c0 "add epsilon" refs: (HEAD -> b4)
    55b133e "add delta" refs: (master, b3)
    d338971 "add gamma" refs:
    9497a4e "add beta" refs:
    7eeab2e "add alpha" refs: (b2)
  $ git checkout -b b5 b2
  Switched to a new branch 'b5'
  $ echo zeta > zeta; git add zeta; gitcommit -m 'add zeta'
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
    5 7ab447d0494f 2b8593c2d63c "add zeta" bookmarks: [b5] (public)
    4 0ac7ec7b4113 fcfd2c0262db "add epsilon" bookmarks: [b4] (draft)
    3 03769a650ded 55b133e1d558 "add delta" bookmarks: [b3 master] (public)
    2 ca33a262eb46 d338971a96e2 "add gamma" bookmarks: [] (public)
    1 7fe02317c63d 9497a4ee62e1 "add beta" bookmarks: [] (public)
    0 ff7a2f2d8d70 7eeab2ea75ec "add alpha" bookmarks: [b2] (public)

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
  5: public
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
    6 7ac86d6e9d1d 842c1e660ab3 "Merge branch 'b5'" bookmarks: [master] (public)
    5 7ab447d0494f 2b8593c2d63c "add zeta" bookmarks: [b5] (public)
    4 0ac7ec7b4113 fcfd2c0262db "add epsilon" bookmarks: [b4] (public)
    3 03769a650ded 55b133e1d558 "add delta" bookmarks: [b3] (public)
    2 ca33a262eb46 d338971a96e2 "add gamma" bookmarks: [] (public)
    1 7fe02317c63d 9497a4ee62e1 "add beta" bookmarks: [] (public)
    0 ff7a2f2d8d70 7eeab2ea75ec "add alpha" bookmarks: [b2] (public)
  $ cd ..
