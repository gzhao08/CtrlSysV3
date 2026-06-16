# CtrlSysV3 Vivado IP Configuration

This repo is meant to provide HDL that can be packaged as a Vivado IP and connected in a Block Design. The custom logic top is `ctrlsys_core`; the other required IP should be configured in Vivado and connected around it.

## System-Level Connections

Recommended block diagram shape:

```text
CPU/PS/MicroBlaze AXI master
        |
        v
AXI SmartConnect, control plane
        |
        +--> ctrlsys_core.s00_axi_*    custom axil_regs
        +--> axi_dma_0.S_AXI_LITE              DMA control registers
        +--> axi_iic_0.S_AXI                   CPU-controlled I2C

ctrlsys_core.m_axis_*
        |
        v
axi_dma_0.S_AXIS_S2MM

axi_dma_0.M_AXI_S2MM
        |
        v
DDR / memory interconnect

axi_iic_0 IIC signal pins
        |
        v
ctrlsys_core.axi_iic_* pins
        |
        v
ctrlsys_core internal sensors_mux
        |
        v
top-level sensor sda/scl pins
```

Do not connect `ctrlsys_core.s00_axi_*` directly to AXI IIC or AXI DMA. These are all AXI-Lite slaves. They each need a separate decoded connection from AXI SmartConnect.

## Suggested Address Map

Use any non-overlapping base addresses that fit your board/platform. This map is a sane starting point for a 32-bit Zynq-style memory map:

| Peripheral | Suggested Base | Range | Notes |
|---|---:|---:|---|
| `ctrlsys_core` / `axil_regs` | `0x43C0_0000` | `0x0001_0000` | Custom control/status. Internal implemented register window is only `0x40` bytes. |
| `axi_iic_0` | `0x43C1_0000` | `0x0001_0000` | CPU-driven I2C access. |
| `axi_dma_0` AXI-Lite | `0x4040_0000` | `0x0001_0000` | DMA config/status registers. |
| DDR DMA buffer | software-selected DDR address | software-selected size | Programmed into DMA S2MM destination address register by software. |

The exact base addresses are assigned in Vivado Address Editor and later appear in `xparameters.h` or the device tree.

## `ctrlsys_core`

HDL file: `source/hdl/ctrlsys_core.sv`

### IP Parameters

These are true top-level IP parameters on `ctrlsys_core` and are passed down into `sensors_reader`, `sensors_mux`, `data_buff`, and `frame_to_axis`.

`NUM_SENSORS` is intended to be `1` through `6`. Vivado should expose the fixed sensor slots `SENS0_*` through `SENS5_*`; the GUI Tcl can hide slots greater than or equal to `NUM_SENSORS`. Internally, `ctrlsys_core` repacks the enabled slots into the packed vectors expected by `sensors_reader`, so you no longer need to manually resize packed vector parameters when changing `NUM_SENSORS`.

| Parameter | Default | Description |
|---|---:|---|
| `NUM_SENSORS` | `3` | Number of physical sensor buses and packets per streamed frame. |
| `BUFFER_SIZE` | `5` | Number of complete multi-sensor frames stored in the internal FIFO. |
| `SENS0_PROTOCOL` | `0` | Sensor 0 protocol. `0` currently means I2C. |
| `SENS0_ADDR` | `0` | Sensor 0 7-bit I2C address. |
| `SENS0_REG_ADDR` | `5` | Sensor 0 register address to read from. |
| `SENS0_NUM_BYTES` | `18` | Sensor 0 read length in bytes. |
| `SENS1_PROTOCOL` | `0` | Sensor 1 protocol. |
| `SENS1_ADDR` | `127` | Sensor 1 7-bit I2C address. |
| `SENS1_REG_ADDR` | `41` | Sensor 1 register address to read from. |
| `SENS1_NUM_BYTES` | `18` | Sensor 1 read length in bytes. |
| `SENS2_PROTOCOL` | `0` | Sensor 2 protocol. |
| `SENS2_ADDR` | `127` | Sensor 2 7-bit I2C address. |
| `SENS2_REG_ADDR` | `41` | Sensor 2 register address to read from. |
| `SENS2_NUM_BYTES` | `18` | Sensor 2 read length in bytes. |
| `SENS3_PROTOCOL` | `0` | Sensor 3 protocol. Ignored unless `NUM_SENSORS >= 4`. |
| `SENS3_ADDR` | `0` | Sensor 3 7-bit I2C address. Ignored unless `NUM_SENSORS >= 4`. |
| `SENS3_REG_ADDR` | `0` | Sensor 3 register address. Ignored unless `NUM_SENSORS >= 4`. |
| `SENS3_NUM_BYTES` | `0` | Sensor 3 read length. Ignored unless `NUM_SENSORS >= 4`. |
| `SENS4_PROTOCOL` | `0` | Sensor 4 protocol. Ignored unless `NUM_SENSORS >= 5`. |
| `SENS4_ADDR` | `0` | Sensor 4 7-bit I2C address. Ignored unless `NUM_SENSORS >= 5`. |
| `SENS4_REG_ADDR` | `0` | Sensor 4 register address. Ignored unless `NUM_SENSORS >= 5`. |
| `SENS4_NUM_BYTES` | `0` | Sensor 4 read length. Ignored unless `NUM_SENSORS >= 5`. |
| `SENS5_PROTOCOL` | `0` | Sensor 5 protocol. Ignored unless `NUM_SENSORS = 6`. |
| `SENS5_ADDR` | `0` | Sensor 5 7-bit I2C address. Ignored unless `NUM_SENSORS = 6`. |
| `SENS5_REG_ADDR` | `0` | Sensor 5 register address. Ignored unless `NUM_SENSORS = 6`. |
| `SENS5_NUM_BYTES` | `0` | Sensor 5 read length. Ignored unless `NUM_SENSORS = 6`. |

