Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ hg init hgrepo
  $ cd hgrepo

Create a commit that we can export later on

  $ touch thefile
  $ hg commit -A -m "initial commit"
  adding thefile

We should only read .gitignore files in a hg-git repo (i.e. one with .hg/git
directory) otherwise, a rogue .gitignore could slow down a hg-only repo

  $ touch foo
  $ touch foobar
  $ touch bar
  $ echo 'foo*' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? foo
  ? foobar

Notice that foo appears above. Now export the commit to git and verify
it's gone:

  $ hg gexport
  $ hg status
  ? .gitignore
  ? bar

  $ echo '*bar' > .gitignore
  $ hg status
  ? .gitignore
  ? foo

  $ mkdir dir
  $ touch dir/foo
  $ echo 'foo' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? foobar

  $ echo '/foo' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? dir/foo
  ? foobar

  $ rm .gitignore
  $ echo 'foo' > dir/.gitignore
  $ hg status
  ? bar
  ? dir/.gitignore
  ? foo
  ? foobar

  $ touch dir/bar
  $ echo 'bar' > .gitignore
  $ hg status
  ? .gitignore
  ? dir/.gitignore
  ? foo
  ? foobar

  $ echo '/bar' > .gitignore
  $ hg status
  ? .gitignore
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar

  $ echo 'foo*' > .gitignore
  $ echo '!*bar' >> .gitignore
  $ hg status
  .gitignore: unsupported ignore pattern '!*bar'
  ? .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar

  $ echo '.hg/' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar

  $ echo 'dir/.hg/' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar

  $ echo '.hg/foo' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar

  $ touch foo.hg
  $ echo 'foo.hg' > .gitignore
  $ hg status
  ? .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar
  $ rm foo.hg

  $ touch .hgignore
  $ hg status
  ? .gitignore
  ? .hgignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? dir/foo
  ? foo
  ? foobar

  $ echo 'syntax: re' > .hgignore
  $ echo 'foo.*$(?<!bar)' >> .hgignore
  $ echo 'dir/foo' >> .hgignore
  $ hg status
  ? .gitignore
  ? .hgignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foobar

  $ hg add .gitignore
  $ hg commit -m "add and commit .gitignore"
  $ rm .gitignore
  $ rm .hgignore
  $ hg status
  ! .gitignore
  ? bar
  ? dir/.gitignore
  ? dir/bar
  ? foo
  ? foobar
  $ cd ..

show pattern error in hgignore file as expected (issue197)
----------------------------------------------------------

  $ cd hgrepo
  $ cat > $TESTTMP/invalidhgignore <<EOF
  > # invalid syntax in regexp
  > foo(
  > EOF
  $ hg status --config ui.ignore=$TESTTMP/invalidhgignore
  abort: $TESTTMP/invalidhgignore: invalid pattern (relre): foo(
  [255]

  $ cat > .hgignore <<EOF
  > # invalid syntax in regexp
  > foo(
  > EOF
  $ hg status
  abort: $TESTTMP/hgrepo/.hgignore: invalid pattern (relre): foo(
  [255]
  $ cd ..

check behaviour with worktree
-----------------------------

  $ git init -q --bare repo.git
  $ cd hgrepo
  $ hg book -r tip master
  $ hg push ../repo.git
  pushing to ../repo.git
  searching for changes
  adding objects
  remote: found 0 deltas to reuse (dulwich0210 !)
  added 2 commits with 2 trees and 2 blobs
  adding reference refs/heads/master
  $ cd ..
  $ hg --config hggit.worktree=yes clone repo.git worktree
  importing 2 git commits
  new changesets 69cb9b83bde4:c6a4b5109a96 (2 drafts)
  updating to bookmark master (hg57 !)
  updating to branch default (no-hg57 !)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd worktree
  $ ls -A
  .git
  .gitignore
  .hg
  thefile
  $ hg st
  ? .git
  $ hg --config hggit.worktree=yes st
  $ git status
  On branch master
  nothing to commit, working tree clean
  $ cd ..
  $ rm -rf worktree
