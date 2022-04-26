from __future__ import absolute_import, print_function

import distutils.version
import os
import re
import socket
import stat
import subprocess
import sys
import tempfile

tempprefix = 'hg-hghave-'

checks = {
    "true": (lambda: True, "yak shaving"),
    "false": (lambda: False, "nail clipper"),
    "known-bad-output": (lambda: True, "use for currently known bad output"),
    "missing-correct-output": (lambda: False, "use for missing good output"),
}

try:
    import msvcrt

    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stderr.fileno(), os.O_BINARY)
except ImportError:
    pass

stdout = getattr(sys.stdout, 'buffer', sys.stdout)
stderr = getattr(sys.stderr, 'buffer', sys.stderr)

is_not_python2 = sys.version_info[0] >= 3
if is_not_python2:

    def _sys2bytes(p):
        if p is None:
            return p
        return p.encode('utf-8')

    def _bytes2sys(p):
        if p is None:
            return p
        return p.decode('utf-8')


else:

    def _sys2bytes(p):
        return p

    _bytes2sys = _sys2bytes


def check(name, desc):
    """Registers a check function for a feature."""

    def decorator(func):
        checks[name] = (func, desc)
        return func

    return decorator


def checkvers(name, desc, vers):
    """Registers a check function for each of a series of versions.

    vers can be a list or an iterator.

    Produces a series of feature checks that have the form <name><vers> without
    any punctuation (even if there's punctuation in 'vers'; i.e. this produces
    'py38', not 'py3.8' or 'py-38')."""

    def decorator(func):
        def funcv(v):
            def f():
                return func(v)

            return f

        for v in vers:
            v = str(v)
            f = funcv(v)
            checks['%s%s' % (name, v.replace('.', ''))] = (f, desc % v)
        return func

    return decorator


def checkfeatures(features):
    result = {
        'error': [],
        'missing': [],
        'skipped': [],
    }

    for feature in features:
        negate = feature.startswith('no-')
        if negate:
            feature = feature[3:]

        if feature not in checks:
            result['missing'].append(feature)
            continue

        check, desc = checks[feature]
        try:
            available = check()
        except Exception as e:
            result['error'].append('hghave check %s failed: %r' % (feature, e))
            continue

        if not negate and not available:
            result['skipped'].append('missing feature: %s' % desc)
        elif negate and available:
            result['skipped'].append('system supports %s' % desc)

    return result


def require(features):
    """Require that features are available, exiting if not."""
    result = checkfeatures(features)

    for missing in result['missing']:
        stderr.write(
            ('skipped: unknown feature: %s\n' % missing).encode('utf-8')
        )
    for msg in result['skipped']:
        stderr.write(('skipped: %s\n' % msg).encode('utf-8'))
    for msg in result['error']:
        stderr.write(('%s\n' % msg).encode('utf-8'))

    if result['missing']:
        sys.exit(2)

    if result['skipped'] or result['error']:
        sys.exit(1)


def matchoutput(cmd, regexp, ignorestatus=False):
    """Return the match object if cmd executes successfully and its output
    is matched by the supplied regular expression.
    """

    # Tests on Windows have to fake USERPROFILE to point to the test area so
    # that `~` is properly expanded on py3.8+.  However, some tools like black
    # make calls that need the real USERPROFILE in order to run `foo --version`.
    env = os.environ
    if os.name == 'nt':
        env = os.environ.copy()
        env['USERPROFILE'] = env['REALUSERPROFILE']

    r = re.compile(regexp)
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
    )
    s = p.communicate()[0]
    ret = p.returncode
    return (ignorestatus or not ret) and r.search(s)


@check("baz", "GNU Arch baz client")
def has_baz():
    return matchoutput('baz --version 2>&1', br'baz Bazaar version')


@check("bzr", "Breezy library and executable version >= 3.1")
def has_bzr():
    if not is_not_python2:
        return False
    try:
        # Test the Breezy python lib
        import breezy
        import breezy.bzr.bzrdir
        import breezy.errors
        import breezy.revision
        import breezy.revisionspec

        breezy.revisionspec.RevisionSpec
        if breezy.__doc__ is None or breezy.version_info[:2] < (3, 1):
            return False
    except (AttributeError, ImportError):
        return False
    # Test the executable
    return matchoutput('brz --version 2>&1', br'Breezy \(brz\) ')


@check("chg", "running with chg")
def has_chg():
    return 'CHG_INSTALLED_AS_HG' in os.environ


