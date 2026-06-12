import json
from pathlib import Path


# Paths are relative to the project root
system_config_path = Path("source/config/system_config.json")
sensor_config_path = Path("source/config/sensors")
sv_config_path = Path("source/hdl/config_pkg.sv")
sv_struct_path = Path("source/hdl/struct")


def sv_parameter_type(value):
    """Return the SystemVerilog type and literal for a Python value."""
    if isinstance(value, bool):
        return "bit", "1'b1" if value else "1'b0"
    if isinstance(value, int):
        return "int", str(value)
    if isinstance(value, str):
        return "string", f'"{value}"'

    raise TypeError(f"Unsupported parameter type: {type(value).__name__}")


def get_required_sensor_field(sensor, field, sensor_file):
    """Get a required field from a sensor JSON object with a useful error."""
    if field not in sensor:
        raise KeyError(f"Missing required field '{field}' in {sensor_file}")
    return sensor[field]


def sensor_protocol_id(protocol, sensor_file):
    """Map a protocol string from JSON to the generated SystemVerilog ID."""
    match protocol.upper():
        case "I2C":
            return "PROTOCOL_I2C"
        case "SPI":
            return "PROTOCOL_SPI"
        case _:
            raise ValueError(f"Unsupported Protocol '{protocol}' in {sensor_file}")


# Collect struct files deterministically
struct_paths = sorted(sv_struct_path.glob("*.sv"))

# Open and parse the system JSON file
with open(system_config_path, "r", encoding="utf-8") as config_file:
    data = json.load(config_file)

# Open and parse all sensor JSON files deterministically
sensor_files = sorted(sensor_config_path.glob("*.json"))
sensors = []

for sensor_file in sensor_files:
    with open(sensor_file, "r", encoding="utf-8") as f:
        sensor_data = json.load(f)

    sensors.append({
        "name": sensor_file.stem,
        "file": sensor_file,
        "data": sensor_data,
    })

# Optional sanity check: make sure NUM_SENSORS matches the number of sensor JSON files
if "NUM_SENSORS" in data and data["NUM_SENSORS"] != len(sensors):
    raise ValueError(
        f"NUM_SENSORS is {data['NUM_SENSORS']}, but found {len(sensors)} sensor JSON files "
        f"in {sensor_config_path}"
    )

# If NUM_SENSORS was not in the system config, define it from the sensor files
if "NUM_SENSORS" not in data:
    data["NUM_SENSORS"] = len(sensors)

# Create SV config package
with open(sv_config_path, "w", encoding="utf-8") as sv_file:
    sv_file.write("package config_pkg;\n\n")

    # Write system JSON constants
    for key, val in data.items():
        sv_type, param_val = sv_parameter_type(val)
        sv_file.write(f"\tparameter {sv_type} {key} = {param_val};\n")

    sv_file.write("\tparameter int PROTOCOL_WIDTH = 2;\n")
    sv_file.write("\tparameter logic [PROTOCOL_WIDTH-1:0] PROTOCOL_I2C = 2'd0;\n")
    sv_file.write("\tparameter logic [PROTOCOL_WIDTH-1:0] PROTOCOL_SPI = 2'd1;\n")

    sv_file.write("\n")

    # Write individual flattened sensor parameters too, e.g. sen0_Sensor_Address
    for sensor in sensors:
        sensor_name = sensor["name"]
        sensor_data = sensor["data"]

        sv_file.write(f"\t// Parameters from {sensor['file'].name}\n")
        for key, val in sensor_data.items():
            sv_type, param_val = sv_parameter_type(val)
            sv_file.write(f"\tparameter {sv_type} {sensor_name}_{key} = {param_val};\n")
        sv_file.write("\n")

    # Write packed sensor config vectors for generate-loop indexing
    protocols = []
    sensor_addrs = []
    reg_addrs = []
    num_bytes = []

    for sensor in sensors:
        sensor_data = sensor["data"]
        sensor_file = sensor["file"]

        protocols.append(sensor_protocol_id(get_required_sensor_field(sensor_data, "Protocol", sensor_file), sensor_file))
        sensor_addrs.append(get_required_sensor_field(sensor_data, "Sensor_Address", sensor_file))
        reg_addrs.append(get_required_sensor_field(sensor_data, "Register_Address", sensor_file))
        num_bytes.append(get_required_sensor_field(sensor_data, "Num_Bytes", sensor_file))

    # Sensor 0 occupies the least-significant slice, so concatenate in reverse order.
    protocol_literals = ", ".join(reversed(protocols))
    sensor_addr_literals = ", ".join(f"7'd{addr}" for addr in reversed(sensor_addrs))
    reg_addr_literals = ", ".join(f"8'd{addr}" for addr in reversed(reg_addrs))
    num_byte_literals = ", ".join(f"8'd{n}" for n in reversed(num_bytes))

    sv_file.write("\t// Packed sensor config vectors for generate-loop indexing.\n")
    sv_file.write("\t// Sensor 0 occupies the least-significant slice.\n")
    sv_file.write(f"\tparameter logic [PROTOCOL_WIDTH*NUM_SENSORS-1:0] SENSOR_PROTOCOLS = {{{protocol_literals}}};\n")
    sv_file.write(f"\tparameter logic [7*NUM_SENSORS-1:0] SENSOR_ADDRS = {{{sensor_addr_literals}}};\n")
    sv_file.write(f"\tparameter logic [8*NUM_SENSORS-1:0] SENSOR_REG_ADDRS = {{{reg_addr_literals}}};\n")
    sv_file.write(f"\tparameter logic [8*NUM_SENSORS-1:0] SENSOR_NUM_BYTES = {{{num_byte_literals}}};\n")

    sv_file.write("\n")

    # Write structs into package
    for struct_path in struct_paths:
        with open(struct_path, "r", encoding="utf-8") as struct_file:
            for line in struct_file:
                sv_file.write(f"\t{line}")
            sv_file.write("\n")
        sv_file.write("\n")

    sv_file.write("endpackage\n")
