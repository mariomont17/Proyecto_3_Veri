class test extends uvm_test;
    `uvm_component_utils (test)

    function new (string name ="test", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    env e0;
  	secuence_test_agent seq;
  
  	virtual dut_if _if;

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        e0 = env::type_id::create("e0",this);


        //Parte para conectar la interface
    
      if (!uvm_config_db#(virtual dut_if)::get(this,"", "dut_if", _if))
        `uvm_fatal ("TEST", "Did not get _if")
		
        //Conecto la interfaz con el driver y el monitor 
        for (int i = 0; i < 16 ; i++)begin
          uvm_config_db#(virtual dut_if)::set(this,$sformatf("e0.a0.d[%0d]",i),"dut_if", _if);
          uvm_config_db#(virtual dut_if)::set(this,$sformatf("e0.a0.m[%0d]",i),"dut_if", _if);
        end

    
    endfunction 

    virtual task run_phase (uvm_phase phase);
      
      //Levanta la mano y hasta que no se baje no termina la simulacion
      
      phase.raise_objection(this); 
      
      seq = secuence_test_agent::type_id::create("seq"); // primera secuencia - TRANSACCION ESPECIFICA
      seq.instruccion = trans_especifica;
      seq.term_envio_espec = 3;
      seq.retardo_espec = 4;     //Retardo especifico
      seq.row_espec = 5;         //Fila especifica
      seq.column_espec = 4;       //Columna especifica
      seq.mode_espec = 1;        //Modo especifico
      seq.pyld_espec = 8'haa;    //Payload especifico
      for (int i = 0; i < 16 ; i++) begin
        seq.start(e0.a0.s[i]);  //Inicio de la secuencia en todos los secuenciadores
      end 
	
      // PONER LAS OTRAS SECUENCIAS
      
      #1000
      
      seq = secuence_test_agent::type_id::create("seq"); // primera secuencia - TRANSACCION ESPECIFICA
      seq.instruccion = trans_aleat_x_terminal;
      for (int i = 0; i < 16 ; i++) begin
        seq.start(e0.a0.s[i]);  //Inicio de la secuencia en todos los secuenciadores
      end
      
      phase.drop_objection(this);  //Baja la mano para terminar la simulacion
    endtask

    
    
    
endclass