@check("rhg", "running with rhg as 'hg'")
def has_rhg():
    return 'RHG_INSTALLED_AS_HG' in os.environ


@check("pyoxidizer", "running with pyoxidizer build as 'hg'")
def has_rhg():
    return 'PYOXIDIZED_INSTALLED_AS_HG' in os.environ


@check("cvs", "cvs client/server")
def has_cvs():
    re = br'Concurrent Versions System.*?server'
    return matchoutput('cvs --version 2>&1', re) and not has_msys()


@check("cvs112", "cvs client/server 1.12.* (not cvsnt)")
def has_cvs112():
    re = br'Concurrent Versions System \(CVS\) 1.12.*?server'
    return matchoutput('cvs --version 2>&1', re) and not has_msys()


@check("cvsnt", "cvsnt client/server")
def has_cvsnt():
    re = br'Concurrent Versions System \(CVSNT\) (\d+).(\d+).*\(client/server\)'
    return matchoutput('cvsnt --version 2>&1', re)


@check("darcs", "darcs client")
def has_darcs():
    return matchoutput('darcs --version', br'\b2\.([2-9]|\d{2})', True)


@check("mtn", "monotone client (>= 1.0)")
def has_mtn():
    return matchoutput('mtn --version', br'monotone', True) and not matchoutput(
        'mtn --version', br'monotone 0\.', True
    )


@check("eol-in-paths", "end-of-lines in paths")
def has_eol_in_paths():
    try:
        fd, path = tempfile.mkstemp(dir='.', prefix=tempprefix, suffix='\n\r')
        os.close(fd)
        os.remove(path)
        return True
    except (IOError, OSError):
        return False


@check("execbit", "executable bit")
def has_executablebit():
    try:
        EXECFLAGS = stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
        fh, fn = tempfile.mkstemp(dir='.', prefix=tempprefix)
        try:
            os.close(fh)
            m = os.stat(fn).st_mode & 0o777
            new_file_has_exec = m & EXECFLAGS
            os.chmod(fn, m ^ EXECFLAGS)
            exec_flags_cannot_flip = (os.stat(fn).st_mode & 0o777) == m
        finally:
            os.unlink(fn)
    except (IOError, OSError):
        # we don't care, the user probably won't be able to commit anyway
        return False
    return not (new_file_has_exec or exec_flags_cannot_flip)


@check("suidbit", "setuid and setgid bit")
def has_suidbit():
    if getattr(os, "statvfs", None) is None or getattr(os, "ST_NOSUID") is None:
        return False
    return bool(os.statvfs('.').f_flag & os.ST_NOSUID)


@check("icasefs", "case insensitive file system")
def has_icasefs():
    # Stolen from mercurial.util
    fd, path = tempfile.mkstemp(dir='.', prefix=tempprefix)
    os.close(fd)
    try:
        s1 = os.stat(path)
        d, b = os.path.split(path)
        p2 = os.path.join(d, b.upper())
        if path == p2:
            p2 = os.path.join(d, b.lower())
        try:
            s2 = os.stat(p2)
            return s2 == s1
        except OSError:
            return False
    finally:
        os.remove(path)


@check("fifo", "named pipes")
def has_fifo():
    if getattr(os, "mkfifo", None) is None:
        return False
    name = tempfile.mktemp(dir='.', prefix=tempprefix)
    try:
        os.mkfifo(name)
        os.unlink(name)
        return True
    except OSError:
        return False


@check("killdaemons", 'killdaemons.py support')
def has_killdaemons():
    return True


@check("cacheable", "cacheable filesystem")
def has_cacheable_fs():
    from mercurial import util

    fd, path = tempfile.mkstemp(dir='.', prefix=tempprefix)
    os.close(fd)
    try:
        return util.cachestat(path).cacheable()
    finally:
        os.remove(path)


@check("lsprof", "python lsprof module")
def has_lsprof():
    try:
        import _lsprof

        _lsprof.Profiler  # silence unused import warning
        return True
    except ImportError:
        return False


def _gethgversion():
    m = matchoutput('hg --version --quiet 2>&1', br'(\d+)\.(\d+)')
    if not m:
        return (0, 0)
    return (int(m.group(1)), int(m.group(2)))


_hgversion = None


def gethgversion():
    global _hgversion
    if _hgversion is None:
        _hgversion = _gethgversion()
    return _hgversion