`PROTOCOL_WIDTH` is now an internal localparam fixed at `2` bits per sensor protocol field.

### Clocks and Reset

| Port | Direction | Connect To |
|---|---|---|
| `clk` | input | Main PL clock, same clock as AXI DMA stream and AXI-Lite if possible. |
| `rst` | input | Active-high reset for custom logic. |
| `s00_axi_aclk` | input | Same clock as `clk`. |
| `s00_axi_aresetn` | input | Active-low AXI reset, usually `~rst` after reset synchronization. |

### AXI-Lite Slave: Custom Registers

This is the CPU control/status interface for `axil_regs`.

| Setting | Value |
|---|---|
| AXI protocol | AXI4-Lite slave |
| Data width | 32 bits |
| Address width | 6 bits |
| Byte address range implemented | `0x00` to `0x3F` |
| Recommended Vivado address range | `64K`, even though only `0x40` bytes are decoded |

### AXI-Stream Output to DMA

Connect these ports to `axi_dma_0.S_AXIS_S2MM`.

| `ctrlsys_core` Port | AXI DMA Port |
|---|---|
| `m_axis_tvalid` | `s_axis_s2mm_tvalid` |
| `m_axis_tready` | `s_axis_s2mm_tready` |
| `m_axis_tdata[31:0]` | `s_axis_s2mm_tdata[31:0]` |
| `m_axis_tkeep[3:0]` | `s_axis_s2mm_tkeep[3:0]` |
| `m_axis_tlast` | `s_axis_s2mm_tlast` |

Stream format is currently 32-bit words. Each sensor packet is 10 words, so with `NUM_SENSORS = 3`, one complete frame is:

```text
3 sensors * 10 words/sensor * 4 bytes/word = 120 bytes
```

### AXI IIC Signal-Level Ports

These are not AXI ports. They are the AXI IIC controller's I2C tri-state signal pins.

| `ctrlsys_core` Port | Connect To AXI IIC |
|---|---|
| `axi_iic_sda_i` | `sda_i` |
| `axi_iic_sda_o` | `sda_o` |
| `axi_iic_sda_t` | `sda_t` |
| `axi_iic_scl_i` | `scl_i` |
| `axi_iic_scl_o` | `scl_o` |
| `axi_iic_scl_t` | `scl_t` |

The physical package pins remain `ctrlsys_core.sda` and `ctrlsys_core.scl`. Do not also let AXI IIC instantiate its own external IOBUFs to the same board pins.

`axil_regs.control.useAXI` selects whether the internal custom I2C readers or AXI IIC controls the muxed sensor bus.

## Custom `axil_regs`

HDL files:

```text
source/hdl/axil_regs.v
source/hdl/axil_regs_slave_lite_v1_0_S00_AXI.v
```

### Parameters

| Parameter | Value |
|---|---:|
| `C_S00_AXI_DATA_WIDTH` | `32` |
| `C_S00_AXI_ADDR_WIDTH` | `6` |

### Register Map

