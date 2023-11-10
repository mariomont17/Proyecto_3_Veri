interface dut_if #(
    parameter pckg_sz =40
    )(
    input bit clk
    );

    logic   reset;
    logic   pndng[16];
    logic   pop[16];
    logic   pndng_i_in[16];
    logic   popin[16];
    logic   [pckg_sz-1:0] data_out[16];
    logic   [pckg_sz-1:0]data_out_i_in[16];

endinterface