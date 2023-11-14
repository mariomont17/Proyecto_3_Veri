`timescale 1ns/1ps

`define ancho 40
`define filas 4
`define columnas 4
`define profundidad 4
`define broadcast {8{1'b1}}
`define FIFOS
`include "fifo.sv"
`include "Library.sv"
`define LIB 
`include "Router_library.sv"
`include "Interface.sv"
`include "secuence_item.sv"
`include "Driver.sv"
`include "Monitor.sv"
`include "Agente.sv" 
`include "Ambiente.sv"
`include "Test.sv"




module tb;
  
  reg clk;
  
  always #5 clk =~ clk;
  dut_if _if (clk);
  
  //Instancia del DUT y conexion con la interfaz
  mesh_gnrtr #(.ROWS(`filas), .COLUMS(`columnas), .pckg_sz(`ancho), .fifo_depth(`profundidad), .bdcst(`broadcast)) DUT (
        .clk            (clk),
        .reset          (_if.reset),
        .pndng          (_if.pndng),
        .data_out       (_if.data_out),
        .popin          (_if.popin),
        .pop            (_if.pop),
        .data_out_i_in  (_if.data_out_i_in),
        .pndng_i_in     (_if.pndng_i_in)
    );
  
  initial begin
    clk = 0;
    uvm_config_db#(virtual dut_if)::set(null,"uvm_test_top","dut_if", _if);
    run_test ("test");
  end
endmodule