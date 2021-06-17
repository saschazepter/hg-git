from mercurial import exthelper

from . import compat

eh = exthelper.exthelper()


ALL_BRANCHES = object()


@eh.extsetup
def extsetup(ui):
    @compat.pathsuboption(
        b'hg-git.find-successors-in',
        'hggit_find_sucessors_in',
    )
    def process_successors_option(ui, path, value):
        """process the config "suboption" into a attribute on the path instance

        The value will be either:
        - None: no value specified, feature disabled,
        - [<head-names>]: a list of git branch to consider for the feature.
        """
        if not value:
            return None
        elif value == b'*':
            return ALL_BRANCHES
        else:
            return compat.parselist(value)
