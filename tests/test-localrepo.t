Load commonly used test logic
  $ . "$TESTDIR/testutil"

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m 'add alpha'
  $ git tag alpha
  $ cd ..

The directory should have no impact on the successful cloning of a repository.
However, we have to verify it.
  $ hg clone -U gitrepo hgrepo
  importing 1 git commits
  new changesets ff7a2f2d8d70 (1 drafts)

If the directory name does not end with ".git", all should work as expected
  $ cd hgrepo
  $ hg log -T "{node|short}\n"
  ff7a2f2d8d70
  $ cd ..

It should also work if the directory name ends with ".git", but it does not.
  $ mv hgrepo hgrepo.git
  $ cd hgrepo.git
  $ hg log -T "{node|short}\n"
  abort: repository '$TESTTMP/hgrepo.git' is not local
  [10]
