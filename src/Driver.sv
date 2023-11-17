class driver extends uvm_driver #(secuence_item_test_agent );

  `uvm_component_utils(driver)

  bit [`ancho-1:0] fifo_emul [$:`profundidad];  // queue que emula el comportamiento de la FIFO de entrada al DUT
  
  bit pndng;  // señal de pending hacia el DUT
  int id; // identificador de la FIFO de entrada (0 a 15), se debe escribir en la fase de build del agente
  int espera; // retardo entre transacciones

  uvm_analysis_port #(secuence_item_test_agent) drv_analysis_port;

  function new(string name = "driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction //new()

  virtual dut_if vif; // interfaz virtual del DUT

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "dut_if", vif))
        `uvm_fatal("DRV", "No se encontró la interface")
        drv_analysis_port = new ("drv_analysis_port",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    #100
    forever begin 
      secuence_item_test_agent m_item;
      //`uvm_info("DRV", $sformatf("Espera por una transaccion: "), UVM_LOW)
      seq_item_port.get_next_item(m_item);

      if (m_item.term_envio == this.id) begin
        drive_item(m_item);
        #500;         
      end
  		seq_item_port.item_done();
    end
  endtask

  virtual task drive_item(secuence_item_test_agent  m_item);
    @(posedge vif.clk);
    `uvm_info("DRV", $sformatf("Transaccion Recibida, pkt = %0h, term_envio = %0d, term_destino=%0d", m_item.paquete, m_item.term_envio,m_item.term_recibido ), UVM_LOW)
    
    espera = 0;
    
    while(espera < m_item.retardo) begin   // se esperan los ciclos del reloj entre transacciones
      @(posedge vif.clk);
      espera = espera + 1;
    end

    if (m_item.tipo == 0) begin
      vif.reset <= 1;
      @(posedge vif.clk);
      vif.reset <= 0;
    end else begin
      fifo_emul.push_back(m_item.paquete);
      m_item.tiempo_envio = $time;
      vif.pndng_i_in[this.id] = 1'b1;
      vif.data_out_i_in[this.id] = fifo_emul.pop_front(); 
      drv_analysis_port.write(m_item);      
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