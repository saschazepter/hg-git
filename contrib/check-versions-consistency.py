#!/usr/bin/env python
#
# /// script
# dependencies = [
#   "packaging>=25.0",
#   "setuptools>=78.1.1",
#   "PyYAML>=6.0.2",
# ]
# ///
#
#
# This script checks consistency between tested and documented versions,
# analyzing the following files:
#
# - <BASE>/.gitlab-ci.yml
# - <BASE>/README.rst
# - <BASE>/hggit/__init__.py
# - <BASE>/setup.cfg
#
# It should be run in a CI stage before running heavier tests.
#
# In detail, the script:
# - extracts the set of (python, hg, dulwich) versions used in `.gitlab-ci.yml`
#   to perform actual tests and sorts them. These versions will be considered
#   the authoritative ones;
# - reads the `minimumhgversion` and `testedwith` attributes in `__init__.py`,
#   and ensures that they report the same information extracted from
#   `.gitlab-ci.yml`;
# - extracts the (python, dulwich) versions constraints from `setup.cfg` and
#   checks that they are compatible with the range of versions used in the CI;
# - checks that `README.rst` reports as minimum required versions the same
#   versions that are concretely used in the CI.
#
# Linted with ruff 0.15.19:
#     ruff check --select=ALL --ignore=D,E501 check-versions-consistency.py

import logging
import pathlib
import re
import sys
import types
from collections.abc import Generator
from contextlib import contextmanager
from textwrap import dedent
from typing import Literal
from unittest.mock import MagicMock, Mock

import yaml
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.version import Version
from setuptools.config import setupcfg

logger = logging.getLogger(__name__)
SCRIPT_DIR = pathlib.Path(__file__).resolve().parent


ComponentHgPythonDulwich = Literal["hg", "python", "dulwich"]
ComponentPythonDulwich = Literal["python", "dulwich"]


class HgGitModuleAttributes:
    def __init__(self) -> None:
        with self.mocked_hggit() as hggit:
            self.tested_with = sorted(
                [Version(s) for s in hggit.testedwith.decode().split()],
            )
            self.minimum_hg_version = Version(hggit.minimumhgversion.decode())

    def __str__(self) -> str:
        return f"testedwith={[str(v) for v in self.tested_with]}, minimumhgversion={self.minimum_hg_version}"

    @property
    def min_testedwith(self) -> Version:
        return self.tested_with[0]

    @staticmethod
    @contextmanager
    def mocked_hggit() -> Generator[types.ModuleType]:
        repo_base_path = str((SCRIPT_DIR / "..").resolve())
        mock_config = {
            "dulwich": Mock(),
            "dulwich.client": Mock(),
            "dulwich.config": Mock(),
            "dulwich.errors": Mock(),
            "dulwich.object_store": Mock(),
            "dulwich.objects": Mock(),
            "dulwich.pack": Mock(),
            "dulwich.refs": Mock(),
            "dulwich.repo": Mock(),
            "mercurial": Mock(demandimport=MagicMock()),
            "mercurial.i18n": Mock(),
            "mercurial.interfaces": Mock(),
            "mercurial.node": Mock(),
            "mercurial.utils": Mock(),
        }
        sys.path = [repo_base_path, *sys.path]
        sys.modules |= mock_config
        import hggit  # noqa: PLC0415

        try:
            yield hggit
        finally:
            sys.path.remove(repo_base_path)
            for k in mock_config:
                del sys.modules[k]


class ReadmeError(Exception):
    pass


