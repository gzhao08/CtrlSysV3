import subprocess
from pathlib import Path
import os

def compile():
    work_dir = "source/hdl"

    os.chdir(work_dir)

    # Get file names in the current directory
    file_names = [f.name for f in Path('.').iterdir() if f.is_file()]
    # print(file_names)

    prefix = "config"

    reordered = sorted(file_names, key=lambda word: not word.startswith(prefix))

    command = ["iverilog", "-g2012", "-tnull"] + reordered

    print(" ".join(command))

    subprocess.run(command)
