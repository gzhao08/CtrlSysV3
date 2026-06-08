interface I2C_bus;

    logic sda_i;
    logic sda_o;
    logic sda_t;

    logic scl_i;
    logic scl_o;
    logic scl_t;

    // Master/driver view
    modport master (
        input  sda_i,
        output sda_o,
        output sda_t,

        input  scl_i,
        output scl_o,
        output scl_t
    );

    // Slave/device view, if you ever need to model one
    modport slave (
        output sda_i,
        input  sda_o,
        input  sda_t,

        output scl_i,
        input  scl_o,
        input  scl_t
    );

    // Physical I/O buffer view
    modport pins (
        output sda_i,
        input  sda_o,
        input  sda_t,

        output scl_i,
        input  scl_o,
        input  scl_t
    );

endinterface