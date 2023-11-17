class functional_coverage_router extends uvm_subscriber #(secuence_item_test_agent);
	`uvm_component_utils(functional_coverage_router)
  	
 	bit [7:0] id;
  	bit  mode;
  	bit [3:0] term_recibido;
  	
  	secuence_item_test_agent from_monitor;
  	
  	covergroup cg;
        ids_posibles: coverpoint id {   
                //Verifica que se generen paquetes para todos los dispositivos posibles
                bins b1[] = {8'h01, 8'h02, 8'h03, 8'h04,
                        8'h10, 8'h20, 8'h30, 8'h40,
                        8'h51, 8'h52, 8'h53, 8'h54,
                        8'h15, 8'h25, 8'h35, 8'h45};
        }
      	term_rx: coverpoint term_recibido; // todos los posibles 16 valores
      	modos_posibles: coverpoint mode; // los posibles modos
      	idxmode: cross ids_posibles, modos_posibles; // Verifica si se dan las 32 posibles opciones de ID y modo
		
    endgroup: cg
  
  	function new(string name = "functional_coverage_router", uvm_component parent = null);
        super.new(name, parent);
        cg = new();
    endfunction
  	
  	  	
  function void write(secuence_item_test_agent trans);
      from_monitor = trans;
//     `uvm_info("COV", $sformatf("Muestra recibida..."), UVM_LOW);
      this.id = from_monitor.paquete[`ancho-9:`ancho-16];
      this.mode = from_monitor.paquete[`ancho-17];
      this.term_recibido = from_monitor.term_recibido;
      cg.sample();
    endfunction: write
  
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("COV", $sformatf("Cobertura Funcional total es:  %0.2f %%",  cg.get_coverage()), UVM_LOW);
    `uvm_info("COV", $sformatf("Cobertura de IDs posibles:  %0.2f %%",  cg.ids_posibles.get_coverage()), UVM_LOW);
    `uvm_info("COV", $sformatf("Cobertura de modos posibles:  %0.2f %%",  cg.modos_posibles.get_coverage()), UVM_LOW);
    `uvm_info("COV", $sformatf("Cobertura de terminales de recepción:  %0.2f %%",  cg.term_rx.get_coverage()), UVM_LOW);
    `uvm_info("COV", $sformatf("Cobertura de cruce de IDs con modos posibles:  %0.2f %%",  cg.idxmode.get_coverage()), UVM_LOW);
   
  endfunction      
  
endclass



