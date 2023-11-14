class driver extends uvm_driver #(secuence_item_test_agent);

    `uvm_component_utils(driver)

    bit [`ancho-1:0] fifo_emul [$:`profundidad];  // queue que emula el comportamiento de la FIFO de entrada al DUT
    bit pop;    // señal de pop que viene desde el DUT
    bit pndng;  // señal de pending hacia el DUT
    int id; // identificador de la FIFO de entrada (0 a 15), se debe escribir en la fase de build del agente
    int espera; // retardo entre transacciones

    function new(string name = "driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    virtual dut_if _if; // interfaz virtual del DUT

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      
      	if(!uvm_config_db#(virtual dut_if)::get(this, "", "dut_if", _if))
        	`uvm_fatal("DRIVER", "No se encontró la interface")
    endfunction
  
    virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      
      _if.reset = 1;
      @(posedge _if.clk);
      for(int i = 0; i<4; i++)begin
        @(posedge _if.clk);
      end 
      
      forever begin 
        secuence_item_test_agent m_item;
        //`uvm_info("DRV", $sformatf("Espera por una transaccion: "), UVM_LOW)
        seq_item_port.get_next_item(m_item);
        //Verifica si el paquete pertenece a este driver 
        if (m_item.term_envio == this.id)begin //Solo la toma si la terminal de envio corresponde y si las fifos no estan llenas 
          //`uvm_info("DRV", $sformatf("Transaccion Recibida, id = %0d", id), UVM_LOW)
          
		  //Hace el retardo
          espera = 0;
          while(espera < m_item.retardo) begin   // se esperan los ciclos del reloj entre transacciones
            @(posedge _if.clk);
              espera = espera + 1;
          end
       
          m_item.tiempo_envio = $time; //Setea el tiempo en el cual se envio.
          drive_item(m_item);
      	  seq_item_port.item_done();
          
        end else begin
          seq_item_port.item_done();
          continue;
        end 
        
      end
    endtask

    virtual task drive_item(secuence_item_test_agent m_item);
      
      	@(posedge _if.clk);
		_if.reset = 0;
        pop = _if.popin[id];    //Se actualiza el pop cada flanco de reloj
      	_if.data_out_i_in[this.id] = fifo_emul[0]; // D_pop apunta al primer elemento de la FIFO
       

      	
        if (m_item.tipo == 0) begin
          _if.reset <= 1;
          @(posedge _if.clk);
          _if.reset <= 0;
          
        end else begin
          
          if(fifo_emul.size()<`profundidad)begin
            fifo_emul.push_back(m_item.paquete);
          end 
          
          if(pop) begin
            _if.data_out_i_in[this.id] = fifo_emul.pop_front();
            `uvm_info("DRV", $sformatf("Transaccion enviada al DUT, id = %0d", id), UVM_LOW) //Funcionando
          end 

          if (fifo_emul.size() != 0) begin // si la FIFO no esta vacía
            pndng = 1;  // se pone la señal de pending en alto
          end else begin
            pndng = 0; // si esta vacia se pone en bajo
          end
          
          _if.pndng_i_in[this.id] = pndng; // se actualiza la señal de pending del DUT
          
        end
		
    endtask
      

endclass //driver extends uvm_driver #(seq_item)