Test that there is an error if the same ref is used for multiple changesets.

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
  > branch_bookmark_suffix = _bookmark
  > EOF

  $ create_commit alpha
  $ hg bookmark foo --inactive
  $ create_commit beta
  $ hg bookmark foo_bookmark --inactive

  $ hg log --template "{node|short} {bookmarks}\n" $@
  a7b2ac5cbfff foo_bookmark
  0221c246a567 foo
  $ hg gexport
  abort: ref(s) used for multiple changesets:
    refs/heads/foo -> 0221c246a56712c6aa64e5ee382244d8a471b1e2, a7b2ac5cbfff7c3ce3beda1a2db4ffeb047581d2
  [255]
