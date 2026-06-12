import runpy
from pathlib import Path


def setup():
    runpy.run_path(str(Path("source/setup/setup_updated.py")))
