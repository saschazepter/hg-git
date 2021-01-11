hg-git 0.10.0 (2020-02-01)
==========================

The 0.10.x series will be the last one supporting Python 2.7 and
Python 3.5. Future feature releases will only support Python 3.6 and
later and Mercurial 5.2 or later.

Enhancements:

* Add support for proper HTTP authentication, using either
  ``~/.git-credentials`` or just as with any other Mercurial remote
  repository. Previously, the only place to specify credentials was in
  the URL.
* Add ``--git`` option to ``hg tag`` for creating lightweight Git tags.
* Always show Git tags and remotes in ``hg log``, even if marked as
  obsolete.
* Support ``{gitnode}`` keyword in templates for incoming changes.
* Support HTTP authentication using either the Mercurial
  configuration, ``git-credentials`` or a user prompt.
* Support accessing Git repositories using ``file://`` URIs.
* Optimise writing the map between Mercurial and Git commits.
* Add ``debuggitdir`` command that prints the path to the cached Git
  repository.

Bug fixes:

* Fix pulling changes that build on obsoleted changesets.
* Fix using ``git-cleanup`` from a shared repository.
* Fix scp-style “URIs” on Windows.
* Fix ``hg status`` crashing when using ``.gitignore`` and a directory
  is not readable.
* Fix support for ``.gitignore`` from shared repositories and when
  using a Mercurial built with Rust extensions.
* Add ``brotli`` to list of modules ignored by Mercurial's
  ``demandimport``, so ``urllib3`` can detect its absence on Python 2.7.
* Fix the ``git`` protocol on Python 3.
* Address a deprecation in Dulwich 0.20.6 when pushing to Git.
* Fix configuration path sub-options such as ``remote:pushurl``.
* Fix pushing to Git when invalid references exist by disregarding
  them.
* Always save the commit map after an import.
* Add support for using Python 3 on Windows.
* Mark ``gimport``, ``gexport`` and ``gclear`` as advanced as they are
  either complicated to understand or dangerous.
* Handle backslashes in ``.gitignore`` correctly on Windows.
* Fix path auditing on Windows, so that e.g. ``.hg`` and ``.git``
  trigger the appropriate behaviour.

Other changes:

* More robust tests and CI infrastructure.
* Drop support for Mercurial 4.3.
* Updated documentation.