@checkvers(
    "hg", "Mercurial >= %s", list([(1.0 * x) / 10 for x in range(9, 99)])
)
def has_hg_range(v):
    major, minor = v.split('.')[0:2]
    return gethgversion() >= (int(major), int(minor))


@check("rust", "Using the Rust extensions")
def has_rust():
    """Check is the mercurial currently running is using some rust code"""
    cmd = 'hg debuginstall --quiet 2>&1'
    match = br'checking module policy \(([^)]+)\)'
    policy = matchoutput(cmd, match)
    if not policy:
        return False
    return b'rust' in policy.group(1)


@check("hg08", "Mercurial >= 0.8")
def has_hg08():
    if checks["hg09"][0]():
        return True
    return matchoutput('hg help annotate 2>&1', '--date')


@check("hg07", "Mercurial >= 0.7")
def has_hg07():
    if checks["hg08"][0]():
        return True
    return matchoutput('hg --version --quiet 2>&1', 'Mercurial Distributed SCM')


@check("hg06", "Mercurial >= 0.6")
def has_hg06():
    if checks["hg07"][0]():
        return True
    return matchoutput('hg --version --quiet 2>&1', 'Mercurial version')


@check("gettext", "GNU Gettext (msgfmt)")
def has_gettext():
    return matchoutput('msgfmt --version', br'GNU gettext-tools')


@check("git", "git command line client")
def has_git():
    return matchoutput('git --version 2>&1', br'^git version')


def getgitversion():
    m = matchoutput('git --version 2>&1', br'git version (\d+)\.(\d+)')
    if not m:
        return (0, 0)
    return (int(m.group(1)), int(m.group(2)))


@check("dulwich", "Dulwich Python library")
def has_dulwich():
    try:
        from dulwich import client

        client.ZERO_SHA  # silence unused import
        return True
    except ImportError:
        return False

@checkvers(
    "dulwich", "Dulwich >= %s", [
        '%d.%d.%d' % vers
        for vers in (
            (0, 19, 10),
            (0, 20, 0),
            (0, 20, 3),
            (0, 20, 4),
        )
    ]
)
def has_dulwich_range(v):
    import dulwich

    return dulwich.__version__ >= tuple(map(int, v.split('.')))


@check("pygit2", "pygit2 Python library")
def has_git():
    try:
        import pygit2

        pygit2.Oid  # silence unused import
        return True
    except ImportError:
        return False


# https://github.com/git-lfs/lfs-test-server
@check("lfs-test-server", "git-lfs test server")
def has_lfsserver():
    exe = 'lfs-test-server'
    if has_windows():
        exe = 'lfs-test-server.exe'
    return any(
        os.access(os.path.join(path, exe), os.X_OK)
        for path in os.environ["PATH"].split(os.pathsep)
    )


@checkvers("git", "git client (with ext::sh support) version >= %s", (1.9,))
def has_git_range(v):
    major, minor = v.split('.')[0:2]
    return getgitversion() >= (int(major), int(minor))


@check("docutils", "Docutils text processing library")
def has_docutils():
    try:
        import docutils.core

        docutils.core.publish_cmdline  # silence unused import
        return True
    except ImportError:
        return False


def getsvnversion():
    m = matchoutput('svn --version --quiet 2>&1', br'^(\d+)\.(\d+)')
    if not m:
        return (0, 0)
    return (int(m.group(1)), int(m.group(2)))


@checkvers("svn", "subversion client and admin tools >= %s", (1.3, 1.5))
def has_svn_range(v):
    major, minor = v.split('.')[0:2]
    return getsvnversion() >= (int(major), int(minor))


@check("svn", "subversion client and admin tools")
def has_svn():
    return matchoutput('svn --version 2>&1', br'^svn, version') and matchoutput(
        'svnadmin --version 2>&1', br'^svnadmin, version'
    )


@check("svn-bindings", "subversion python bindings")
def has_svn_bindings():
    try:
        import svn.core

        version = svn.core.SVN_VER_MAJOR, svn.core.SVN_VER_MINOR
        if version < (1, 4):
            return False
        return True
    except ImportError:
        return False


@check("p4", "Perforce server and client")
def has_p4():
    return matchoutput('p4 -V', br'Rev\. P4/') and matchoutput(
        'p4d -V', br'Rev\. P4D/'
    )


