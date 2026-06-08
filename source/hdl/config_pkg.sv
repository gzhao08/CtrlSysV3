package config_pkg;

	parameter string TOP_MODULE_NAME = "design_1";
	parameter int NUM_SENSORS = 2;
	parameter int BUFFER_SIZE = 5;

	typedef struct packed{
	    logic [63:0]    init_read_ts; // timestamp that read was initiated
	    logic [63:0]    done_read_ts; // timestamp that read finished
	    logic           valid;        // whether data is valid or not
	    logic [143:0]   sensor_data;  // 
	} raw_packet_t;
	
	typedef struct packed{
	    raw_packet_t packets [NUM_SENSORS-1:0];
	} raw_frame_t;


endpackage