class Agente extends uvm_agent;
  `uvm_component_utils(Agente)
  function new (string name = "Agente", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  driver d0;  //Como es solo prueba se hace un solo 
  
  uvm_secuencer #(secuence_item_test_agent) s0;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s0 = uvm_secuencer#(secuence_item_test_agent)::type_id::create("s0",this);
    d0 = driver::type_id::create("d0",this);
  endfunction
  
  virtual function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    d0.seq_item_port.connect(s0.seq_item_export);
  endfunction
  
endclass