@check("symlink", "symbolic links")
def has_symlink():
    # mercurial.windows.checklink() is a hard 'no' at the moment
    if os.name == 'nt' or getattr(os, "symlink", None) is None:
        return False
    name = tempfile.mktemp(dir='.', prefix=tempprefix)
    try:
        os.symlink(".", name)
        os.unlink(name)
        return True
    except (OSError, AttributeError):
        return False


@check("hardlink", "hardlinks")
def has_hardlink():
    from mercurial import util

    fh, fn = tempfile.mkstemp(dir='.', prefix=tempprefix)
    os.close(fh)
    name = tempfile.mktemp(dir='.', prefix=tempprefix)
    try:
        util.oslink(_sys2bytes(fn), _sys2bytes(name))
        os.unlink(name)
        return True
    except OSError:
        return False
    finally:
        os.unlink(fn)


@check("hardlink-whitelisted", "hardlinks on whitelisted filesystems")
def has_hardlink_whitelisted():
    from mercurial import util

    try:
        fstype = util.getfstype(b'.')
    except OSError:
        return False
    return fstype in util._hardlinkfswhitelist


@check("rmcwd", "can remove current working directory")
def has_rmcwd():
    ocwd = os.getcwd()
    temp = tempfile.mkdtemp(dir='.', prefix=tempprefix)
    try:
        os.chdir(temp)
        # On Linux, 'rmdir .' isn't allowed, but the other names are okay.
        # On Solaris and Windows, the cwd can't be removed by any names.
        os.rmdir(os.getcwd())
        return True
    except OSError:
        return False
    finally:
        os.chdir(ocwd)
        # clean up temp dir on platforms where cwd can't be removed
        try:
            os.rmdir(temp)
        except OSError:
            pass


@check("tla", "GNU Arch tla client")
def has_tla():
    return matchoutput('tla --version 2>&1', br'The GNU Arch Revision')


@check("gpg", "gpg client")
def has_gpg():
    return matchoutput('gpg --version 2>&1', br'GnuPG')


@check("gpg2", "gpg client v2")
def has_gpg2():
    return matchoutput('gpg --version 2>&1', br'GnuPG[^0-9]+2\.')


@check("gpg21", "gpg client v2.1+")
def has_gpg21():
    return matchoutput('gpg --version 2>&1', br'GnuPG[^0-9]+2\.(?!0)')


@check("unix-permissions", "unix-style permissions")
def has_unix_permissions():
    d = tempfile.mkdtemp(dir='.', prefix=tempprefix)
    try:
        fname = os.path.join(d, 'foo')
        for umask in (0o77, 0o07, 0o22):
            os.umask(umask)
            f = open(fname, 'w')
            f.close()
            mode = os.stat(fname).st_mode
            os.unlink(fname)
            if mode & 0o777 != ~umask & 0o666:
                return False
        return True
    finally:
        os.rmdir(d)


@check("unix-socket", "AF_UNIX socket family")
def has_unix_socket():
    return getattr(socket, 'AF_UNIX', None) is not None


@check("root", "root permissions")
def has_root():
    return getattr(os, 'geteuid', None) and os.geteuid() == 0


@check("pyflakes", "Pyflakes python linter")
def has_pyflakes():
    try:
        import pyflakes

        pyflakes.__version__
    except ImportError:
        return False
    else:
        return True


@check("pylint", "Pylint python linter")
def has_pylint():
    try:
        import pylint

        pylint.version  # silence unused import warning
        return True
    except ImportError:
        return False


@check("clang-format", "clang-format C code formatter (>= 11)")
def has_clang_format():
    m = matchoutput('clang-format --version', br'clang-format version (\d+)')
    # style changed somewhere between 10.x and 11.x
    if m:
        return int(m.group(1)) >= 11
    # Assist Googler contributors, they have a centrally-maintained version of
    # clang-format that is generally very fresh, but unlike most builds (both
    # official and unofficial), it does *not* include a version number.
    return matchoutput(
        'clang-format --version', br'clang-format .*google3-trunk \([0-9a-f]+\)'
    )


@check("jshint", "JSHint static code analysis tool")
def has_jshint():
    return matchoutput("jshint --version 2>&1", br"jshint v")


@check("pygments", "Pygments source highlighting library")
def has_pygments():
    try:
        import pygments

        pygments.highlight  # silence unused import warning
        return True
    except ImportError:
        return False


@check("pygments25", "Pygments version >= 2.5")
def pygments25():
    try:
        import pygments

        v = pygments.__version__
    except ImportError:
        return False

    parts = v.split(".")
    major = int(parts[0])
    minor = int(parts[1])

    return (major, minor) >= (2, 5)


