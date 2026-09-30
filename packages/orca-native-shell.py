"""Patch only local shell selection in the pinned Orca Linux bundle.

Remote hook paths must stay portable: never globally replace /bin/bash.
Exact match counts deliberately fail a version update when upstream changes.
"""

import pathlib
import sys

bundle = pathlib.Path(sys.argv[1])
bash = sys.argv[2]
source = bundle.read_text()
local_hook = 'process.platform===`win32`?process.env.ComSpec||`cmd.exe`:`/bin/bash`'
profiles = '[`/bin/zsh`,`/bin/bash`,`/bin/sh`]'
assert source.count(local_hook) == 1, "Review upstream local hook shell selection"
assert source.count(profiles) == 2, "Review upstream local terminal profiles"
source = source.replace(local_hook, local_hook.replace('/bin/bash', bash))
source = source.replace(profiles, profiles.replace('/bin/bash', bash))
bundle.write_text(source)
