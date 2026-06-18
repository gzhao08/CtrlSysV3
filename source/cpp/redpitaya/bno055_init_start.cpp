#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <thread>
#include <unistd.h>

namespace {

constexpr std::uint64_t kCtrlBaseDefault = 0x40000000ULL;
constexpr std::uint64_t kDmaBaseDefault = 0x40400000ULL;
constexpr std::uint64_t kIicBaseDefault = 0x41600000ULL;
constexpr std::size_t kCtrlRange = 0x1000;
constexpr std::size_t kDmaRange = 0x10000;
constexpr std::size_t kIicRange = 0x10000;

constexpr std::uint32_t kNumSensors = 2;
constexpr std::uint32_t kSensorMask = (1u << kNumSensors) - 1u;
constexpr std::uint32_t kBno055AddrDefault = 0x28;
constexpr std::uint32_t kSamplePeriodCycles = 50000000; // 1 second at 50 MHz.

namespace CtrlReg {
constexpr std::uint32_t Control = 0x00;
constexpr std::uint32_t SamplePeriod = 0x04;
constexpr std::uint32_t SensorEnableMask = 0x08;
constexpr std::uint32_t Command = 0x0c;
constexpr std::uint32_t Status = 0x10;
constexpr std::uint32_t SampleCount = 0x14;
constexpr std::uint32_t ErrorCode = 0x1c;
}

namespace CtrlBit {
constexpr std::uint32_t Enable = 1u << 0;
constexpr std::uint32_t SoftReset = 1u << 1;
constexpr std::uint32_t UseAxiIic = 1u << 2;
}

namespace CmdBit {
constexpr std::uint32_t ClearError = 1u << 0;
constexpr std::uint32_t ResetSampleCounter = 1u << 1;
constexpr std::uint32_t CpuClearIrq = 1u << 2;
}

namespace DmaReg {
constexpr std::uint32_t S2mmDmacr = 0x30;
constexpr std::uint32_t S2mmDmasr = 0x34;
}

namespace IicReg {
constexpr std::uint32_t IrqStatus = 0x20;
constexpr std::uint32_t Reset = 0x40;
constexpr std::uint32_t Control = 0x100;
constexpr std::uint32_t Status = 0x104;
constexpr std::uint32_t TxFifo = 0x108;
constexpr std::uint32_t TxFifoOccupancy = 0x114;
constexpr std::uint32_t RxFifoOccupancy = 0x118;
}

namespace IicCtrl {
constexpr std::uint32_t Enable = 1u << 0;
constexpr std::uint32_t TxFifoReset = 1u << 1;
}

namespace IicStatus {
constexpr std::uint32_t AddressedAsSlave = 1u << 0;
constexpr std::uint32_t BusBusy = 1u << 2;
constexpr std::uint32_t TxFifoFull = 1u << 4;
constexpr std::uint32_t RxFifoFull = 1u << 5;
constexpr std::uint32_t RxFifoEmpty = 1u << 6;
constexpr std::uint32_t TxFifoEmpty = 1u << 7;
}

namespace IicIrq {
constexpr std::uint32_t ArbitrationLost = 1u << 0;
constexpr std::uint32_t TxError = 1u << 1;
constexpr std::uint32_t TxFifoEmpty = 1u << 2;
constexpr std::uint32_t RxFifoFull = 1u << 3;
constexpr std::uint32_t BusNotBusy = 1u << 4;
constexpr std::uint32_t AddressedAsSlave = 1u << 5;
constexpr std::uint32_t NotAddressedAsSlave = 1u << 6;
constexpr std::uint32_t TxFifoHalfEmpty = 1u << 7;
}

namespace IicDyn {
constexpr std::uint32_t Start = 0x100;
constexpr std::uint32_t Stop = 0x200;
}

namespace Bno055 {
constexpr std::uint8_t PageId = 0x07;
constexpr std::uint8_t OprMode = 0x3d;
constexpr std::uint8_t PwrMode = 0x3e;
constexpr std::uint8_t SysTrigger = 0x3f;
constexpr std::uint8_t UnitSel = 0x3b;
constexpr std::uint8_t ConfigMode = 0x00;
constexpr std::uint8_t NdofMode = 0x0c;
constexpr std::uint8_t NormalPower = 0x00;
}

class MappedRegion {
public:
    MappedRegion(int fd, std::uint64_t base, std::size_t size)
        : size_(size) {
        const long page_size = sysconf(_SC_PAGESIZE);
        if (page_size <= 0) {
            throw std::runtime_error("sysconf(_SC_PAGESIZE) failed");
        }

        const std::uint64_t page_mask = static_cast<std::uint64_t>(page_size - 1);
        const std::uint64_t aligned_base = base & ~page_mask;
        offset_ = static_cast<std::size_t>(base - aligned_base);
        map_size_ = size_ + offset_;

        void* mapped = mmap(nullptr, map_size_, PROT_READ | PROT_WRITE, MAP_SHARED, fd, aligned_base);
        if (mapped == MAP_FAILED) {
            throw std::runtime_error("mmap failed: " + std::string(std::strerror(errno)));
        }

        base_ = static_cast<std::uint8_t*>(mapped);
    }

