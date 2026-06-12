typedef struct packed{
    logic [63:0]    init_read_ts; // timestamp that read was initiated
    logic [63:0]    done_read_ts; // timestamp that read finished
    logic [31:0]    flags;        // bit 0: valid, bit 1: ack error
    logic [15:0]    reserved;     // pads packet to a 32-bit word boundary
    logic [143:0]   sensor_data;  // 
} raw_packet_t;

typedef raw_packet_t raw_frame_t [NUM_SENSORS];
