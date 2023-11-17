class sequence_item_scb extends uvm_sequence_item;
  
  	bit [`ancho-1:0] paquete_enviado;                // paquete enviado al bus
  	bit [`ancho-1:0] paquete_recibido;               // paquete recibido en terminal
    int tiempo_envio;                               // tiempo en el que se envió el paquete
    int tiempo_recibido;                            // tiempo en el que se recibe el paquete
    int latencia;                                   // latencia
    int term_tx;                                    // terminal de envio
    int term_rx;                                    // terminal de recepcion 
    bit completado;                                 // bit de transaccion completada
	
  	function new(string name = "sequence_item_scb");
  		super.new(name);
  	endfunction
  	
  	`uvm_object_utils_begin(sequence_item_scb)
  		`uvm_field_int (paquete_enviado, UVM_HEX)
        `uvm_field_int (paquete_recibido, UVM_HEX)
  		`uvm_field_int (tiempo_envio, UVM_DEC)
        `uvm_field_int (tiempo_recibido, UVM_DEC)
        `uvm_field_int (latencia, UVM_DEC)
        `uvm_field_int (term_tx, UVM_DEC)
        `uvm_field_int (term_rx, UVM_DEC)
  		`uvm_field_int (completado, UVM_BIN)
  	`uvm_object_utils_end
  
  
    task calc_latencia;
        this.latencia = this.tiempo_recibido - this.tiempo_envio;
    endtask
  	

  
endclass