
Load commonly used test logic

  $ . "$TESTDIR/testutil"

  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > evolution = createmarkers
  > evolution.createmarkers = yes
  > [devel]
  > debug.hg-git.find-successors-in=yes
  > EOF

Enable the feature (only for the main branch of the default path)

  $ cat >> $HGRCPATH <<EOF
  > [paths]
  > default:hg-git.find-successors-in=master
  > EOF


Create the three repositories we needs

  $ mkdir base-case
  $ cd base-case
  $ git init --bare --quiet server.git

  $ git clone ./server.git git-repo > /dev/null 2>&1
  $ cd git-repo
  $ git remote set-url origin ../server.git
  $ echo root > root-commit
  $ git add root-commit
  $ fn_git_commit -m 'root commit'
  $ git push --all
  To ../server.git
   * [new branch]      master -> master
  $ cd ..


  $ hg clone -U ./server.git hg-repo
  importing 1 git commits
  new changesets b15403328556 (1 drafts)
  $ hg -R hg-repo update master
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark master)
  $ sed -i "s,$TESTTMP/base-case/,../," ./hg-repo/.hg/hgrc
  $ hg -R hg-repo log -G
  @  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     tag:         tip
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..


Test basic rebase/rewrite detection
===================================

Rebase without content changes
------------------------------

The goal of this test is to check we can detect a simple rebase.

It creates a small branch in Mercurial to be rebased outside of Mercurial.

This is a pure rebase over unrelated change, the changesets should be detected
as replacement.

  $ count=50
  $ cp -r base-case test-basic-rebase
  $ cd test-basic-rebase

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-basic-rebase/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase and merge the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git checkout --quiet master
  $ git merge --ff some-branch
  Updating e4ac97e..7b560c8
  Fast-forward
   alpha | 1 +
   beta  | 1 +
   gamma | 1 +
   3 files changed, 3 insertions(+)
   create mode 100644 alpha
   create mode 100644 beta
   create mode 100644 gamma
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     e4ac97e..7b560c8  master -> master
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pulling the rebase in mercurial should detect the rebase and obsolete the older version
(We update the working copy away to avoid keeping things visible with it)

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-basic-rebase/server.git
  importing 4 git commits
  HG-GIT:INFER_OBS: e91937fd8904 -> 05f94c07c58c
  HG-GIT:INFER_OBS: 67ec0a3230ae -> 47a01f7be6e7
  HG-GIT:INFER_OBS: 0c8e47eb927a -> 45f6ceb621f2
  automatically obsoleted 3 changesets
  updating bookmark master
  updating bookmark some-branch
  3 new obsolescence markers
  obsoleted 3 changesets
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads*) (glob)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  bookmark:    some-branch
  |  tag:         default/master
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  bookmark:    some-branch
  |  tag:         default/master
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | x  changeset:   3:0c8e47eb927a
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 7:45f6ceb621f2
  | |  summary:     gamma
  | |
  | x  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 6:47a01f7be6e7
  | |  summary:     beta
  | |
  | x  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 5:05f94c07c58c
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Update commit message without files changes
-------------------------------------------

The goal of this test is to check we can detect a simple rewrite.

Create a small branch in Mercurial and do small change to the commit message from git.

The changeset should be detected as replacement.

  $ count=50
  $ cp -r base-case test-basic-msg-change
  $ cd test-basic-msg-change

  $ cd hg-repo
  $ hg up master
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg book some-other-branch
  $ echo delta > delta
  $ hg add delta
  $ fn_hg_commit -m delta
  $ hg push -B some-other-branch
  pushing to $TESTTMP/test-basic-msg-change/server.git
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  adding reference refs/heads/some-other-branch
  $ hg log -G
  @  changeset:   1:fcf739bbafc4
  |  bookmark:    some-other-branch
  |  tag:         default/some-other-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     delta
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Pull the changes and update their commit message from git.

  $ cd git-repo
  $ git fetch origin some-other-branch
  From ../server
   * branch            some-other-branch -> FETCH_HEAD
   * [new branch]      some-other-branch -> origin/some-other-branch

  $ git checkout --quiet some-other-branch
  $ fn_git_commit --amend  --message delta-2
  $ git log --graph
  * commit 4bb943850e747062af317d671a5ea13e34061838
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     delta-2
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet master
  $ git merge --ff some-other-branch
  Updating 54dfb14..4bb9438
  Fast-forward
   delta | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 delta
  $ git log --graph
  * commit 4bb943850e747062af317d671a5ea13e34061838
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     delta-2
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     54dfb14..4bb9438  master -> master
   + 3967e38...4bb9438 some-other-branch -> some-other-branch (forced update)
  $ cd ..

