class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    int id; // este id se escribe en la fase de build del agente

    function new(string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    uvm_analysis_port #(secuence_item_test_agent) mon_analysis_port;
  virtual dut_if vif; // interface virtual del DUT

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dut_if)::get(this, "", "dut_if", vif))
            `uvm_fatal("MON", "No se encontró la interface")
        mon_analysis_port = new ("mon_analysis_port",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            @(vif.clk);
            if(!vif.reset) begin
                secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item");
                @(posedge vif.pndng[this.id]);

                m_item.paquete = vif.data_out[this.id]; // se guarda lo que sale de la fifo en el objeto transaction (ID y PAYLOAD)
                m_item.tiempo_recibido = $time;    // se guarda el tiempo en que se hizo pop a la FIFO
                m_item.term_recibido = this.id;    // se guarda el terminal que hace pop
                @(posedge vif.clk);
                vif.pop[this.id] = 1; //Le hace pop al dato
                @(posedge vif.clk);
                vif.pop[this.id] = 0; //pone pop en bajo
                m_item.UnPackage();
                mon_analysis_port.write(m_item);
                `uvm_info("MON", $sformatf("T=%g Se recibió un dato: %h ", $time, m_item.paquete), UVM_LOW)
            end
        end
  endtask

endclass