Offsets are relative to the `ctrlsys_core` assigned base address.

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | control | R/W | Bit 0 `enable`, bit 1 `soft_reset`, bit 2 `useAXI`. |
| `0x04` | sample_period | R/W | Sample period in `clk` cycles. Reset/default is `5000`. |
| `0x08` | sensor_enable_mask | R/W | Enabled sensor bitmask. If zero, HDL treats all sensors as enabled. |
| `0x0C` | command | W | One-cycle pulses: bit 0 `clear_error`, bit 1 `reset_sample_counter`, bit 2 `cpu_clear_irq`. Reads as zero. |
| `0x10` | status | R | Bit 0 `busy`, bit 1 `error`, bit 2 `read_in_progress`, bit 3 `packet_done`, bits 7:4 `state`. |
| `0x14` | sample_count | R | Number of completed frames since reset or command reset. |
| `0x18` | reserved | R | Reads zero. |
| `0x1C` | error_code | R | Sensor error mask/status. |
| `0x20` | data_word0 | R | Latest sensor-0 data preview word 0. |
| `0x24` | data_word1 | R | Latest sensor-0 data preview word 1. |
| `0x28` | data_word2 | R | Latest sensor-0 data preview word 2. |
| `0x2C` | data_word3 | R | Latest sensor-0 data preview word 3. |
| `0x30` | data_word4 | R | Latest sensor-0 data preview word 4. |
| `0x34` | data_word5 | R | Latest sensor-0 data preview word 5. |
| `0x38` | data_word6 | R | Latest sensor-0 data preview word 6. |
| `0x3C` | data_word7 | R | Latest sensor-0 data preview word 7. |

## AXI DMA

Vivado IP: AXI Direct Memory Access

Recommended configuration:

| Setting | Value |
|---|---|
| Scatter Gather Engine | Disabled |
| MM2S channel | Disabled |
| S2MM channel | Enabled |
| S_AXIS_S2MM stream data width | 32 bits |
| M_AXI_S2MM memory map data width | 32 bits, or allow SmartConnect width conversion |
| Address width | 32 bits |
| S_AXI_LITE data width | 32 bits |
| S_AXI_LITE address width | usually 10 bits in generated wrapper |
| Include S2MM DRE | Optional; disabled is fine if destination addresses are 4-byte aligned |
| Interrupt | Connect `s2mm_introut` to interrupt controller/PS if software wants DMA completion IRQs |

DMA software must program:

```text
S2MM destination address = DDR buffer base
S2MM transfer length     = frame byte count, e.g. 120 bytes for 3 sensors
```

## AXI IIC

Vivado IP: AXI IIC

Recommended configuration:

| Setting | Value |
|---|---|
| AXI protocol | AXI4-Lite slave |
| S_AXI data width | 32 bits |
| S_AXI address width/range | Use Vivado default; assign 64K range in Address Editor |
| I2C mode | Standard/Fast mode as required by sensors |
| Physical pins | Do not connect directly to package pins; connect `sda_i/o/t` and `scl_i/o/t` to `ctrlsys_core.axi_iic_*` |
| Interrupt | Optional, connect to PS/interrupt controller if using interrupt-driven IIC software |

Only one AXI IIC instance is needed with the current HDL. When `useAXI = 1`, `sensor_enable_mask` selects which physical sensor bus AXI IIC controls. If more than one bit is set, the HDL currently selects the lowest enabled sensor index.

## AXI SmartConnect

Use one control-plane AXI SmartConnect for AXI-Lite register access:

| Setting | Value |
|---|---|
| Slave interfaces | 1 from CPU/PS/MicroBlaze AXI master |
| Master interfaces | 3: `axil_regs`, AXI IIC, AXI DMA AXI-Lite |
| Data width | 32 bits |
| Address width | 32 bits |
| Clock | Same PL clock as the peripherals where possible |

Use a separate memory/data interconnect path for DMA writes:

| Connection | Notes |
|---|---|
| `axi_dma_0.M_AXI_S2MM` to DDR controller / PS HP port | This is a full AXI memory-mapped master path, not AXI-Lite. |
| Width conversion | OK if the memory port is wider than 32 bits. |
| Clock conversion | Avoid if possible; otherwise let SmartConnect/clock converters handle it. |

## External Sensor Pins

The board-level sensor pins should connect only to:

```text
ctrlsys_core.sda[NUM_SENSORS-1:0]
ctrlsys_core.scl[NUM_SENSORS-1:0]
```

The custom core owns the final IOBUFs and internally chooses between:

```text
custom sensors_reader
AXI IIC signal-level controller
```

using `axil_regs.control.useAXI`.