Pulling the rewrite in mercurial should detect it and obsolete the older version
(We update the working copy away to avoid keeping things visible with it)

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-basic-msg-change/server.git
  importing 1 git commits
  HG-GIT:INFER_OBS: fcf739bbafc4 -> 10b664f469e4
  automatically obsoleted 1 changesets
  updating bookmark master
  updating bookmark some-other-branch
  1 new obsolescence markers
  obsoleted 1 changesets
  new changesets 10b664f469e4 (1 drafts)
  (run 'hg heads' to see heads*) (glob)
  $ hg -R hg-repo log -G
  o  changeset:   2:10b664f469e4
  |  bookmark:    master
  |  bookmark:    some-other-branch
  |  tag:         default/master
  |  tag:         default/some-other-branch
  |  tag:         tip
  |  parent:      0:b15403328556
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     delta-2
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   2:10b664f469e4
  |  bookmark:    master
  |  bookmark:    some-other-branch
  |  tag:         default/master
  |  tag:         default/some-other-branch
  |  tag:         tip
  |  parent:      0:b15403328556
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     delta-2
  |
  | x  changeset:   1:fcf739bbafc4
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 2:10b664f469e4
  |    summary:     delta
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

New unrelated changeset are not detected as superceeding other ones
-------------------------------------------------------------------

The goal of this test is to check the new feature does not trigger when it
should not.

Create a small branch in Mercurial and add more unrelated changeset in git. No
replacement should be detected.

add a commit on master

  $ count=50
  $ cp -r base-case test-basic-unrelated
  $ cd test-basic-unrelated

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ cd ..

  $ cd git-repo
  $ git checkout --quiet master
  $ cat epsilon > epsilon
  $ git add epsilon
  $ fn_git_commit  --message epsilon
  $ git log --graph
  * commit e86e5d7f9bddc59653a4c736ef8ad06e08a5b42d
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     epsilon
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     54dfb14..e86e5d7  master -> master
  $ cd ..

