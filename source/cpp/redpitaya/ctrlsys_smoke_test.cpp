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
constexpr std::size_t kCtrlRange = 0x1000;
constexpr std::size_t kDmaRange = 0x10000;

namespace CtrlReg {
constexpr std::uint32_t Control = 0x00;
constexpr std::uint32_t SamplePeriod = 0x04;
constexpr std::uint32_t SensorEnableMask = 0x08;
constexpr std::uint32_t Command = 0x0c;
constexpr std::uint32_t Status = 0x10;
constexpr std::uint32_t SampleCount = 0x14;
constexpr std::uint32_t ErrorCode = 0x1c;
constexpr std::uint32_t DataWord0 = 0x20;
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

namespace StatusBit {
constexpr std::uint32_t Busy = 1u << 0;
constexpr std::uint32_t Error = 1u << 1;
constexpr std::uint32_t ReadInProgress = 1u << 2;
constexpr std::uint32_t PacketDone = 1u << 3;
}

namespace DmaReg {
constexpr std::uint32_t S2mmDmacr = 0x30;
constexpr std::uint32_t S2mmDmasr = 0x34;
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
            throw std::runtime_error("mmap failed at 0x" + hex64(base) + ": " + std::strerror(errno));
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
        check_offset(offset);
        volatile auto* ptr = reinterpret_cast<volatile std::uint32_t*>(base_ + offset_ + offset);
        return *ptr;
    }

    void write32(std::uint32_t offset, std::uint32_t value) const {
        check_offset(offset);
        volatile auto* ptr = reinterpret_cast<volatile std::uint32_t*>(base_ + offset_ + offset);
        *ptr = value;
    }

private:
    static std::string hex64(std::uint64_t value) {
        std::ostringstream oss;
        oss << std::hex << value;
        return oss.str();
    }

    void check_offset(std::uint32_t offset) const {
        if (offset + sizeof(std::uint32_t) > size_) {
            throw std::out_of_range("register offset outside mapped region");
        }
    }

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

void print_status(std::uint32_t status) {
    const auto state = (status >> 4) & 0x0f;
    std::cout << "status=" << hex32(status)
              << " busy=" << ((status & StatusBit::Busy) != 0)
              << " error=" << ((status & StatusBit::Error) != 0)
              << " read_in_progress=" << ((status & StatusBit::ReadInProgress) != 0)
              << " packet_done=" << ((status & StatusBit::PacketDone) != 0)
              << " state=" << state << '\n';
}

void print_dma_s2mm_status(std::uint32_t dmasr) {
    std::cout << "dma_s2mm_dmasr=" << hex32(dmasr)
              << " halted=" << ((dmasr & (1u << 0)) != 0)
              << " idle=" << ((dmasr & (1u << 1)) != 0)
              << " sg_included=" << ((dmasr & (1u << 3)) != 0)
              << " dma_int_err=" << ((dmasr & (1u << 4)) != 0)
              << " dma_slv_err=" << ((dmasr & (1u << 5)) != 0)
              << " dma_dec_err=" << ((dmasr & (1u << 6)) != 0)
              << '\n';
}

void usage(const char* argv0) {
    std::cout
        << "Usage: " << argv0 << " [options]\n"
        << "\n"
        << "Options:\n"
        << "  --ctrl-base <addr>       ctrlsys_core AXI-Lite base, default 0x40000000\n"
        << "  --dma-base <addr>        AXI DMA AXI-Lite base, default 0x40400000\n"
        << "  --sample-period <cycles> sample period written before enabling, default 5000000\n"
        << "  --mask <bits>            sensor_enable_mask, default 0 meaning all sensors\n"
        << "  --poll-ms <ms>           poll duration, default 2000\n"
        << "  --use-axi-iic            set control.useAXI, useful for CPU-controlled AXI IIC mode\n"
        << "  --no-reset               skip soft reset pulse\n"
        << "  --no-enable              leave enable bit cleared after setup\n"
        << "  --help                   show this help\n";
}

} // namespace

