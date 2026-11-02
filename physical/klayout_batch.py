"""Headless Python-script adapter for the actual KLayout layout API.

Supports the -r/-rd interface used by ORFS def2stream.py. Ruby decks and GUI
commands require the desktop KLayout executable and are deliberately rejected.
"""
import runpy
import sys
import klayout.db as layout_api

args = iter(sys.argv[1:])
script = None
variables = {}
for arg in args:
    if arg in ('-v', '--version'):
        print('KLayout ' + layout_api.__version__)
        raise SystemExit(0)
    if arg in ('-zz', '-z', '-b'):
        continue
    if arg == '-rd':
        name, value = next(args).split('=', 1)
        variables[name] = value
    elif arg == '-r':
        script = next(args)
    else:
        raise SystemExit(f'Unsupported headless KLayout argument: {arg}')
if script is None or not script.endswith('.py'):
    raise SystemExit('This adapter executes Python layout scripts only, not Ruby DRC/LVS decks')
sys.modules['pya'] = layout_api
sys.argv = [script]
runpy.run_path(script, init_globals=variables, run_name='__main__')
