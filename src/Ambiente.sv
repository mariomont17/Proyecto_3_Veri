class env extends uvm_env;
    `uvm_component_utils (env)

  	function new(string name = "env", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    agent       a0;
    //scoreboard        sb0

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        a0 = agent::type_id::create("a0",this);
        //s0 = scoreboard::type_id::create("sb0",this);
    endfunction


    //Esta parte es para conectar el scoreboard 
    /*
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        a0
    endfunction 

    */
endclass