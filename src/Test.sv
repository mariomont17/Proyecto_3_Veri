class test extends uvm_test;
    `uvm_component_utils (test)

    function new (string name ="test", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    env e0;

  	virtual dut_if _if;

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        e0 = env::type_id::create("e0",this);


        //Parte para conectar la interface
    
      if (!uvm_config_db#(virtual dut_if)::get(this,"", "dut_if", _if))
        `uvm_fatal ("TEST", "Did not get _if")
		
        //Conecto la interfaz con el driver y el monitor 
        for (int i = 0; i < 16 ; i++)begin
          uvm_config_db#(virtual dut_if)::set(this,$sformatf("e0.a0.d%0d",i),"dut_if", _if);
          uvm_config_db#(virtual dut_if)::set(this,$sformatf("e0.a0.m%0d",i),"dut_if", _if);
        end

    
    endfunction 

    virtual task run_phase (uvm_phase phase);
      secuence_test_agent seq = secuence_test_agent::type_id::create("seq");
      //Levanta la mano y hasta que no se baje no termina la simulacion
      phase.raise_objection(this);
      apply_reset();
      
      for (int i = 0; i < 16 ; i++) begin
        seq.start(e0.a0.s[i]);  //Inicio de la secuencia en todos los secuenciadores
      end 
      
      phase.drop_objection(this);  //Baja la mano para terminar la simulacion
    endtask

    
    virtual task apply_reset();
        _if.reset <= 1;
      repeat(5) @ (posedge _if.clk);
        _if.reset <= 0;
      repeat(10) @ (posedge _if.clk);
        
    endtask
    
endclass