    ~MappedRegion() {
        if (base_ != nullptr) {
            munmap(base_, map_size_);
        }
    }

    MappedRegion(const MappedRegion&) = delete;
    MappedRegion& operator=(const MappedRegion&) = delete;

    std::uint32_t read32(std::uint32_t offset) const {
        volatile auto* ptr = reinterpret_cast<volatile std::uint32_t*>(base_ + offset_ + offset);
        return *ptr;
    }

    void write32(std::uint32_t offset, std::uint32_t value) const {
        volatile auto* ptr = reinterpret_cast<volatile std::uint32_t*>(base_ + offset_ + offset);
        *ptr = value;
    }

private:
    std::uint8_t* base_ = nullptr;
    std::size_t size_ = 0;
    std::size_t offset_ = 0;
    std::size_t map_size_ = 0;
};

std::uint64_t parse_u64(const char* text) {
    char* end = nullptr;
    errno = 0;
    const auto value = std::strtoull(text, &end, 0);
    if (errno != 0 || end == text || *end != '\0') {
        throw std::invalid_argument(std::string("invalid integer: ") + text);
    }
    return value;
}

std::string hex32(std::uint32_t value) {
    std::ostringstream oss;
    oss << "0x" << std::hex << std::setw(8) << std::setfill('0') << value;
    return oss.str();
}

std::string hex8(std::uint8_t value) {
    std::ostringstream oss;
    oss << "0x" << std::hex << std::setw(2) << std::setfill('0')
        << static_cast<unsigned>(value);
    return oss.str();
}

std::string iic_status_summary(std::uint32_t status) {
    std::ostringstream oss;
    oss << "status=" << hex32(status)
        << " bus_busy=" << ((status & IicStatus::BusBusy) != 0)
        << " tx_empty=" << ((status & IicStatus::TxFifoEmpty) != 0)
        << " tx_full=" << ((status & IicStatus::TxFifoFull) != 0)
        << " rx_empty=" << ((status & IicStatus::RxFifoEmpty) != 0)
        << " rx_full=" << ((status & IicStatus::RxFifoFull) != 0)
        << " addressed_as_slave=" << ((status & IicStatus::AddressedAsSlave) != 0);
    return oss.str();
}

std::string iic_irq_summary(std::uint32_t irq_status) {
    std::ostringstream oss;
    oss << "irq_status=" << hex32(irq_status)
        << " arb_lost=" << ((irq_status & IicIrq::ArbitrationLost) != 0)
        << " tx_error=" << ((irq_status & IicIrq::TxError) != 0)
        << " tx_empty_irq=" << ((irq_status & IicIrq::TxFifoEmpty) != 0)
        << " rx_full_irq=" << ((irq_status & IicIrq::RxFifoFull) != 0)
        << " bus_not_busy_irq=" << ((irq_status & IicIrq::BusNotBusy) != 0)
        << " aas_irq=" << ((irq_status & IicIrq::AddressedAsSlave) != 0)
        << " naas_irq=" << ((irq_status & IicIrq::NotAddressedAsSlave) != 0)
        << " tx_half_irq=" << ((irq_status & IicIrq::TxFifoHalfEmpty) != 0);
    return oss.str();
}

void print_iic_status(const MappedRegion& iic, const std::string& label) {
    const auto control = iic.read32(IicReg::Control);
    const auto status = iic.read32(IicReg::Status);
    const auto irq_status = iic.read32(IicReg::IrqStatus);
    const auto tx_occupancy = iic.read32(IicReg::TxFifoOccupancy);
    const auto rx_occupancy = iic.read32(IicReg::RxFifoOccupancy);

    std::cout << label
              << " control=" << hex32(control)
              << " " << iic_status_summary(status)
              << " " << iic_irq_summary(irq_status)
              << " tx_occ=" << tx_occupancy
              << " rx_occ=" << rx_occupancy
              << '\n';

    if (control == 0xffffffffu || status == 0xffffffffu) {
        std::cout << "  hint: AXI IIC registers read as all ones; check --iic-base against Vivado Address Editor.\n";
    } else if ((status & IicStatus::BusBusy) != 0 && (status & IicStatus::TxFifoEmpty) == 0) {
        std::cout << "  hint: AXI IIC still has queued TX data while the bus is busy; check SCL/SDA pull-ups, selected sensor wiring, and mux pins.\n";
    } else if ((status & IicStatus::BusBusy) != 0) {
        std::cout << "  hint: I2C bus is busy/stuck; one selected SCL/SDA line may be held low.\n";
    }
}

void sleep_ms(unsigned ms) {
    std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

void iic_reset(const MappedRegion& iic) {
    iic.write32(IicReg::Reset, 0x0a);
    sleep_ms(2);
    iic.write32(IicReg::Control, IicCtrl::Enable | IicCtrl::TxFifoReset);
    iic.write32(IicReg::Control, IicCtrl::Enable);
    sleep_ms(2);
}

void wait_tx_space(const MappedRegion& iic, std::uint32_t timeout_ms) {
    const std::uint32_t tries_limit = timeout_ms * 10u + 1u;
    for (std::uint32_t tries = 0; tries < tries_limit; ++tries) {
        if ((iic.read32(IicReg::Status) & IicStatus::TxFifoFull) == 0) {
            return;
        }
        usleep(100);
    }
    throw std::runtime_error("AXI IIC TX FIFO stayed full; " + iic_status_summary(iic.read32(IicReg::Status)));
}

void wait_iic_idle(const MappedRegion& iic, std::uint32_t timeout_ms) {
    const std::uint32_t tries_limit = timeout_ms * 10u + 1u;
    for (std::uint32_t tries = 0; tries < tries_limit; ++tries) {
        const auto status = iic.read32(IicReg::Status);
        if ((status & IicStatus::BusBusy) == 0 && (status & IicStatus::TxFifoEmpty) != 0) {
            return;
        }
        usleep(100);
    }
    print_iic_status(iic, "timeout AXI IIC");
    const auto status = iic.read32(IicReg::Status);
    const auto tx_occupancy = iic.read32(IicReg::TxFifoOccupancy);
    if ((status & IicStatus::BusBusy) == 0 && (status & IicStatus::TxFifoEmpty) == 0) {
        iic_reset(iic);
        throw std::runtime_error(
            "AXI IIC transaction stopped with " + std::to_string(tx_occupancy) +
            " unsent TX FIFO byte(s); likely no ACK from the selected sensor/address, or AXI IIC dynamic mode is not supported by this IP configuration");
    }
    throw std::runtime_error("AXI IIC did not become idle; " + iic_status_summary(status));
}

void iic_push(const MappedRegion& iic, std::uint32_t value, std::uint32_t timeout_ms) {
    wait_tx_space(iic, timeout_ms);
    iic.write32(IicReg::TxFifo, value);
}

void iic_write_reg(const MappedRegion& iic, std::uint8_t addr, std::uint8_t reg, std::uint8_t value, std::uint32_t timeout_ms) {
    iic_push(iic, IicDyn::Start | ((addr & 0x7f) << 1), timeout_ms);
    iic_push(iic, reg, timeout_ms);
    iic_push(iic, IicDyn::Stop | value, timeout_ms);
    try {
        wait_iic_idle(iic, timeout_ms);
    } catch (const std::exception& e) {
        throw std::runtime_error(
            "BNO055 write addr=" + hex8(addr) +
            " reg=" + hex8(reg) +
            " value=" + hex8(value) +
            " failed: " + e.what());
    }
}

void select_sensor_for_axi_iic(const MappedRegion& ctrl, std::uint32_t sensor_index) {
    ctrl.write32(CtrlReg::SensorEnableMask, 1u << sensor_index);
    ctrl.write32(CtrlReg::Control, CtrlBit::UseAxiIic);
    sleep_ms(2);
}

void init_bno055_on_selected_bus(const MappedRegion& iic, std::uint8_t bno_addr, std::uint32_t timeout_ms) {
    iic_reset(iic);
    print_iic_status(iic, "after AXI IIC reset");
    iic_write_reg(iic, bno_addr, Bno055::PageId, 0x00, timeout_ms);
    iic_write_reg(iic, bno_addr, Bno055::OprMode, Bno055::ConfigMode, timeout_ms);
    sleep_ms(25);
    iic_write_reg(iic, bno_addr, Bno055::PwrMode, Bno055::NormalPower, timeout_ms);
    iic_write_reg(iic, bno_addr, Bno055::SysTrigger, 0x00, timeout_ms);
    iic_write_reg(iic, bno_addr, Bno055::UnitSel, 0x00, timeout_ms);
    iic_write_reg(iic, bno_addr, Bno055::OprMode, Bno055::NdofMode, timeout_ms);
    sleep_ms(25);
    print_iic_status(iic, "after BNO055 config");
}

void print_ctrl_status(const MappedRegion& ctrl) {
    std::cout << "ctrl status=" << hex32(ctrl.read32(CtrlReg::Status))
              << " sample_count=" << ctrl.read32(CtrlReg::SampleCount)
              << " error_code=" << hex32(ctrl.read32(CtrlReg::ErrorCode))
              << '\n';
}

void print_dma_status(const MappedRegion& dma) {
    const auto dmacr = dma.read32(DmaReg::S2mmDmacr);
    const auto dmasr = dma.read32(DmaReg::S2mmDmasr);
    std::cout << "dma s2mm_dmacr=" << hex32(dmacr)
              << " s2mm_dmasr=" << hex32(dmasr)
              << " halted=" << ((dmasr & (1u << 0)) != 0)
              << " idle=" << ((dmasr & (1u << 1)) != 0)
              << " dma_int_err=" << ((dmasr & (1u << 4)) != 0)
              << " dma_slv_err=" << ((dmasr & (1u << 5)) != 0)
              << " dma_dec_err=" << ((dmasr & (1u << 6)) != 0)
              << '\n';
}

void usage(const char* argv0) {
    std::cout
        << "Usage: " << argv0 << " [options]\n"
        << "Options:\n"
        << "  --ctrl-base <addr>  ctrlsys_core AXI-Lite base, default 0x40000000\n"
        << "  --dma-base <addr>   AXI DMA AXI-Lite base, default 0x40400000\n"
        << "  --iic-base <addr>   AXI IIC AXI-Lite base, default 0x41600000\n"
        << "  --bno-addr <addr>   BNO055 7-bit I2C address, default 0x28\n"
        << "  --iic-timeout-ms <ms> AXI IIC transaction timeout, default 1000\n"
        << "  --poll-ms <ms>      DMA/status poll duration, default 10000\n"
        << "  --help              show this help\n";
}

} // namespace

int main(int argc, char** argv) {
    std::uint64_t ctrl_base = kCtrlBaseDefault;
    std::uint64_t dma_base = kDmaBaseDefault;
    std::uint64_t iic_base = kIicBaseDefault;
    std::uint8_t bno_addr = kBno055AddrDefault;
    std::uint32_t iic_timeout_ms = 1000;
    std::uint32_t poll_ms = 10000;

    try {
        for (int i = 1; i < argc; ++i) {
            const std::string arg = argv[i];
            auto value = [&](const char* name) -> const char* {
                if (i + 1 >= argc) {
                    throw std::invalid_argument(std::string("missing value for ") + name);
                }
                return argv[++i];
            };

            if (arg == "--ctrl-base") {
                ctrl_base = parse_u64(value("--ctrl-base"));
            } else if (arg == "--dma-base") {
                dma_base = parse_u64(value("--dma-base"));
            } else if (arg == "--iic-base") {
                iic_base = parse_u64(value("--iic-base"));
            } else if (arg == "--bno-addr") {
                const auto parsed = parse_u64(value("--bno-addr"));
                if (parsed > 0x7f) {
                    throw std::invalid_argument("--bno-addr must be a 7-bit I2C address");
                }
                bno_addr = static_cast<std::uint8_t>(parsed);
            } else if (arg == "--iic-timeout-ms") {
                iic_timeout_ms = static_cast<std::uint32_t>(parse_u64(value("--iic-timeout-ms")));
            } else if (arg == "--poll-ms") {
                poll_ms = static_cast<std::uint32_t>(parse_u64(value("--poll-ms")));
            } else if (arg == "--help") {
                usage(argv[0]);
                return 0;
            } else {
                throw std::invalid_argument("unknown option: " + arg);
            }
        }

        const int fd = open("/dev/mem", O_RDWR | O_SYNC);
        if (fd < 0) {
            throw std::runtime_error(std::string("open /dev/mem failed: ") + std::strerror(errno));
        }

        MappedRegion ctrl(fd, ctrl_base, kCtrlRange);
        MappedRegion dma(fd, dma_base, kDmaRange);
        MappedRegion iic(fd, iic_base, kIicRange);
        close(fd);

        std::cout << "Initializing two BNO055 sensors through AXI IIC\n";
        std::cout << "ctrlsys_core base: 0x" << std::hex << ctrl_base << std::dec << '\n';
        std::cout << "axi_dma base:      0x" << std::hex << dma_base << std::dec << '\n';
        std::cout << "axi_iic base:      0x" << std::hex << iic_base << std::dec << '\n';
        std::cout << "BNO055 address:    " << hex8(bno_addr) << '\n';
        print_iic_status(iic, "initial AXI IIC");
        for (std::uint32_t sensor = 0; sensor < kNumSensors; ++sensor) {
            std::cout << "sensor " << sensor << ": select mux row and write BNO055 config\n";
            select_sensor_for_axi_iic(ctrl, sensor);
            print_iic_status(iic, "after selecting sensor " + std::to_string(sensor));
            init_bno055_on_selected_bus(iic, bno_addr, iic_timeout_ms);
        }

        std::cout << "Starting FPGA reads at 1 second sample period\n";
        ctrl.write32(CtrlReg::Control, CtrlBit::SoftReset);
        sleep_ms(10);
        ctrl.write32(CtrlReg::SamplePeriod, kSamplePeriodCycles);
        ctrl.write32(CtrlReg::SensorEnableMask, kSensorMask);
        ctrl.write32(CtrlReg::Command, CmdBit::ClearError | CmdBit::ResetSampleCounter | CmdBit::CpuClearIrq);
        ctrl.write32(CtrlReg::Control, CtrlBit::Enable);

        print_ctrl_status(ctrl);
        print_dma_status(dma);

        const auto start = std::chrono::steady_clock::now();
        while (true) {
            const auto now = std::chrono::steady_clock::now();
            const auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
            if (elapsed_ms > poll_ms) {
                break;
            }

            std::cout << "t=" << elapsed_ms << "ms ";
            print_ctrl_status(ctrl);
            std::cout << "t=" << elapsed_ms << "ms ";
            print_dma_status(dma);
            sleep_ms(1000);
        }

        return 0;
    } catch (const std::exception& e) {
        std::cerr << "error: " << e.what() << '\n';
        std::cerr << "Run with --help for options.\n";
        return 1;
    }
}