@check("outer-repo", "outer repo")
def has_outer_repo():
    # failing for other reasons than 'no repo' imply that there is a repo
    return not matchoutput('hg root 2>&1', br'abort: no repository found', True)


@check("ssl", "ssl module available")
def has_ssl():
    try:
        import ssl

        ssl.CERT_NONE
        return True
    except ImportError:
        return False


@check("defaultcacertsloaded", "detected presence of loaded system CA certs")
def has_defaultcacertsloaded():
    import ssl
    from mercurial import sslutil, ui as uimod

    ui = uimod.ui.load()
    cafile = sslutil._defaultcacerts(ui)
    ctx = ssl.create_default_context()
    if cafile:
        ctx.load_verify_locations(cafile=cafile)
    else:
        ctx.load_default_certs()

    return len(ctx.get_ca_certs()) > 0


@check("tls1.2", "TLS 1.2 protocol support")
def has_tls1_2():
    from mercurial import sslutil

    return b'tls1.2' in sslutil.supportedprotocols


@check("windows", "Windows")
def has_windows():
    return os.name == 'nt'


@check("system-sh", "system() uses sh")
def has_system_sh():
    return os.name != 'nt'


@check("serve", "platform and python can manage 'hg serve -d'")
def has_serve():
    return True


@check("setprocname", "whether osutil.setprocname is available or not")
def has_setprocname():
    try:
        from mercurial.utils import procutil

        procutil.setprocname
        return True
    except AttributeError:
        return False


@check("test-repo", "running tests from repository")
def has_test_repo():
    t = os.environ["TESTDIR"]
    return os.path.isdir(os.path.join(t, "..", ".hg"))


@check("network-io", "whether tests are allowed to access 3rd party services")
def has_test_repo():
    t = os.environ.get("HGTESTS_ALLOW_NETIO")
    return t == "1"


@check("curses", "terminfo compiler and curses module")
def has_curses():
    try:
        import curses

        curses.COLOR_BLUE

        # Windows doesn't have a `tic` executable, but the windows_curses
        # package is sufficient to run the tests without it.
        if os.name == 'nt':
            return True

        return has_tic()

    except (ImportError, AttributeError):
        return False


@check("tic", "terminfo compiler")
def has_tic():
    return matchoutput('test -x "`which tic`"', br'')


@check("xz", "xz compression utility")
def has_xz():
    # When Windows invokes a subprocess in shell mode, it uses `cmd.exe`, which
    # only knows `where`, not `which`.  So invoke MSYS shell explicitly.
    return matchoutput("sh -c 'test -x \"`which xz`\"'", b'')


@check("msys", "Windows with MSYS")
def has_msys():
    return os.getenv('MSYSTEM')


@check("aix", "AIX")
def has_aix():
    return sys.platform.startswith("aix")


@check("osx", "OS X")
def has_osx():
    return sys.platform == 'darwin'


@check("osxpackaging", "OS X packaging tools")
def has_osxpackaging():
    try:
        return (
            matchoutput('pkgbuild', br'Usage: pkgbuild ', ignorestatus=1)
            and matchoutput(
                'productbuild', br'Usage: productbuild ', ignorestatus=1
            )
            and matchoutput('lsbom', br'Usage: lsbom', ignorestatus=1)
            and matchoutput('xar --help', br'Usage: xar', ignorestatus=1)
        )
    except ImportError:
        return False


@check('linuxormacos', 'Linux or MacOS')
def has_linuxormacos():
    # This isn't a perfect test for MacOS. But it is sufficient for our needs.
    return sys.platform.startswith(('linux', 'darwin'))


@check("docker", "docker support")
def has_docker():
    pat = br'A self-sufficient runtime for'
    if matchoutput('docker --help', pat):
        if 'linux' not in sys.platform:
            # TODO: in theory we should be able to test docker-based
            # package creation on non-linux using boot2docker, but in
            # practice that requires extra coordination to make sure
            # $TESTTEMP is going to be visible at the same path to the
            # boot2docker VM. If we figure out how to verify that, we
            # can use the following instead of just saying False:
            # return 'DOCKER_HOST' in os.environ
            return False

        return True
    return False


