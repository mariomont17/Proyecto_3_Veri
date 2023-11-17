typedef bit [10:0] cola_rutas[$];

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

  // Para la verificacion de la ruta
  int contador_auxiliar;
  cola_de_rutas cola_rutas_aux;
  bit [10:0] ruta_aux;

  bit [10:0] assoc_queue [bit [`ancho-9:0]][$]; // arreglo asociativo de colas donde cada index es un paquete y cada elemento de la cola es de 11 bits

  bit[`ancho-1:0] paquete [64];
  bit [3:0] id_r [64]; // id que incluye fila
  bit [3:0] id_c [64];

  // ESTRUCTURAS DE DATOS PARA EL REPORTE
  sequence_item_scb trans_completas[$]; 	// cola de transacciones completadas
  sequence_item_scb trans_incompletas[$]; // Queue de las transacciones NO completadas
  sequence_item_scb transaccion_auxiliar; // se usa para guardar una transaccion del queue principal para su posterior manipulación 
  sequence_item_scb auxiliar_array[$]; // queue que se usa para guardar el queue principal del scoreboard y no perder las transacciones al hacer pop
  
  int retraso_total = 0; // Retraso total en las transacciones hechas 
  int retraso_x_terminal [16]; // Retraso por cada terminal
  int transacciones_completadas = 0; // cantidad de transacciones total completadas
  int transacciones_completadas_x_terminal [16]; // cantidad de transacciones por terminal 
  shortreal retardo_promedio_gen; // Retardo promedio de la prueba

  int tamano_sb = 0; 
  shortreal retardo_promedio_x_terminal [16]; // array con retardos promedio por cada terminal
	
  shortreal tasa_array [$];
  shortreal ab_min;
  shortreal ab_max;
  shortreal ab_prom;

  //Para los .csv
  int report;
  int bw_prom;
  int bw_max;
  int bw_min;
  int reporte_retardo_prom;

  // Registrar en la fabrica
  function new (string name = "scoreboard" , uvm_component parent = null) ;
    super.new(name, parent);
  endfunction

  function void build_phase (uvm_phase phase);
    super.build_phase (phase);
    in_fifo    = new("in_fifo", this);
    out_fifo   = new("out_fifo", this);
    in_export  = new("in_export", this);
    out_export = new("out_export", this);
  endfunction

  function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    in_export.connect(in_fifo.analysis_export);
    out_export.connect(out_fifo.analysis_export);
  endfunction

  virtual task run_phase( uvm_phase phase);
    
    fork 
    	RutaPaquete();
    join_none
    
    forever begin
      secuence_item_test_agent d_txn;  // Desde el driver 
      secuence_item_test_agent m_txn;  // Desde el monitor
      fork
        begin
          in_fifo.get(d_txn);
          //d_txn.print()
          ProcesarPaquetes(d_txn);
        end
        begin
          out_fifo.get(m_txn);
          actual_out_array[m_txn.term_recibido] = m_txn; // Guarda el paquete en el array correspondiente al id del monitor que recibio
          actual_out_q.push_back(m_txn.term_recibido);
        end
      join
      CompararPaquetes();  // Compara los datos ( Checker)
    end
	
endtask
  
  // REFERENCE MODEL
  // Procesa el paquete de entrada para generar el valor esperado
  task ProcesarPaquetes(secuence_item_test_agent d_txn);
    
    secuence_item_test_agent exp_out_txn;
    int id_destino;
    cola_rutas cola_rutas_drv;
    bit [`ancho-9:0] pkcg_drv;

    exp_out_txn = d_txn;
    pkcg_drv = d_txn.paquete[`ancho-9:0];
    d_txn.term_dest();
    id_destino = d_txn.term_recibido;
    cola_rutas_drv = d_txn.cola_rutas;  
    
    foreach(cola_rutas_drv[i]) begin
      assoc_queue[pkcg_drv].push_back(cola_rutas_drv[i]);
    end

    expected_out_array[id_destino] = exp_out_txn;
    expected_out_q.push_back(id_destino);
  endtask
  
  task CompararPaquetes();
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
          `uvm_warning("SCB",$sformatf("Paquete esperado = %h no coincide con el paquete recibido = %h", exp_txn.paquete, act_txn.paquete));
        end
        else begin
          `uvm_info("SCB", $sformatf("Paquete esperado = %h si coincide con el paquete recibido = %h", exp_txn.paquete, act_txn.paquete), UVM_LOW);

          // se guarda la transaccion completada en una cola para su posterior manipulacion en la fase de reportes 
          
          transaccion_auxiliar = sequence_item_scb::type_id::create("transaccion_auxiliar"); // creo la transaccion 
          
          transaccion_auxiliar.paquete_enviado = exp_txn.paquete;
          transaccion_auxiliar.paquete_recibido = act_txn.paquete;
          transaccion_auxiliar.tiempo_envio = exp_txn.tiempo_envio;
          transaccion_auxiliar.tiempo_recibido = act_txn.tiempo_recibido;
          transaccion_auxiliar.term_tx = exp_txn.term_envio;
          transaccion_auxiliar.term_rx = act_txn.term_recibido;
          transaccion_auxiliar.completado = 1;
          transaccion_auxiliar.calc_latencia();
         // transaccion_auxiliar.print();
          
          // se aumentan los retardos entre transacciones 
          retraso_total = retraso_total + transaccion_auxiliar.latencia;
          retraso_x_terminal[transaccion_auxiliar.term_rx] = retraso_x_terminal[transaccion_auxiliar.term_rx] + transaccion_auxiliar.latencia;
          // se aumenta la cantidad de transacciones completadas general y por terminal
          transacciones_completadas++;
          transacciones_completadas_x_terminal[transaccion_auxiliar.term_rx]++;
          // se guarda en una cola de transacciones completadas
          trans_completas.push_back(transaccion_auxiliar);

          actual_out_array.delete(idx);
        end
      end
      else begin 
        `uvm_error("SCB",$sformatf("El id %0d no existe en el sistema",idx));
        //expected_out_q.push_back(idx);
      end 
    end
  endtask

  virtual function void report_phase (uvm_phase phase);
    super.report_phase(phase);
    
    // REPORTE TRANSACCIONES
    `uvm_info("SCB", $sformatf("Reporte --> Reporte csv de paquetes enviados y recibidos"), UVM_LOW);
    report = $fopen("report.csv", "w");
    $fwrite(report, "Dispositivos,Profundidad,Paquete_Enviado,Paquete_Recibido,Tiempo_Envio,Tiempo_Recibido,Terminal_de_Envio,Terminal_de_recibido,Latencia\n");
    
    transaccion_auxiliar = sequence_item_scb::type_id::create("transaccion_auxiliar");
    
    foreach(trans_completas[i]) begin
      
      	transaccion_auxiliar.copy(trans_completas[i]);
      	transaccion_auxiliar.print();      
      	$fwrite(report, "%0d, %0d, %0h, %0h, %0g, %0g, %0g, %0g, %0g\n", 16, `profundidad, transaccion_auxiliar.paquete_enviado, transaccion_auxiliar.paquete_recibido, 
              transaccion_auxiliar.tiempo_envio, transaccion_auxiliar.tiempo_recibido, transaccion_auxiliar.term_tx, transaccion_auxiliar.term_rx,
              transaccion_auxiliar.latencia);
              
   	end
    $fclose(report);
    
    // Se realiza el display de el retardo promedio general y por terminal de la prueba
    `uvm_info("SCB", $sformatf("Reporte --> Retardo promedio general"), UVM_LOW);
    retardo_promedio_gen = retraso_total/transacciones_completadas;
    `uvm_info("SCB", $sformatf("El retardo promedio general es de: %0d ciclos del reloj",  retardo_promedio_gen), UVM_LOW);
    // se escribe en el csv
    reporte_retardo_prom = $fopen("reporte_retardo_prom.csv", "a"); // se imprime en csv el retardo promedio de la transmisión
    $fwrite(reporte_retardo_prom, "Dispositivos,Profundidad,Retardo\n");
    $fwrite(reporte_retardo_prom, "%0d,%0d,%0.2f\n", 16, `profundidad, retardo_promedio_gen);
    $fclose(reporte_retardo_prom);

    
    foreach (retardo_promedio_x_terminal[i]) begin // ciclo for para calcular el retardo promedio por cada terminal
        retardo_promedio_x_terminal[i] = retraso_x_terminal[i]/transacciones_completadas_x_terminal[i];
      `uvm_info("SCB", $sformatf("El retardo promedio en la terminal %0g es: %0d ciclos del reloj", i, retardo_promedio_x_terminal[i]), UVM_LOW);
    end
    
    // SE REALIZA EL REPORTE DE ANCHO DE BANDA
    `uvm_info("SCB", $sformatf("Reporte --> Ancho de banda de la prueba"), UVM_LOW);

    foreach(retardo_promedio_x_terminal[i]) begin  // Para cada transaccion completada, guarda la tasa de bits correspondiente en un arreglo
      tasa_array[i] = `ancho/retardo_promedio_x_terminal[i];    // se calcula la tasa de bits de cada transacción, tasa = bits del paquete/latencia en segundos
    end 

    tasa_array.sort(); //Ordena de mayor a menor
   
    ab_max = tasa_array[$];
    ab_min = tasa_array[0];
    ab_prom = tasa_array.sum()/tasa_array.size();

    `uvm_info("SCB", $sformatf("Ancho de banda máximo: %0f bits/ciclo del reloj", ab_max), UVM_LOW);
    `uvm_info("SCB", $sformatf("Ancho de banda mínimo: %0f bits/ciclo del reloj", ab_min), UVM_LOW);
    `uvm_info("SCB", $sformatf("Ancho de banda promedio: %0f bits/ciclo del reloj", ab_prom), UVM_LOW);
    
    bw_prom = $fopen("reporte_bw_prom.csv", "a");
    bw_max = $fopen("reporte_bw_max.csv", "a");
    bw_min = $fopen("reporte_bw_min.csv", "a");


    $fwrite(bw_prom, "Terminales,Profundidad,Ancho_de_Banda\n");
 
    $fwrite(bw_max, "%0d,%0d,%0.2f\n", 16, `profundidad,  ab_max);
    $fwrite(bw_min, "%0d,%0d,%0.2f\n", 16, `profundidad, ab_min);
    $fwrite(bw_prom, "%0d,%0d,%0.2f\n", 16, `profundidad, ab_prom);
    $fclose(bw_prom);
    $fclose(bw_max);
    $fclose(bw_min);
    
  endfunction

  task RutaPaquete(); //Este run se encarga de buscar un paquete recibido en algun router en un queue generado para verificar si se encuentra en la ruta correcta
      #50
      forever begin
        @(negedge $root.tb.clk) begin
        // PRIMERA FILA
          // ROUTER 11
            if($root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[0].rtr_ntrfs_.popin) //110
            begin
                this.paquete[0] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[0] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[0] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_c;
                // llamar una funcion que busque la transaccion en queue del checker y compare id con la cola_ruta de transaccion
                // debe ir eliminando las rutas del queue conforme se vayan dando 
                void'(VerificarRuta(paquete[0],{id_r[0],id_c[0]}));
                

            end
            if($root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[1].rtr_ntrfs_.popin) //111
            begin
                this.paquete[1] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[1] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[1] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[1],{id_r[1],id_c[1]}));
                
            end
            if($root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[2].rtr_ntrfs_.popin)//112
            begin
                this.paquete[2] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[2] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[2] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[2],{id_r[2],id_c[2]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[3].rtr_ntrfs_.popin)//113
            begin
                this.paquete[3] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[3] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[3] = $root.tb.DUT._rw_[1]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[3],{id_r[3],id_c[3]}));
            end

            // ROUTER 12

            if( $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[0].rtr_ntrfs_.popin)//120
            begin
                this.paquete[4] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[4] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[4] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[4],{id_r[4],id_c[4]}));

            end
            if($root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[1].rtr_ntrfs_.popin)//121
            begin
                this.paquete[5] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[5] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[5] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[5],{id_r[5],id_c[5]}));
                
            end
            if($root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[2].rtr_ntrfs_.popin)//122
            begin
                this.paquete[6] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[6] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[6] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[6],{id_r[6],id_c[6]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[3].rtr_ntrfs_.popin)//123
            begin
                this.paquete[7] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[7] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[7] = $root.tb.DUT._rw_[1]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[7],{id_r[7],id_c[7]}));
            end

          // ROUTER 13

            if( $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[0].rtr_ntrfs_.popin)//130
            begin
                this.paquete[8] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[8] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[8] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[8],{id_r[8],id_c[8]}));
            end
           if($root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[1].rtr_ntrfs_.popin)//131
            begin
                this.paquete[9] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[9] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[9] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[9],{id_r[9],id_c[9]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[2].rtr_ntrfs_.popin)//132
            begin
                this.paquete[10] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[10] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[10] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[10],{id_r[10],id_c[10]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[3].rtr_ntrfs_.popin)//133
            begin
                this.paquete[11] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[11] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[11] = $root.tb.DUT._rw_[1]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[11],{id_r[11],id_c[11]}));
            end

            // ROUTER 14

            if( $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[0].rtr_ntrfs_.popin)//140
            begin
                this.paquete[12] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[12] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[12] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[12],{id_r[12],id_c[12]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[1].rtr_ntrfs_.popin)//141
            begin
                this.paquete[13] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[13] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[13] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[13],{id_r[13],id_c[13]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[2].rtr_ntrfs_.popin)//142
            begin
                this.paquete[14] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[14] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[14] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[14],{id_r[14],id_c[14]}));
            end
            if($root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[3].rtr_ntrfs_.popin)//143
            begin
                this.paquete[15] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[15] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[15] = $root.tb.DUT._rw_[1]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[15],{id_r[15],id_c[15]}));
            end

        // SEGUNDA FILA
            // ROUTER 21
            if($root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[0].rtr_ntrfs_.popin)//210
            begin
                this.paquete[16] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[16] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[16] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[16],{id_r[16],id_c[16]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[1].rtr_ntrfs_.popin)//211
            begin
                this.paquete[17] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[17] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[17] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[17],{id_r[17],id_c[17]}));
                
            end
            if($root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[2].rtr_ntrfs_.popin)//212
            begin
                this.paquete[18] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[18] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[18] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[18],{id_r[18],id_c[18]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[3].rtr_ntrfs_.popin)//213
            begin
                this.paquete[19] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[19] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[19] = $root.tb.DUT._rw_[2]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[19],{id_r[19],id_c[19]}));
            end

            // ROUTER 22

            if( $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[0].rtr_ntrfs_.popin)//220
            begin
                this.paquete[20] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[20] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[20] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[20],{id_r[20],id_c[20]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[1].rtr_ntrfs_.popin)//221
            begin
                this.paquete[21] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[21] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[21] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[21],{id_r[21],id_c[21]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[2].rtr_ntrfs_.popin)//222
            begin
                this.paquete[22] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[22] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[22] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[22],{id_r[22],id_c[22]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[3].rtr_ntrfs_.popin)//223
            begin
                this.paquete[23] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[23] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[23] = $root.tb.DUT._rw_[2]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[23],{id_r[23],id_c[23]}));
            end

          // ROUTER 23

            if( $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[0].rtr_ntrfs_.popin)//230
            begin
                this.paquete[24] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[24] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[24] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[24],{id_r[24],id_c[24]}));
            end
           if($root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[1].rtr_ntrfs_.popin)//231
            begin
                this.paquete[25] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[25] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[25] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[25],{id_r[25],id_c[25]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[2].rtr_ntrfs_.popin)//232
            begin
                this.paquete[26] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[26] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[26] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[26],{id_r[26],id_c[26]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[3].rtr_ntrfs_.popin)//233
            begin
                this.paquete[27] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[27] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[27] = $root.tb.DUT._rw_[2]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[27],{id_r[27],id_c[27]}));
            end

            // ROUTER 24

            if( $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[0].rtr_ntrfs_.popin)//240
            begin
                this.paquete[28] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[28] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[28] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[28],{id_r[28],id_c[28]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[1].rtr_ntrfs_.popin)//241
            begin
                this.paquete[29] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[29] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[29] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[29],{id_r[29],id_c[29]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[2].rtr_ntrfs_.popin)//242
            begin
                this.paquete[30] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[30] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[30] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[30],{id_r[30],id_c[30]}));
            end
            if($root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[3].rtr_ntrfs_.popin)//243
            begin
                this.paquete[31] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[31] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[31] = $root.tb.DUT._rw_[2]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[31],{id_r[31],id_c[31]}));
            end
        // TERCERA FILA
            // ROUTER 31
            if($root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[0].rtr_ntrfs_.popin)//310
            begin
                this.paquete[32] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[32] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[32] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[32],{id_r[32],id_c[32]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[1].rtr_ntrfs_.popin)//311
            begin
                this.paquete[33] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[33] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[33] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[33],{id_r[33],id_c[33]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[2].rtr_ntrfs_.popin)//312
            begin
                this.paquete[34] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[34] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[34] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[34],{id_r[34],id_c[34]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[3].rtr_ntrfs_.popin)//313
            begin
                this.paquete[35] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[35] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[35] = $root.tb.DUT._rw_[3]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[35],{id_r[35],id_c[35]}));
            end

            // ROUTER 32

            if( $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[0].rtr_ntrfs_.popin)//320
            begin
                this.paquete[36] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[36] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[36] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[36],{id_r[36],id_c[36]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[1].rtr_ntrfs_.popin)//321
            begin
                this.paquete[37] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[37] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[37] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[37],{id_r[37],id_c[37]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[2].rtr_ntrfs_.popin)//322
            begin
                this.paquete[38] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[38] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[38] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[38],{id_r[38],id_c[38]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[3].rtr_ntrfs_.popin)//323
            begin
                this.paquete[39] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[39] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[39] = $root.tb.DUT._rw_[3]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[39],{id_r[39],id_c[39]}));
            end

          // ROUTER 33

            if( $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[0].rtr_ntrfs_.popin)//330
            begin
                this.paquete[40] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[40] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[40] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[40],{id_r[40],id_c[40]}));
            end
           if($root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[1].rtr_ntrfs_.popin)//331
            begin
                this.paquete[41] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[41] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[41] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[41],{id_r[41],id_c[41]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[2].rtr_ntrfs_.popin)//332
            begin
                this.paquete[42] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[42] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[42] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[42],{id_r[42],id_c[42]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[3].rtr_ntrfs_.popin)//333
            begin
                this.paquete[43] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[43] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[43] = $root.tb.DUT._rw_[3]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[43],{id_r[43],id_c[43]}));
            end

            // ROUTER 34

            if( $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[0].rtr_ntrfs_.popin)//340
            begin
                this.paquete[44] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[44] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[44] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[44],{id_r[44],id_c[44]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[1].rtr_ntrfs_.popin)//341
            begin
                this.paquete[45] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[45] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[45] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[45],{id_r[45],id_c[45]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[2].rtr_ntrfs_.popin)//342
            begin
                this.paquete[46] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[46] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[46] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[46],{id_r[46],id_c[46]}));
            end
            if($root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[3].rtr_ntrfs_.popin)//343
            begin
                this.paquete[47] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[47] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[47] = $root.tb.DUT._rw_[3]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[47],{id_r[47],id_c[47]}));
            end
        // CUARTA FILA
            // ROUTER 41
            if($root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[0].rtr_ntrfs_.popin)//410
            begin
                this.paquete[48] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[48] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[48] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[48],{id_r[48],id_c[48]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[1].rtr_ntrfs_.popin)//411
            begin
                this.paquete[49] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[49] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[49] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[49],{id_r[49],id_c[49]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[2].rtr_ntrfs_.popin)//412
            begin
                this.paquete[50] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[50] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[50] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[50],{id_r[50],id_c[50]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[3].rtr_ntrfs_.popin)//413
            begin
                this.paquete[51] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[51] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[51] = $root.tb.DUT._rw_[4]._clm_[1].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[51],{id_r[51],id_c[51]}));
            end

            // ROUTER 42

            if( $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[0].rtr_ntrfs_.popin)//420
            begin
                this.paquete[52] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[52] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[52] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[52],{id_r[52],id_c[52]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[1].rtr_ntrfs_.popin)//421
            begin
                this.paquete[53] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[53] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[53] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[53],{id_r[53],id_c[53]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[2].rtr_ntrfs_.popin)//422
            begin
                this.paquete[54] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[54] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[54] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[54],{id_r[54],id_c[54]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[3].rtr_ntrfs_.popin)//423
            begin
                this.paquete[55] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[55] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[55] = $root.tb.DUT._rw_[4]._clm_[2].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[55],{id_r[55],id_c[55]}));
            end

          // ROUTER 43

            if( $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[0].rtr_ntrfs_.popin)//430
            begin
                this.paquete[56] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[56] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[56] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[56],{id_r[56],id_c[56]}));
            end
           if($root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[1].rtr_ntrfs_.popin)//431
            begin
                this.paquete[57] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[57] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[57] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[57],{id_r[57],id_c[57]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[2].rtr_ntrfs_.popin)//432
            begin
                this.paquete[58] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[58] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[58] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[58],{id_r[58],id_c[58]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[3].rtr_ntrfs_.popin)//433
            begin
                this.paquete[59] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[59] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[59] = $root.tb.DUT._rw_[4]._clm_[3].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[59],{id_r[59],id_c[59]}));
            end

            // ROUTER 44

            if( $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[0].rtr_ntrfs_.popin)//440
            begin
                this.paquete[60] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[0].rtr_ntrfs_.data_out_i_in;
                this.id_r[60] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_r; 
                this.id_c[60] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[0].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[60],{id_r[60],id_c[60]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[1].rtr_ntrfs_.popin)//441
            begin
                this.paquete[61] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[1].rtr_ntrfs_.data_out_i_in;
                this.id_r[61] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_r; 
                this.id_c[61] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[1].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[61],{id_r[61],id_c[61]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[2].rtr_ntrfs_.popin)//442
            begin
                this.paquete[62] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[2].rtr_ntrfs_.data_out_i_in;
                this.id_r[62] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_r; 
                this.id_c[62] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[2].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[62],{id_r[62],id_c[62]}));
            end
            if($root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[3].rtr_ntrfs_.popin)
            begin
                this.paquete[63] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[3].rtr_ntrfs_.data_out_i_in;
                this.id_r[63] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_r; 
                this.id_c[63] = $root.tb.DUT._rw_[4]._clm_[4].rtr._nu_[3].rtr_ntrfs_.id_c;
                void'(VerificarRuta(paquete[63],{id_r[63],id_c[63]}));
            end
     
     end
    end
    endtask

function bit VerificarRuta(bit[`ancho-1:0] paquete=0, bit [7:0] id=0);
    bit [`ancho-9:0] auxiliar;
    bit [10:0] id_aux;
    auxiliar = paquete[`ancho-9:0];
  if(this.assoc_queue.exists (auxiliar)) begin // se mira si la transaccion/paquete existe en el arreglo asociativo de colas
      id_aux = this.assoc_queue[auxiliar].pop_front(); 
      if (id == id_aux[9:2]) begin // si el id que recibe la transaccion esta en la ruta (debe ir en orden), va por buen camino 
        //`uvm_info("SCB", $sformatf("Paquete: %h, ID_Recibido: %h, ID_Esperado:%h -> Ruta Correcta",paquete,id,id_aux[9:2]), UVM_LOW);  
        if (this.assoc_queue[auxiliar].size() == 0) begin // si se vacia la cola
          `uvm_info("SCB", $sformatf("El Paquete: %h ha llegado a su destino por la ruta correcta",paquete), UVM_LOW);
          this.assoc_queue.delete(auxiliar); // se elimina el index del arreglo
        end
        return 1;
      end else begin // si no recibe en orden correcto, la transaccion no va bien y se imprime 
        `uvm_info("SCB", $sformatf("Paquete: %h, ID_Recibido: %h, ID_Esperado:%h -> Ruta Incorrecta",paquete,id,id_aux[9:2]), UVM_LOW);
       
        if (this.assoc_queue[auxiliar].size() == 0) begin // si se vacia la cola y no llega por la ruta correcta
          `uvm_info("SCB", $sformatf("El Paquete: %h ha llegado a su destino por la ruta incorrecta",paquete), UVM_LOW);
          this.assoc_queue.delete(auxiliar); // se elimina el index del arreglo
        end
        return 0;
      end
    end else begin
      `uvm_error("SCB",$sformatf("el Paquete: %h recibido en ID: %h nunca fue generado",paquete,id));
      return 0;
    end
  endfunction

endclass