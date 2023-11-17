class env extends uvm_env;
    `uvm_component_utils (env)

  	function new(string name = "env", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    agent       a0;
    scoreboard  scb;
	
  	functional_coverage_router cov;
  
    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        a0 = agent::type_id::create("a0",this);
        scb = scoreboard::type_id::create("scb",this);
      	cov = functional_coverage_router::type_id::create("cov",this);
    endfunction


    //Esta parte es para conectar el scoreboard 
    
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        for (int i = 0 ; i < 16 ; i++) begin
            a0.m[i].mon_analysis_port.connect(scb.out_export);
            a0.d[i].drv_analysis_port.connect(scb.in_export);
          	a0.m[i].mon_analysis_port.connect(cov.analysis_export);
        end
    endfunction 

    
endclass