@check("debhelper", "debian packaging tools")
def has_debhelper():
    # Some versions of dpkg say `dpkg', some say 'dpkg' (` vs ' on the first
    # quote), so just accept anything in that spot.
    dpkg = matchoutput(
        'dpkg --version', br"Debian .dpkg' package management program"
    )
    dh = matchoutput(
        'dh --help', br'dh is a part of debhelper.', ignorestatus=True
    )
    dh_py2 = matchoutput(
        'dh_python2 --help', br'other supported Python versions'
    )
    # debuild comes from the 'devscripts' package, though you might want
    # the 'build-debs' package instead, which has a dependency on devscripts.
    debuild = matchoutput(
        'debuild --help', br'to run debian/rules with given parameter'
    )
    return dpkg and dh and dh_py2 and debuild


@check(
    "debdeps", "debian build dependencies (run dpkg-checkbuilddeps in contrib/)"
)
def has_debdeps():
    # just check exit status (ignoring output)
    path = '%s/../contrib/packaging/debian/control' % os.environ['TESTDIR']
    return matchoutput('dpkg-checkbuilddeps %s' % path, br'')


@check("demandimport", "demandimport enabled")
def has_demandimport():
    # chg disables demandimport intentionally for performance wins.
    return (not has_chg()) and os.environ.get('HGDEMANDIMPORT') != 'disable'


# Add "py27", "py35", ... as possible feature checks. Note that there's no
# punctuation here.
@checkvers("py", "Python >= %s", (2.7, 3.5, 3.6, 3.7, 3.8, 3.9))
def has_python_range(v):
    major, minor = v.split('.')[0:2]
    py_major, py_minor = sys.version_info.major, sys.version_info.minor

    return (py_major, py_minor) >= (int(major), int(minor))


@check("py3", "running with Python 3.x")
def has_py3():
    return 3 == sys.version_info[0]


@check("py3exe", "a Python 3.x interpreter is available")
def has_python3exe():
    py = 'python3'
    if os.name == 'nt':
        py = 'py -3'
    return matchoutput('%s -V' % py, br'^Python 3.(5|6|7|8|9)')


@check("pure", "running with pure Python code")
def has_pure():
    return any(
        [
            os.environ.get("HGMODULEPOLICY") == "py",
            os.environ.get("HGTEST_RUN_TESTS_PURE") == "--pure",
        ]
    )


@check("slow", "allow slow tests (use --allow-slow-tests)")
def has_slow():
    return os.environ.get('HGTEST_SLOW') == 'slow'


@check("hypothesis", "Hypothesis automated test generation")
def has_hypothesis():
    try:
        import hypothesis

        hypothesis.given
        return True
    except ImportError:
        return False


@check("unziplinks", "unzip(1) understands and extracts symlinks")
def unzip_understands_symlinks():
    return matchoutput('unzip --help', br'Info-ZIP')


@check("zstd", "zstd Python module available")
def has_zstd():
    try:
        import mercurial.zstd

        mercurial.zstd.__version__
        return True
    except ImportError:
        return False


@check("devfull", "/dev/full special file")
def has_dev_full():
    return os.path.exists('/dev/full')


@check("ensurepip", "ensurepip module")
def has_ensurepip():
    try:
        import ensurepip

        ensurepip.bootstrap
        return True
    except ImportError:
        return False


@check("virtualenv", "virtualenv support")
def has_virtualenv():
    try:
        import virtualenv

        # --no-site-package became the default in 1.7 (Nov 2011), and the
        # argument was removed in 20.0 (Feb 2020).  Rather than make the
        # script complicated, just ignore ancient versions.
        return int(virtualenv.__version__.split('.')[0]) > 1
    except (AttributeError, ImportError, IndexError):
        return False


@check("fsmonitor", "running tests with fsmonitor")
def has_fsmonitor():
    return 'HGFSMONITOR_TESTS' in os.environ


@check("fuzzywuzzy", "Fuzzy string matching library")
def has_fuzzywuzzy():
    try:
        import fuzzywuzzy

        fuzzywuzzy.__version__
        return True
    except ImportError:
        return False


@check("clang-libfuzzer", "clang new enough to include libfuzzer")
def has_clang_libfuzzer():
    mat = matchoutput('clang --version', br'clang version (\d)')
    if mat:
        # libfuzzer is new in clang 6
        return int(mat.group(1)) > 5
    return False


@check("clang-6.0", "clang 6.0 with version suffix (libfuzzer included)")
def has_clang60():
    return matchoutput('clang-6.0 --version', br'clang version 6\.')


