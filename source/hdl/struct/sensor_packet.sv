typedef struct {
    logic [63:0]    init_read_ts; // timestamp that read was initiated
    logic [63:0]    done_read_ts; // timestamp that read finished
    logic           valid;        // whether data is valid or not
    logic [143:0]   sensor_data;  // 
} sensor_packet_t;