package config_pkg;

	parameter string TOP_MODULE_NAME = "design_1";
	parameter int NUM_SENSORS = 3;
	parameter int BUFFER_SIZE = 5;

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

	// Sensor arrays for generate-loop indexing
	parameter string SENSOR_PROTOCOLS [NUM_SENSORS] = '{"I2C", "I2C", "I2C"};
	parameter logic [6:0] SENSOR_ADDRS [NUM_SENSORS] = '{7'd0, 7'd127, 7'd127};
	parameter logic [7:0] SENSOR_REG_ADDRS [NUM_SENSORS] = '{8'd5, 8'd41, 8'd41};
	parameter logic [7:0] SENSOR_NUM_BYTES [NUM_SENSORS] = '{8'd18, 8'd18, 8'd18};

	typedef struct packed{
	    logic [63:0]    init_read_ts; // timestamp that read was initiated
	    logic [63:0]    done_read_ts; // timestamp that read finished
	    logic [31:0]    flags;        // bit 0: valid, bit 1: ack error
	    logic [15:0]    reserved;     // pads packet to a 32-bit word boundary
	    logic [143:0]   sensor_data;  // 
	} raw_packet_t;
	
	typedef raw_packet_t raw_frame_t [NUM_SENSORS];

endpackage
