class test extends uvm_test;
    `uvm_component_utils (test)

    function new (string name ="test", uvm_component parent = null);
        super.new (name, parent);
    endfunction

    env e0;

    virtual dut_if #(.ancho(`ancho)) vif;

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        e0 = env::type_id::create("e0",this);


        //Parte para conectar la interface
    
        if (!uvm_config_db#(virtual dut_if #(.ancho(`ancho)))::get(this,"", "dut_if", vif))
            `uvm_fatal ("TEST", "Did not get vif")

        uvm_config_db#(virtual dut_if)::set(this,"e0.a0.*","dut_if", vif);

    
    endfunction 

    virtual task run_phase (uvm_phase phase);
      secuence_test_agent seq = secuence_test_agent::type_id::create("seq");

      //Levanta la mano y hasta que no se baje no termina la simulacion
      phase.raise_objection(this);
      apply_reset();

      seq.start(e0.a0.s0);  //Inicio de la secuencia
      #200;
      phase.drop_objection(this);  //Baja la mano para terminar la simulacio
    endtask

    
    virtual task apply_reset();
        vif.reset <= 1;
        repeat(5) @ (posedge vif.clk);
        vif.reset <= 0;
        repeat(10) @ (posedge vif.clk);
        
    endtask
    
endclass