Test the functionality that allows to specify revsets to be exported to Git refs according to a template.

  $ . "$TESTDIR/testutil"
  $ create_commit() {
  >   echo $1 > $1
  >   hg add $1
  >   fn_hg_commit -m "add $1"
  > }

  $ hg init
  $ cat << EOF >> .hg/hgrc
  > [git]
  > intree = yes
  > export-additional-refs.named-branch-heads:revset = head()
  > export-additional-refs.named-branch-heads:template = refs/heads/branch/{branch}
  > EOF

  $ create_commit alpha
  $ hg branch foo
  marked working directory as branch foo
  (branches are permanent and global, did you want a bookmark?)
  $ create_commit beta
  $ hg branch bar
  marked working directory as branch bar
  $ create_commit gamma

  $ hg gexport
  $ hg log --template "{gitnode|short} \"{desc}\" branch: {branch}\n" $@
  75759345733e "add gamma" branch: bar
  a4fef2b4377b "add beta" branch: foo
  672a49b78d04 "add alpha" branch: default
  $ find .git/refs/heads | sort
  .git/refs/heads
  .git/refs/heads/branch
  .git/refs/heads/branch/bar
  .git/refs/heads/branch/default
  .git/refs/heads/branch/foo
  $ cat .git/refs/heads/branch/default
  672a49b78d041d14fb9f6f9a28d750e2959120f7
  $ cat .git/refs/heads/branch/foo
  a4fef2b4377b99b81a4d897798f6160fa53f98cb
  $ cat .git/refs/heads/branch/bar
  75759345733e9f67146057e528fb54af992454c2

  $ hg update 1
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg branch bar -f
  marked working directory as branch bar
  $ create_commit delta
  $ hg log -r 'head() and branch(bar)' --template "{node|short}\n" $@
  6af8ead84341
  b4da028a8ec6
  $ hg gexport
  abort: ref(s) used for multiple changesets:
    refs/heads/branch/bar -> 6af8ead84341ad202b2d5237b8509ee40c152235, b4da028a8ec6b963e20c5071237c797710230bb5
  [255]
