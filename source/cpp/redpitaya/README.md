# Red Pitaya Userspace Tests

Build on the Red Pitaya:

```sh
make
```

Run as root because the program maps FPGA registers through `/dev/mem`:

```sh
sudo ./ctrlsys_smoke_test
```

Initialize two BNO055 sensors, start FPGA reads at 1 Hz, and print DMA/core status:

```sh
sudo ./bno055_init_start
```

Default address map:

```text
ctrlsys_core AXI-Lite: 0x40000000
AXI DMA AXI-Lite:      0x40400000
AXI IIC AXI-Lite:      0x41600000
```

The smoke test verifies the custom AXI-Lite registers and prints AXI DMA S2MM status. It does not allocate a DMA buffer; use it first to confirm the FPGA design is reachable and producing frames/status.

`bno055_init_start` assumes:

```text
NUM_SENSORS = 2
SENS0_ADDR = 0x28
SENS1_ADDR = 0x28
sample_period = 50,000,000 cycles
```

It configures each BNO055 through AXI IIC by selecting one sensor bus at a time with `sensor_enable_mask` while `useAXI` is set. Then it returns control to the FPGA reader by clearing `useAXI`, enables the core, and prints the custom core status plus AXI DMA S2MM status once per second.
