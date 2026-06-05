import json
import os

# Get the absolute path of the directory containing this file
script_dir = os.path.dirname(os.path.abspath(__file__))

# Change the working directory
os.chdir(script_dir)


system_config_path = r"../config/system_config.json"
sv_config_path = r"../hdl/config_pkg.sv"
sv_struct_path = r"../hdl/struct/"
packet_path = sv_struct_path + r"sensor_packet.sv"
frame_path = sv_struct_path + r"data_frame.sv"
struct_paths = [packet_path,frame_path]

# Open and parse the JSON file
with open(system_config_path, "r", encoding="utf-8") as config_file:
    data = json.load(config_file)

# print(data)



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