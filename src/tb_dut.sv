`define ancho 40
`define filas 4
`define columnas 4
`define profundidad 4
`define broadcast {8{1'b1}}
`include "Interface.sv"
`include "secuence_item.sv"
`include "Driver.sv"
//`include "Monitor.sv"
`include "Agente.sv" 
`include "Ambiente.sv"
`include "Test.sv"




module tb;
  reg clk;
  
  always #10 clk =~ clk;
  dut_if _if (clk);
  
  initial begin
    clk <= 0;
    uvm_config_db#(virtual dut_if)::set(null,"uvm_test_top","dut_if", _if);
    run_test ("test");
  end
endmodule