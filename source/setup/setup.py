import runpy
from pathlib import Path


runpy.run_path(str(Path(__file__).with_name("setup_updated.py")))
