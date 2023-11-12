class driver#(parameter ancho =40, parameter profundidad = 4) extends uvm_driver #(seq_item);

    `uvm_component_utils(driver)

    bit [ancho-1:0] fifo_emul [$:profundidad];  // queue que emula el comportamiento de la FIFO de entrada al DUT
    bit pop;    // señal de pop que viene desde el DUT
    bit pndng;  // señal de pending hacia el DUT
    int id; // identificador de la FIFO de entrada (0 a 15), se debe escribir en la fase de build del agente
    int espera; // retardo entre transacciones

    function new(string name = "driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    virtual dut_if #(.pckg_sz(ancho)) vif; // interfaz virtual del DUT

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dut_if)::get(this, "", "dut_if", vif))
            `uvm_fatal("MON", "No se encontró la interface")
    endfunction
  
    virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin 
                secuence_item_test_agent m_item;
                `uvm_info("DRV", $sformatf("Espera por una transaccion: "), UVM_LOW)
                seq_item_port.get_next_item(m_item);
                drive_item(m_item);
                seq_item_port.item_done();
            end
    endtask

    virtual task drive_item(secuence_item_test_agent m_item);
        @(posedge vif.clk);

        espera = 0;
        while(espera < m_item.retardo) begin   // se esperan los ciclos del reloj entre transacciones
            @(posedge vif.clk);
            espera = espera + 1;
        end

        if (m_item.tipo == reset) begin
            vif.reset <= 1;
            @(posedge vif.clk);
            vif.reset <= 0;
        end else begin
            fifo_emul.push_back(m_item.paquete);
            vif.pndng_i_in[this.id] = 1'b1;
            vif.data_out_i_in[this.id] = fifo_emul.pop_front();
            
            @(negedge vif.popin[this.id]);

            vif.data_out_i_in[this.id] = fifo_emul[0]; // D_pop apunta al primer elemento de la FIFO
            
            if (fifo_emul.size() != 0) begin // si la FIFO no esta vacía
                pndng = 1;  // se pone la señal de pending en alto
            end else begin
                pndng = 0; // si esta vacia se pone en bajo
            end
            vif.pndng_i_in[this.id] = pndng; // se actualiza la señal de pending del DUT
        end

    endtask

endclass //driver extends uvm_driver #(seq_item)