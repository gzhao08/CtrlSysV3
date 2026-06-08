typedef struct packed{
    sensor_packet_t packets [NUM_SENSORS-1:0];
} data_frame_t;