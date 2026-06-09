import json
import os
from pathlib import Path


# Get the absolute path of the directory containing this file
cwd = os.getcwd()

system_config_path = r"source\config\system_config.json"
sensor_config_path = r"source\config\sensors"
sv_config_path = r"source\hdl\config_pkg.sv"
sv_struct_path = r"source\hdl\struct"

os.chdir(sv_struct_path)

struct_paths = [f"source/hdl/struct/{f.name}" for f in Path('.').iterdir() if f.is_file()]

os.chdir(cwd)

# Open and parse the JSON file
with open(system_config_path, "r", encoding="utf-8") as config_file:
    data = json.load(config_file)

sensor_dir = Path(sensor_config_path)

for sensor_file in sensor_dir.glob("*.json"):
    with open(sensor_file, "r", encoding="utf-8") as f:
        sensor_data = json.load(f)

    sensor_name = sensor_file.stem

    for key, val in sensor_data.items():
        data[f"{sensor_name}_{key}"] = val



# create sv config package
with open(sv_config_path, "w") as sv_file:
    sv_file.write("package config_pkg;\n\n")

    # write json constants
    for key, val in data.items():
        param_val = val
        match type(val).__name__:
            case "int":
                sv_type = "int"
            case "str":
                sv_type = "string"
                param_val = f'"{val}"'
            case _:
                print("type not implemented")

        sv_file.write(f'\tparameter {sv_type} {key} = {param_val};\n')

    sv_file.write("\n")

    # write structs

    for struct_path in struct_paths:
        with open(struct_path, "r") as struct_file:
            for line in struct_file:
                sv_file.write(f'\t{line}')
            sv_file.write("\n")
        sv_file.write("\n")

    sv_file.write("\nendpackage")