class ReadmeVersions:
    """Class that extracts minimum required versions from README.rst"""

    def __init__(self, readme_path: pathlib.Path) -> None:
        self.path = readme_path.resolve(strict=True)
        readme_contents = self.path.read_text()
        expr = dedent(
            r"""
            Dependencies
            ============
            .*
            \* Mercurial (?P<hg>\d+(?:\.\d+)*)
            \* Dulwich (?P<dulwich>\d+(?:\.\d+)*)
            \* Python (?P<python>\d+(?:\.\d+)*)
        """,
        )
        m = re.search(expr, readme_contents, re.DOTALL)
        if m is None:
            msg = f"could not identify minimal required hg, dulwich and python versions from {self.path}"
            raise ReadmeError(msg)
        self.hg = Version(m.groupdict()["hg"])
        self.dulwich = Version(m.groupdict()["dulwich"])
        self.python = Version(m.groupdict()["python"])

    def __str__(self) -> str:
        return f"hg={self.hg}, dulwich={self.dulwich}, python={self.python}"

    def __getitem__(self, item: ComponentHgPythonDulwich) -> list[Version]:
        return getattr(self, item)


class GitlabCiError(Exception):
    pass


class GitlabCiVersions:
    def __init__(self, gitlab_ci_path: pathlib.Path) -> None:
        self.path = gitlab_ci_path.resolve(strict=True)
        with self.path.open() as f:
            contents = yaml.safe_load(f)
        try:
            latest_hgs = contents["Latest"]["parallel"]["matrix"][0]["HG"]
            supported_hgs = contents["Supported"]["parallel"]["matrix"][0]["HG"]
            self.hg = sorted(Version(s) for s in (latest_hgs + supported_hgs))
            self.dulwich = sorted(
                Version(s)
                for s in contents["Alpine"]["parallel"]["matrix"][0]["DULWICH"]
            )
            self.python = sorted(
                Version(s)
                for s in contents["Latest"]["parallel"]["matrix"][0]["PYTHON"]
            )
        except Exception as e:
            msg = f"unable to extract component versions from {self.path} ({e})"
            raise GitlabCiError(msg) from e
        if len(self.hg) == 0:
            msg = f"could not find any hg version in {self.path.name}"
            raise GitlabCiError(msg)
        if len(self.dulwich) == 0:
            msg = f"could not find any dulwich version in {self.path.name}"
            raise GitlabCiError(msg)
        if len(self.python) == 0:
            msg = f"could not find any python version in {self.path.name}"
            raise GitlabCiError(msg)

    def __str__(self) -> str:
        return f"hg={[str(v) for v in self.hg]}, dulwich={[str(v) for v in self.dulwich]}, python={[str(v) for v in self.python]}"

    def __getitem__(self, item: ComponentHgPythonDulwich) -> list[Version]:
        return getattr(self, item)

    def min_version(self, component_name: ComponentHgPythonDulwich) -> Version:
        return self[component_name][0]


class SetupCfgError(Exception):
    pass


class SetupCfgSpecifiers:
    def __init__(self, setup_cfg_path: pathlib.Path) -> None:
        self.path = setup_cfg_path.resolve(strict=True)
        cfg = setupcfg.read_configuration(self.path)["options"]
        self.python = SpecifierSet(cfg["python_requires"])
        install_requires: dict[str, SpecifierSet] = {
            r.name: r.specifier
            for r in (
                Requirement(requirement_str)
                for requirement_str in cfg["install_requires"]
            )
        }
        if "dulwich" not in install_requires:
            msg = (
                f"Unable to extract a SpecifierSet for dulwich from {self.path}"
            )
            raise SetupCfgError(msg)
        self.dulwich = install_requires["dulwich"]

    def __str__(self) -> str:
        return f"python: '{self.python}', dulwich: '{self.dulwich}'"

    def __getitem__(self, item: ComponentPythonDulwich) -> SpecifierSet:
        return getattr(self, item)