@check("xdiff", "xdiff algorithm")
def has_xdiff():
    try:
        from mercurial import policy

        bdiff = policy.importmod('bdiff')
        return bdiff.xdiffblocks(b'', b'') == [(0, 0, 0, 0)]
    except (ImportError, AttributeError):
        return False


@check('extraextensions', 'whether tests are running with extra extensions')
def has_extraextensions():
    return 'HGTESTEXTRAEXTENSIONS' in os.environ


def getrepofeatures():
    """Obtain set of repository features in use.

    HGREPOFEATURES can be used to define or remove features. It contains
    a space-delimited list of feature strings. Strings beginning with ``-``
    mean to remove.
    """
    # Default list provided by core.
    features = {
        'bundlerepo',
        'revlogstore',
        'fncache',
    }

    # Features that imply other features.
    implies = {
        'simplestore': ['-revlogstore', '-bundlerepo', '-fncache'],
    }

    for override in os.environ.get('HGREPOFEATURES', '').split(' '):
        if not override:
            continue

        if override.startswith('-'):
            if override[1:] in features:
                features.remove(override[1:])
        else:
            features.add(override)

            for imply in implies.get(override, []):
                if imply.startswith('-'):
                    if imply[1:] in features:
                        features.remove(imply[1:])
                else:
                    features.add(imply)

    return features


@check('reporevlogstore', 'repository using the default revlog store')
def has_reporevlogstore():
    return 'revlogstore' in getrepofeatures()


@check('reposimplestore', 'repository using simple storage extension')
def has_reposimplestore():
    return 'simplestore' in getrepofeatures()


@check('repobundlerepo', 'whether we can open bundle files as repos')
def has_repobundlerepo():
    return 'bundlerepo' in getrepofeatures()


@check('repofncache', 'repository has an fncache')
def has_repofncache():
    return 'fncache' in getrepofeatures()


@check('dirstate-v2', 'using the v2 format of .hg/dirstate')
def has_dirstate_v2():
    # Keep this logic in sync with `newreporequirements()` in `mercurial/localrepo.py`
    return has_rust() and matchoutput(
        'hg config format.exp-rc-dirstate-v2', b'(?i)1|yes|true|on|always'
    )


@check('sqlite', 'sqlite3 module and matching cli is available')
def has_sqlite():
    try:
        import sqlite3

        version = sqlite3.sqlite_version_info
    except ImportError:
        return False

    if version < (3, 8, 3):
        # WITH clause not supported
        return False

    return matchoutput('sqlite3 -version', br'^3\.\d+')


@check('vcr', 'vcr http mocking library (pytest-vcr)')
def has_vcr():
    try:
        import vcr

        vcr.VCR
        return True
    except (ImportError, AttributeError):
        pass
    return False


@check('emacs', 'GNU Emacs')
def has_emacs():
    # Our emacs lisp uses `with-eval-after-load` which is new in emacs
    # 24.4, so we allow emacs 24.4, 24.5, and 25+ (24.5 was the last
    # 24 release)
    return matchoutput('emacs --version', b'GNU Emacs 2(4.4|4.5|5|6|7|8|9)')


@check('black', 'the black formatter for python (>= 22.3)')
def has_black():
    try:
        import black
        version = black.__version__
    except ImportError:
        version = None
    sv = distutils.version.StrictVersion
    return version and sv(version) >= sv('22.3')


@check('pytype', 'the pytype type checker')
def has_pytype():
    pytypecmd = 'pytype --version'
    version = matchoutput(pytypecmd, b'[0-9a-b.]+')
    sv = distutils.version.StrictVersion
    return version and sv(_bytes2sys(version.group(0))) >= sv('2019.10.17')


@check("rustfmt", "rustfmt tool at version nightly-2020-10-04")
def has_rustfmt():
    # We use Nightly's rustfmt due to current unstable config options.
    return matchoutput(
        '`rustup which --toolchain nightly-2020-10-04 rustfmt` --version',
        b'rustfmt',
    )


@check("cargo", "cargo tool")
def has_cargo():
    return matchoutput('`rustup which cargo` --version', b'cargo')


@check("lzma", "python lzma module")
def has_lzma():
    try:
        import _lzma

        _lzma.FORMAT_XZ
        return True
    except ImportError:
        return False


@check("bash", "bash shell")
def has_bash():
    return matchoutput("bash -c 'echo hi'", b'^hi$')