Pulling the unrelated changeset should not create any obsolescence

  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-basic-unrelated/server.git
  importing 1 git commits
  automatically obsoleted 0 changesets
  updating bookmark master
  new changesets 1c4cddbe0758 (1 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg -R hg-repo log -G
  o  changeset:   4:1c4cddbe0758
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     epsilon
  |
  | @  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  o  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   4:1c4cddbe0758
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         tip
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     epsilon
  |
  | @  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  o  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

New unrelated changeset combined with some rewriting
----------------------------------------------------

The goal of this test is to check that we can mix rewritten and non-rewritten
changeset without confusing the logic.

Create a small branch in Mercurial rewrite it. and add more changesets

Only the replaced changeset should be detected as such

  $ count=50
  $ cp -r base-case test-basic-msg-change-unrelated
  $ cd test-basic-msg-change-unrelated

  $ cd hg-repo
  $ hg up master
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg book branch-change-and-new
  $ echo zita > zita
  $ hg add zita
  $ fn_hg_commit -m zita
  $ hg push -B branch-change-and-new
  pushing to $TESTTMP/test-basic-msg-change-unrelated/server.git
  searching for changes
  adding objects
  added 1 commits with 1 trees and 1 blobs
  adding reference refs/heads/branch-change-and-new
  $ hg log -G
  @  changeset:   1:9520d9292a0c
  |  bookmark:    branch-change-and-new
  |  tag:         default/branch-change-and-new
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     zita
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Pull the change and update its commit message from git and add another changeset.

  $ cd git-repo
  $ git fetch origin branch-change-and-new
  From ../server
   * branch            branch-change-and-new -> FETCH_HEAD
   * [new branch]      branch-change-and-new -> origin/branch-change-and-new

  $ git checkout --quiet branch-change-and-new
  $ fn_git_commit --amend  --message zita-2
  $ cat ita > ita
  $ git add ita
  $ fn_git_commit  --message ita
  $ git log --graph
  * commit a484b464518ff7b66bbbb52a554410da486a4c84
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     ita
  | 
  * commit 93b2324898c3de5307e79fd11620e6dc16d26c3a
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     zita-2
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet master
  $ git merge --ff branch-change-and-new
  Updating 54dfb14..a484b46
  Fast-forward
   ita  | 0
   zita | 1 +
   2 files changed, 1 insertion(+)
   create mode 100644 ita
   create mode 100644 zita
  $ git log --graph
  * commit a484b464518ff7b66bbbb52a554410da486a4c84
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     ita
  | 
  * commit 93b2324898c3de5307e79fd11620e6dc16d26c3a
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     zita-2
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
   + 064b80d...a484b46 branch-change-and-new -> branch-change-and-new (forced update)
     54dfb14..a484b46  master -> master
  $ cd ..

Pulling the new changeset in mercurial should detect the single rewrite only.

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-basic-msg-change-unrelated/server.git
  importing 2 git commits
  HG-GIT:INFER_OBS: 9520d9292a0c -> 63805a492976
  automatically obsoleted 1 changesets
  updating bookmark branch-change-and-new
  updating bookmark master
  1 new obsolescence markers
  obsoleted 1 changesets
  new changesets 63805a492976:f91f264e694f (2 drafts)
  (run 'hg heads' to see heads*) (glob)
  $ hg -R hg-repo log -G
  o  changeset:   3:f91f264e694f
  |  bookmark:    branch-change-and-new
  |  bookmark:    master
  |  tag:         default/branch-change-and-new
  |  tag:         default/master
  |  tag:         tip
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     ita
  |
  o  changeset:   2:63805a492976
  |  parent:      0:b15403328556
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     zita-2
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   3:f91f264e694f
  |  bookmark:    branch-change-and-new
  |  bookmark:    master
  |  tag:         default/branch-change-and-new
  |  tag:         default/master
  |  tag:         tip
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     ita
  |
  o  changeset:   2:63805a492976
  |  parent:      0:b15403328556
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     zita-2
  |
  | x  changeset:   1:9520d9292a0c
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 2:63805a492976
  |    summary:     zita
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..


Check we only process the target item
=====================================

Check that we only check possible replacement under the specified branch
------------------------------------------------------------------------

We first rebase the changes, but keep them outside of the master branch. Since
we only select replacement under master they are not selected for replacement.

  $ count=50
  $ cp -r base-case test-target-rebase
  $ cd test-target-rebase

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-target-rebase/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pull will not search for replacement as the new changeset are not under a tracked branch.

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-target-rebase/server.git
  importing 4 git commits
  automatically obsoleted 0 changesets
  updating bookmark master
  not updating diverged bookmark some-branch
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..


Check we do not (try to) obsolete changeset that are public
-----------------------------------------------------------

The changesets were rebased, but the source changeset became public before we
pull. No marker will be created.

  $ count=50
  $ cp -r base-case test-target-public
  $ cd test-target-public

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-target-public/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase and merge the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git checkout --quiet master
  $ git merge --ff some-branch
  Updating e4ac97e..7b560c8
  Fast-forward
   alpha | 1 +
   beta  | 1 +
   gamma | 1 +
   3 files changed, 3 insertions(+)
   create mode 100644 alpha
   create mode 100644 beta
   create mode 100644 gamma
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     e4ac97e..7b560c8  master -> master
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

We publish the source changeset

  $ hg -R hg-repo phase --public --rev 'all()'

Pulling the rebase will not consider the public changeset and not detect any replacement.

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-target-public/server.git
  importing 4 git commits
  automatically obsoleted 0 changesets
  updating bookmark master
  not updating diverged bookmark some-branch
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..


Check we do not look replacement to changeset that already exist in the repository
----------------------------------------------------------------------------------

We first rebase the changes, but keep them outside of the master branch. Since
we only select replacement under master they are not selected for replacement.

However, later we merge them into master. Since they are not new, they won't be selected.
(Maybe we should actually select them, but it is prefered to narrow the
processing as much as possible to avoid errors)

  $ count=50
  $ cp -r base-case test-target-existing
  $ cd test-target-existing

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-target-existing/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase (but do not merge) the branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pulling the rebase in mercurial will not consider replacement since they are
not under master.

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-target-existing/server.git
  importing 4 git commits
  automatically obsoleted 0 changesets
  updating bookmark master
  not updating diverged bookmark some-branch
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  

Now we actually merge things into master git side.

  $ cd git-repo
  $ git checkout --quiet master
  $ git merge --ff some-branch
  Updating e4ac97e..7b560c8
  Fast-forward
   alpha | 1 +
   beta  | 1 +
   gamma | 1 +
   3 files changed, 3 insertions(+)
   create mode 100644 alpha
   create mode 100644 beta
   create mode 100644 gamma
  $ git push --all
  To ../server.git
     e4ac97e..7b560c8  master -> master
  $ cd ..


And we pull the result in Mercurial, since the changeset are not new, they are not considered.
(this is an explicit choice to avoid seeking replacement in a too wide set)

  $ hg -R hg-repo pull
  pulling from $TESTTMP/test-target-existing/server.git
  no changes found
  updating bookmark master
  not updating diverged bookmark some-branch
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  tag:         default/master
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  

  $ cd ..


Check the behavior is configurable
==================================

Check we can control the specified branch with config
-----------------------------------------------------

We first rebase the changes, but keep them outside of the master branch.
However the branch is selected for tracking.

  $ count=50
  $ cp -r base-case test-config-target
  $ cd test-config-target

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-config-target/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase and merge the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pulling the rebase in mercurial should detect the rebase and obsolete the older version.

  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull --config paths.default:hg-git.find-successors-in=some-branch
  pulling from $TESTTMP/test-config-target/server.git
  importing 4 git commits
  HG-GIT:INFER_OBS: e91937fd8904 -> 05f94c07c58c
  HG-GIT:INFER_OBS: 67ec0a3230ae -> 47a01f7be6e7
  HG-GIT:INFER_OBS: 0c8e47eb927a -> 45f6ceb621f2
  automatically obsoleted 3 changesets
  updating bookmark master
  updating bookmark some-branch
  3 new obsolescence markers
  obsoleted 3 changesets
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads*) (glob)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  bookmark:    master
  |  tag:         default/master
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | x  changeset:   3:0c8e47eb927a
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 7:45f6ceb621f2
  | |  summary:     gamma
  | |
  | x  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 6:47a01f7be6e7
  | |  summary:     beta
  | |
  | x  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 5:05f94c07c58c
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Pull replacement from a path that has no config
-----------------------------------------------