int main(int argc, char** argv) {
    std::uint64_t ctrl_base = kCtrlBaseDefault;
    std::uint64_t dma_base = kDmaBaseDefault;
    std::uint32_t sample_period = 5000000;
    std::uint32_t sensor_mask = 0;
    std::uint32_t poll_ms = 2000;
    bool use_axi_iic = false;
    bool do_reset = true;
    bool do_enable = true;

    try {
        for (int i = 1; i < argc; ++i) {
            const std::string arg = argv[i];
            auto need_value = [&](const char* name) -> const char* {
                if (i + 1 >= argc) {
                    throw std::invalid_argument(std::string("missing value for ") + name);
                }
                return argv[++i];
            };

            if (arg == "--ctrl-base") {
                ctrl_base = parse_u64(need_value("--ctrl-base"));
            } else if (arg == "--dma-base") {
                dma_base = parse_u64(need_value("--dma-base"));
            } else if (arg == "--sample-period") {
                sample_period = static_cast<std::uint32_t>(parse_u64(need_value("--sample-period")));
            } else if (arg == "--mask") {
                sensor_mask = static_cast<std::uint32_t>(parse_u64(need_value("--mask")));
            } else if (arg == "--poll-ms") {
                poll_ms = static_cast<std::uint32_t>(parse_u64(need_value("--poll-ms")));
            } else if (arg == "--use-axi-iic") {
                use_axi_iic = true;
            } else if (arg == "--no-reset") {
                do_reset = false;
            } else if (arg == "--no-enable") {
                do_enable = false;
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
        close(fd);

        std::cout << "ctrlsys_core base: 0x" << std::hex << ctrl_base << std::dec << '\n';
        std::cout << "axi_dma base:      0x" << std::hex << dma_base << std::dec << '\n';

        std::cout << "\nInitial registers\n";
        std::cout << "control=" << hex32(ctrl.read32(CtrlReg::Control)) << '\n';
        std::cout << "sample_period=" << ctrl.read32(CtrlReg::SamplePeriod) << '\n';
        std::cout << "sensor_enable_mask=" << hex32(ctrl.read32(CtrlReg::SensorEnableMask)) << '\n';
        print_status(ctrl.read32(CtrlReg::Status));
        std::cout << "sample_count=" << ctrl.read32(CtrlReg::SampleCount) << '\n';
        std::cout << "error_code=" << hex32(ctrl.read32(CtrlReg::ErrorCode)) << '\n';
        std::cout << "dma_s2mm_dmacr=" << hex32(dma.read32(DmaReg::S2mmDmacr)) << '\n';
        print_dma_s2mm_status(dma.read32(DmaReg::S2mmDmasr));

        if (do_reset) {
            ctrl.write32(CtrlReg::Control, CtrlBit::SoftReset);
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        ctrl.write32(CtrlReg::SamplePeriod, sample_period);
        ctrl.write32(CtrlReg::SensorEnableMask, sensor_mask);
        ctrl.write32(CtrlReg::Command, CmdBit::ClearError | CmdBit::ResetSampleCounter | CmdBit::CpuClearIrq);

        std::uint32_t control = 0;
        if (do_enable) {
            control |= CtrlBit::Enable;
        }
        if (use_axi_iic) {
            control |= CtrlBit::UseAxiIic;
        }
        ctrl.write32(CtrlReg::Control, control);

        std::cout << "\nConfigured registers\n";
        std::cout << "control=" << hex32(ctrl.read32(CtrlReg::Control)) << '\n';
        std::cout << "sample_period=" << ctrl.read32(CtrlReg::SamplePeriod) << '\n';
        std::cout << "sensor_enable_mask=" << hex32(ctrl.read32(CtrlReg::SensorEnableMask)) << '\n';

        const auto start = std::chrono::steady_clock::now();
        auto last_sample_count = ctrl.read32(CtrlReg::SampleCount);
        std::cout << "\nPolling for " << poll_ms << " ms\n";

        while (true) {
            const auto now = std::chrono::steady_clock::now();
            const auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
            if (elapsed_ms > poll_ms) {
                break;
            }

            const auto status = ctrl.read32(CtrlReg::Status);
            const auto sample_count = ctrl.read32(CtrlReg::SampleCount);
            if (sample_count != last_sample_count || (status & (StatusBit::Error | StatusBit::PacketDone)) != 0) {
                std::cout << "t=" << elapsed_ms << "ms ";
                print_status(status);
                std::cout << "sample_count=" << sample_count
                          << " error_code=" << hex32(ctrl.read32(CtrlReg::ErrorCode))
                          << '\n';
                last_sample_count = sample_count;

                ctrl.write32(CtrlReg::Command, CmdBit::CpuClearIrq);
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }

        std::cout << "\nData preview words\n";
        for (std::uint32_t i = 0; i < 8; ++i) {
            const auto value = ctrl.read32(CtrlReg::DataWord0 + 4 * i);
            std::cout << "data_word" << i << "=" << hex32(value) << '\n';
        }

        std::cout << "\nFinal status\n";
        print_status(ctrl.read32(CtrlReg::Status));
        std::cout << "sample_count=" << ctrl.read32(CtrlReg::SampleCount) << '\n';
        std::cout << "error_code=" << hex32(ctrl.read32(CtrlReg::ErrorCode)) << '\n';

        return 0;
    } catch (const std::exception& e) {
        std::cerr << "error: " << e.what() << '\n';
        std::cerr << "Run with --help for options.\n";
        return 1;
    }
}
