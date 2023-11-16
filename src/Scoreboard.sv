
class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)
  
  uvm_analysis_export #(secuence_item_test_agent) in_export;  // Comunicacion con el Drivers
  uvm_analysis_export #(secuence_item_test_agent)  out_export; // Comunicacion con los Monitores
  uvm_tlm_analysis_fifo #(secuence_item_test_agent) in_fifo; 
  uvm_tlm_analysis_fifo #(secuence_item_test_agent) out_fifo;

  // Arreglo asociativo de paquetes con indice del dispositivo
  secuence_item_test_agent expected_out_array[int];    
  secuence_item_test_agent actual_out_array[int];

  // Queues para guardar el indice
  int expected_out_q[$];
  int actual_out_q[$];

  function new (string name = "scoreboard" , uvm_component parent = null) ;
    super.new(name, parent);
  endfunction

  function void build_phase (uvm_phase phase);
    in_fifo    = new("in_fifo", this);
    out_fifo   = new("out_fifo", this);
    in_export  = new("in_export", this);
    out_export = new("out_export", this);
  endfunction

  function void connect_phase (uvm_phase phase);
    in_export.connect(in_fifo.analysis_export);
    out_export.connect(out_fifo.analysis_export);
  endfunction

  task run_phase( uvm_phase phase);

  secuence_item_test_agent d_txn;  // Desde el driver 
  secuence_item_test_agent m_txn;  // Desde el monitor
    forever begin
      fork      
        begin 
          in_fifo.get(d_txn);
          process_data(d_txn);   // Procesa el paquete recibido
        end
        begin
          out_fifo.get(m_txn);
          actual_out_array[m_txn.term_recibido] = m_txn; // Guarda el paquete en el array correspondiente al id del monitor que recibio
          actual_out_q.push_back(m_txn.term_recibido);
        end

      join
      compare_data();  // Compara los datos ( Checker)
    end
  endtask
  
  // REFERENCE MODEL
  // Procesa el paquete de entrada para generar el valor esperado
  task process_data(secuence_item_test_agent d_txn);
    
    secuence_item_test_agent exp_out_txn;
    int id_destino;
    d_txn.term_dest();
    id_destino = d_txn.term_recibido;
    exp_out_txn = d_txn;

    expected_out_array[id_destino] = exp_out_txn;
    expected_out_q.push_back(id_destino);
  endtask
  
  task compare_data();
    int idx;
    secuence_item_test_agent exp_txn;
    secuence_item_test_agent act_txn;

    if(expected_out_q.size() > 0 && actual_out_q.size() > 0) begin
      idx = expected_out_q.pop_front();
      
      // Revisa si existe el id del dispositivo en el queue de ids
      if(actual_out_array.exists(idx)) begin 
        exp_txn = expected_out_array[idx];
        act_txn = actual_out_array[idx];
        
        if(!(exp_txn.row == act_txn.row && exp_txn.column == act_txn.column && exp_txn.mode == act_txn.mode && exp_txn.payload == act_txn.payload)) begin
          `uvm_error("SCB",$sformatf("Paquete esperado = %h no coincide con el paquete recibido = %h", exp_txn.paquete, act_txn.paquete));
        end
        else begin
          `uvm_info("SCB", $sformatf("Paquete esperado = %h si coincide con el paquete recibido = %h", exp_txn.paquete, act_txn.paquete), UVM_LOW);
          actual_out_array.delete(idx);
        end
      end
      else begin 
        `uvm_error("SCB",$sformatf("El id %0d no existe en el sistema",idx));
        //expected_out_q.push_back(idx);
      end 
    end
  endtask

endclass