Since the pull involves a path without the obsolescence inference configuration, nothing should happen.

  $ count=50
  $ cp -r base-case test-config-custom-no-config
  $ cd test-config-custom-no-config

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-config-custom-no-config/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase and merge the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git checkout --quiet master
  $ git merge --ff some-branch
  Updating e4ac97e..7b560c8
  Fast-forward
   alpha | 1 +
   beta  | 1 +
   gamma | 1 +
   3 files changed, 3 insertions(+)
   create mode 100644 alpha
   create mode 100644 beta
   create mode 100644 gamma
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     e4ac97e..7b560c8  master -> master
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pull should not do anything since the path as not config for obs inference.

  $ cat << EOF >> ./hg-repo/.hg/hgrc
  > [paths]
  > default = NOTHING/TO/SEE/HERE
  > my-path = ../server.git
  > EOF
  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull my-path
  pulling from $TESTTMP/test-config-custom-no-config/server.git
  importing 4 git commits
  updating bookmark master
  not updating diverged bookmark some-branch
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  tag:         my-path/master
  |  tag:         my-path/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  tag:         default/some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  tag:         my-path/master
  |  tag:         my-path/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | o  changeset:   3:0c8e47eb927a
  | |  bookmark:    some-branch
  | |  tag:         default/some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  summary:     gamma
  | |
  | o  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  summary:     beta
  | |
  | o  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Pull replacement from a custom path that as the config
------------------------------------------------------

The path is not 'default' but still has the associated configuration. The
feature should be used.

  $ count=50
  $ cp -r base-case test-config-custom-has-config
  $ cd test-config-custom-has-config

  $ cd hg-repo
  $ hg book some-branch
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m alpha
  $ echo beta > beta
  $ hg add beta
  $ fn_hg_commit -m beta
  $ echo gamma > gamma
  $ hg add gamma
  $ fn_hg_commit -m gamma
  $ hg push -B some-branch
  pushing to $TESTTMP/test-config-custom-has-config/server.git
  searching for changes
  adding objects
  added 3 commits with 3 trees and 3 blobs
  adding reference refs/heads/some-branch
  $ hg log -G
  @  changeset:   3:0c8e47eb927a
  |  bookmark:    some-branch
  |  tag:         default/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   2:67ec0a3230ae
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   1:e91937fd8904
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   0:b15403328556
     bookmark:    master
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..

Make the main branch move forward in git.

  $ cd git-repo
  $ echo main > main
  $ git add main
  $ fn_git_commit -m 'main-1'
  $ git push --all
  To ../server.git
     54dfb14..e4ac97e  master -> master

