class agent extends uvm_agent;
  
  `uvm_component_utils(agent)
  function new (string name = "agent", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  
  driver d [16] ;  //Arreglo de drivers (Modificar el driver para que unicamente tome el que le corresponde)
  monitor m [16] ;  //Arreglo de monitores 
  uvm_sequencer #(secuence_item_test_agent) s[16]; //16 secuenciadores distintos
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    for (int i = 0; i < 16; i++)begin  //Inicializacion de los secuenciadores 
      s[i] = uvm_sequencer#(secuence_item_test_agent)::type_id::create($sformatf("s[%0d]", i) ,this);
    end 
    
    for (int i = 0; i < 16; i++)begin //Inicializacion de los drivers y monitores 
      d[i] = driver::type_id::create($sformatf("d[%0d]",i),this); //Inicializo los 16 drivers 
      d[i].id = i; //Se establece el id interno de cada driver 
      
      m[i] = monitor::type_id::create($sformatf("m[%0d]",i),this); //Inicializo los 16 drivers 
      m[i].id = i; //Se establece el id interno de cada driver 
    end 
  endfunction
  
  virtual function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    
    for (int i = 0; i < 16; i++)begin
      d[i].seq_item_port.connect(s[i].seq_item_export); //Conecto cada uno con el secuenciador que corresponde 
    end 
  endfunction
  
endclass