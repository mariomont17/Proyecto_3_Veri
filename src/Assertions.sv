module assertions_fifo #(
    parameter depth = 16,
    parameter bits = 32
    )
    (
    input logic clk,
    input logic reset, 
    input logic pop,
    input logic push, 
    input logic pndng,
    input logic [bits-1:0]Din,
    input logic [bits-1:0]Dout,
    input logic [$clog2(depth):0] count
    );

    default clocking @(posedge clk); endclocking

    //Si hay un reset entonces el pnding = 0, Dout = 0 y count = 0
    property check_reset;
        reset |-> ##1 (pndng === 0) && (Dout === 0) && (count === 0);
    endproperty

    //Si la fifo del router esta llena entonces no deberia haber un push
    property push_when_full;
        disable iff (reset)
        (count === depth) && push |-> ##1 $stable(count);
    endproperty

    //Si la fifo esta vacia entonces no deberia existir un pop
    property pop_when_empty;
        disable iff (reset)
        (count === 0) && pop |-> ##1 $stable(count);
    endproperty


    //Si el count de la fifo es diferente de 0 entonces el pnding deberia ser 1
    property pending_flag;
        disable iff (reset)
        (count != 0) |-> pndng;
    endproperty

    //Si un dato entra en una FIFO -> count es distinto de cero por lo que en algún momento debe suceder un pop para que el dato salga de la FIFO
    // de otorga un tiempo para hacer pop de 0 a 100 ciclos del reloj 
    property pop_dout;
      disable iff(reset) 
      (count != 0)  |-> ##[0:100] pop;
    endproperty


    //Display de las aserciones.
    prop_check_reset: assert property (check_reset) else $display("FIFO RESET ERROR");
    prop_push_when_full: assert property (push_when_full) else $display("FIFO COUNT CHANGING WHEN PUSH & FULL");
    prop_pop_when_empty: assert property (pop_when_empty) else $display("FIFO COUNT CHANGING WHEN POP & EMPTY");
    prop_pending_flag: assert property (pending_flag) else $display("PENDING FLAG ERROR");
    prop_pop_dout: assert property (pop_dout) else $display("FIFO NOT POPPING DATA");

endmodule

//Se conecta el modulo de aserciones con el modulo que se desea verificar.
bind fifo_flops_no_full assertions_fifo#(depth,bits) a2(clk,rst,pop,push,pndng,Din,Dout,count);