Pull, rebase and merge the new branch created in Mercurial.

  $ git fetch origin some-branch
  From ../server
   * branch            some-branch -> FETCH_HEAD
   * [new branch]      some-branch -> origin/some-branch
  $ git log --graph
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git checkout --quiet some-branch
  $ git log --graph
  * commit a48097a4ee0e25ae0bf590af7b00885e8839c9bd
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit e47c333c122acb342b916fbacac7f1234fdf8dbe
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit 99431e150e51ed0b82d2a9158dae68afae39b99b
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ fn_git_rebase master
  $ git checkout --quiet master
  $ git merge --ff some-branch
  Updating e4ac97e..7b560c8
  Fast-forward
   alpha | 1 +
   beta  | 1 +
   gamma | 1 +
   3 files changed, 3 insertions(+)
   create mode 100644 alpha
   create mode 100644 beta
   create mode 100644 gamma
  $ git log --graph
  * commit 7b560c8d4265f86f9b2990359e16690f43005bc1
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:52 2007 +0000
  | 
  |     gamma
  | 
  * commit 57d955e039ff9ccee0a86f91f32e11bf45025982
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:51 2007 +0000
  | 
  |     beta
  | 
  * commit c44c134ccdc8a6831dbfa7732c63eaf526ca37ae
  | Author: test <none@none>
  | Date:   Mon Jan 1 00:00:50 2007 +0000
  | 
  |     alpha
  | 
  * commit e4ac97e7fecb5b18c920789fae2e0a5ff1494236
  | Author: test <test@example.org>
  | Date:   Mon Jan 1 00:00:53 2007 +0000
  | 
  |     main-1
  | 
  * commit 54dfb147815dcd75f0af8ba4b31cae8f25688e81
    Author: test <test@example.org>
    Date:   Mon Jan 1 00:00:10 2007 +0000
    
        root commit
  $ git push --all --force
  To ../server.git
     e4ac97e..7b560c8  master -> master
   + a48097a...7b560c8 some-branch -> some-branch (forced update)
  $ cd ..

Pull should create marker this time since the config is set this time

  $ cat << EOF >> ./hg-repo/.hg/hgrc
  > [paths]
  > default = NOTHING/TO/SEE/HERE
  > my-path = ../server.git
  > my-path:hg-git.find-successors-in=master
  > EOF
  $ hg -R hg-repo up master
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (activating bookmark master)
  $ hg -R hg-repo pull my-path
  pulling from $TESTTMP/test-config-custom-has-config/server.git
  importing 4 git commits
  HG-GIT:INFER_OBS: e91937fd8904 -> 05f94c07c58c
  HG-GIT:INFER_OBS: 67ec0a3230ae -> 47a01f7be6e7
  HG-GIT:INFER_OBS: 0c8e47eb927a -> 45f6ceb621f2
  automatically obsoleted 3 changesets
  updating bookmark master
  updating bookmark some-branch
  3 new obsolescence markers
  obsoleted 3 changesets
  new changesets 542d88807180:45f6ceb621f2 (4 drafts)
  (run 'hg heads' to see heads*) (glob)
  $ hg -R hg-repo log -G
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  bookmark:    some-branch
  |  tag:         my-path/master
  |  tag:         my-path/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | x  changeset:   3:0c8e47eb927a
  | |  tag:         default/some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 7:45f6ceb621f2
  | |  summary:     gamma
  | |
  | x  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 6:47a01f7be6e7
  | |  summary:     beta
  | |
  | x  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 5:05f94c07c58c
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ hg -R hg-repo log -G --hidden
  o  changeset:   7:45f6ceb621f2
  |  bookmark:    master
  |  bookmark:    some-branch
  |  tag:         my-path/master
  |  tag:         my-path/some-branch
  |  tag:         tip
  |  user:        test
  |  date:        Mon Jan 01 00:00:52 2007 +0000
  |  summary:     gamma
  |
  o  changeset:   6:47a01f7be6e7
  |  user:        test
  |  date:        Mon Jan 01 00:00:51 2007 +0000
  |  summary:     beta
  |
  o  changeset:   5:05f94c07c58c
  |  user:        test
  |  date:        Mon Jan 01 00:00:50 2007 +0000
  |  summary:     alpha
  |
  o  changeset:   4:542d88807180
  |  parent:      0:b15403328556
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:53 2007 +0000
  |  summary:     main-1
  |
  | x  changeset:   3:0c8e47eb927a
  | |  tag:         default/some-branch
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:52 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 7:45f6ceb621f2
  | |  summary:     gamma
  | |
  | x  changeset:   2:67ec0a3230ae
  | |  user:        test
  | |  date:        Mon Jan 01 00:00:51 2007 +0000
  | |  obsolete:    rewritten using auto-creation-by-hg-git as 6:47a01f7be6e7
  | |  summary:     beta
  | |
  | x  changeset:   1:e91937fd8904
  |/   user:        test
  |    date:        Mon Jan 01 00:00:50 2007 +0000
  |    obsolete:    rewritten using auto-creation-by-hg-git as 5:05f94c07c58c
  |    summary:     alpha
  |
  @  changeset:   0:b15403328556
     tag:         default/master
     user:        test <test@example.org>
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     root commit
  
  $ cd ..
