class monitor extends uvm_monitor;
  	//Fabrica
    `uvm_component_utils(monitor)

    int id; // este id se escribe en la fase de build del agente

  	//Constructor
    function new(string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
      `uvm_info ("MONITOR", "Inicializacion",UVM_LOW);
    endfunction //new()

    uvm_analysis_port #(secuence_item_test_agent) mon_analysis_port;
    virtual dut_if _if; // interface virtual del DUT

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      
      	if(!uvm_config_db#(virtual dut_if)::get(this, "", "dut_if", _if))
          `uvm_fatal("MONITOR", "No se encontró la interface")
        mon_analysis_port = new ("mon_analysis_port",this);
      
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        receive();
       
      
  	endtask
  
    virtual task receive ();
        _if.reset = 1;
        @(posedge _if.clk);
      	_if.reset = 0;
      
        forever begin
         //display ("Dentro");
          @(posedge _if.clk);
          if(_if.pndng[this.id]) begin
          	secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item");
            m_item.paquete = _if.data_out[this.id]; // se guarda lo que sale de la fifo en el objeto transaction (ID y PAYLOAD)
            m_item.tiempo_recibido = $time;    // se guarda el tiempo en que se hizo pop a la FIFO
            m_item.term_recibido = this.id;    // se guarda el terminal que hace pop
            m_item.UnPackage();
            @(posedge _if.clk);
            _if.pop[this.id] = 1; //Le hace pop al dato
            @(posedge _if.clk);
            _if.pop[this.id] = 0; //pone pop en bajo

            mon_analysis_port.write(m_item);
            `uvm_info("MON", $sformatf("T=%g Se recibió un dato: %h ", $time, m_item.paquete), UVM_LOW)
            
          end else begin
            continue;
          end 
        end
      
    endtask

endclass