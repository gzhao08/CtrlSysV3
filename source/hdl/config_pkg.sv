package config_pkg;

	parameter string TOP_MODULE_NAME = "design_1";
	parameter int NUM_SENSORS = 3;
	parameter int BUFFER_SIZE = 5;
	parameter int PROTOCOL_WIDTH = 2;
	parameter logic [PROTOCOL_WIDTH-1:0] PROTOCOL_I2C = 2'd0;
	parameter logic [PROTOCOL_WIDTH-1:0] PROTOCOL_SPI = 2'd1;

	// Parameters from sen0.json
	parameter string sen0_Protocol = "I2C";
	parameter int sen0_Sensor_Address = 0;
	parameter int sen0_Register_Address = 5;
	parameter int sen0_Num_Bytes = 18;

	// Parameters from sen1.json
	parameter string sen1_Protocol = "I2C";
	parameter int sen1_Sensor_Address = 127;
	parameter int sen1_Register_Address = 41;
	parameter int sen1_Num_Bytes = 18;

	// Parameters from sen2.json
	parameter string sen2_Protocol = "I2C";
	parameter int sen2_Sensor_Address = 127;
	parameter int sen2_Register_Address = 41;
	parameter int sen2_Num_Bytes = 18;

	// Packed sensor config vectors for generate-loop indexing.
	// Sensor 0 occupies the least-significant slice.
	parameter logic [PROTOCOL_WIDTH*NUM_SENSORS-1:0] SENSOR_PROTOCOLS = {PROTOCOL_I2C, PROTOCOL_I2C, PROTOCOL_I2C};
	parameter logic [7*NUM_SENSORS-1:0] SENSOR_ADDRS = {7'd127, 7'd127, 7'd0};
	parameter logic [8*NUM_SENSORS-1:0] SENSOR_REG_ADDRS = {8'd41, 8'd41, 8'd5};
	parameter logic [8*NUM_SENSORS-1:0] SENSOR_NUM_BYTES = {8'd18, 8'd18, 8'd18};

	typedef struct packed{
	    logic [63:0]    init_read_ts; // timestamp that read was initiated
	    logic [63:0]    done_read_ts; // timestamp that read finished
	    logic [31:0]    flags;        // bit 0: valid, bit 1: ack error
	    logic [15:0]    reserved;     // pads packet to a 32-bit word boundary
	    logic [143:0]   sensor_data;  // 
	} raw_packet_t;
	
	typedef raw_packet_t raw_frame_t [NUM_SENSORS];

endpackage