def check_ci_versions_contained_in_setup_cfg_versions(
    component_name: ComponentPythonDulwich,
    gitlab_ci: GitlabCiVersions,
    setup_cfg_specifiers: SetupCfgSpecifiers,
) -> int:
    """Check that each version of the given component (currently, python or
    dulwich) tested in ci (.gitlab_ci.yml) satisfies the corresponding version
    specifier in setup.cfg.
    """
    error_count = 0
    setup_specifier = setup_cfg_specifiers[component_name]
    for version in gitlab_ci[component_name]:
        if not setup_specifier.contains(version):
            logger.error(
                "%s tests component '%s' with version '%s', but this is not allowed by %s, that specifies: '%s'",
                gitlab_ci.path.name,
                component_name,
                version,
                setup_cfg_specifiers.path.name,
                setup_specifier,
            )
            error_count += 1
    return error_count


def check_min_ci_versions_match_min_readme_versions(
    component_name: ComponentHgPythonDulwich,
    gitlab_ci: GitlabCiVersions,
    readme_versions: ReadmeVersions,
) -> Literal[0, 1]:
    ci_min_component_version = gitlab_ci.min_version(component_name)
    readme_min_component_version = readme_versions[component_name]
    if ci_min_component_version != readme_min_component_version:
        logger.error(
            "in %s, the minimum version used for component '%s' is '%s', but %s reports a minimum version of '%s'",
            gitlab_ci.path.name,
            component_name,
            ci_min_component_version,
            readme_versions.path.name,
            readme_min_component_version,
        )
        return 1
    return 0


def main(argv: list[str]) -> int:  # noqa: ARG001
    error_count = 0
    ci_versions = GitlabCiVersions(SCRIPT_DIR / ".." / ".gitlab-ci.yml")
    logger.info(
        "versions tested in %s are: %s",
        ci_versions.path.name,
        ci_versions,
    )

    hggit_attributes = HgGitModuleAttributes()
    logger.info("hggit module attributes are: %s", hggit_attributes)

    readme_versions = ReadmeVersions(SCRIPT_DIR / ".." / "README.rst")
    logger.info(
        "versions mentioned in %s are: %s",
        readme_versions.path.name,
        readme_versions,
    )

    setup_cfg_specs = SetupCfgSpecifiers(SCRIPT_DIR / ".." / "setup.cfg")
    logger.info(
        "%s specifies the following dependencies contraints: %s",
        setup_cfg_specs.path.name,
        setup_cfg_specs,
    )

    if ci_versions.hg != hggit_attributes.tested_with:
        logger.error(
            "%s concretely tests these hg versions: %s, but in __init__.py the 'testedwith' attribute is different: %s",
            ci_versions.path.name,
            [str(v) for v in ci_versions.hg],
            [str(v) for v in hggit_attributes.tested_with],
        )
        error_count += 1

    if hggit_attributes.min_testedwith != hggit_attributes.minimum_hg_version:
        logger.error(
            "in __init__.py, the lowest hg version declared in minimumhgversion is '%s', but the lowest version in testedwith is '%s'",
            hggit_attributes.minimum_hg_version,
            hggit_attributes.min_testedwith,
        )
        error_count += 1

    error_count += check_min_ci_versions_match_min_readme_versions(
        "hg",
        ci_versions,
        readme_versions,
    )
    error_count += check_min_ci_versions_match_min_readme_versions(
        "python",
        ci_versions,
        readme_versions,
    )
    error_count += check_min_ci_versions_match_min_readme_versions(
        "dulwich",
        ci_versions,
        readme_versions,
    )

    error_count += check_ci_versions_contained_in_setup_cfg_versions(
        "python",
        ci_versions,
        setup_cfg_specs,
    )
    error_count += check_ci_versions_contained_in_setup_cfg_versions(
        "dulwich",
        ci_versions,
        setup_cfg_specs,
    )

    if error_count == 0:
        logger.info(
            "SUCCESS: versions specified in %s, %s, %s and __init__.py are consistent",
            ci_versions.path.name,
            setup_cfg_specs.path.name,
            readme_versions.path.name,
        )
        return 0
    logger.error("There were %d errors", error_count)
    return error_count


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s: %(message)s",
    )
    sys.exit(main(sys.argv))
