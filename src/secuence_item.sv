 
typedef bit [10:0] cola_de_rutas[$];

//Se declara el item que se enviara al secuenciador
class secuence_item_test_agent extends uvm_sequence_item;
  
  //Declaro las variables del ob
  
  // se definen primero los bits de contenido del paquete
  bit tipo; //Envio 1, reset 0
  bit 	 [`ancho-1:0] paquete; // paquete completo que entra al DUT

  // METADATOS
  bit 	 [7:0] nxt_jump; // 8 bits más significativos del paquete, NXT JUMP
  rand bit [3:0] row; // 4 bits para identificador de fila de destino
  rand bit [3:0] column; // 4 bits para identificador de columna de destino
  rand bit mode; // 1 bit de modo
  // MENSAJE

  rand bit [`ancho-18:0] payload; // bits restantes del paquete para payload
  bit [7:0] src; // router fuente 
  bit [7:0] id; // router destino

  // Se definen las características de envio del paquete: retardo, tiempos de envio/recibido, terminal de envio/recibido
  int retardo_max; // retardo máximo de envio de paquetes (en ciclos del reloj) 
  randc int retardo; // retardo del envio específico de un paquete
  rand int unsigned term_envio; // terminal que envía el paquete
  int unsigned term_recibido; // terminal que recibe el paquete
  int tiempo_envio; // tiempo en que se hace "push" en la FIFO de entrada
  int tiempo_recibido; // tiempo en que se hace "pop" desde la FIFO de salida incorporada en el DUT

  cola_de_rutas cola_rutas; //Cola que contiene la ruta que debe sequir la transaccion
  	
  
  constraint row_colum { // constraint para limitar el tamaño de las filas y columnas
        row >= 0; row < 6;  
        column >= 0; column < 6;
    }

  constraint c_term_envio{ // constraint para determinar por donde enviar el paquete
    term_envio < 16;
    term_envio >= 0; 
  }
  constraint const_retardo_max {  // constraint que limita el retardo aka delay
    retardo <= retardo_max;
    retardo >= 0;
  }

  constraint limites {
    {row,column} dist {  8'h01:/6,
                      8'h02:/6,
                      8'h03:/6,
                      8'h04:/6,
                      8'h10:/6,
                      8'h20:/6,
                      8'h30:/6,
                      8'h40:/6,
                      8'h51:/6,
                      8'h52:/6,
                      8'h53:/6,
                      8'h54:/6,
                      8'h15:/6,
                      8'h25:/6,
                      8'h35:/6,
                      8'h45:/6
                     };
  }

  //Registro en la fabrica con todas las variables para poder usar el print
  `uvm_object_utils_begin(secuence_item_test_agent)
    `uvm_field_int (paquete, UVM_DEFAULT)
    `uvm_field_int (nxt_jump, UVM_DEFAULT)
    `uvm_field_int (row, UVM_DEFAULT)
    `uvm_field_int (column, UVM_DEFAULT)
    `uvm_field_int (mode, UVM_DEFAULT)
    `uvm_field_int (payload, UVM_DEFAULT)
    `uvm_field_int (src, UVM_DEFAULT)
    `uvm_field_int (id, UVM_DEFAULT)
  	`uvm_field_int (retardo_max, UVM_DEFAULT)
    `uvm_field_int (retardo, UVM_DEFAULT)
    `uvm_field_int (term_envio, UVM_DEFAULT)
    `uvm_field_int (term_recibido, UVM_DEFAULT)
    `uvm_field_int (tiempo_envio, UVM_DEFAULT)
    `uvm_field_int (tiempo_recibido, UVM_DEFAULT)
    //`uvm_field_int (cola_rutas, UVM_DEFAULT)
  `uvm_object_utils_end 
  
  function new(string name = "secuence_item_test_agent");
  	super.new(name);
  endfunction
  
  //Agrego las demas funciones que actuan sobre los mismos valores 
  
  function void term_dest(); //Pasa de un id en fila y columna a un numero entero
    case({row,column})
      8'h01: this.term_recibido = 0;
      8'h02: this.term_recibido = 1;
      8'h03: this.term_recibido = 2;
      8'h04: this.term_recibido = 3;
      8'h10: this.term_recibido = 4;
      8'h20: this.term_recibido = 5;
      8'h30: this.term_recibido = 6;
      8'h40: this.term_recibido = 7;
      8'h51: this.term_recibido = 8;
      8'h52: this.term_recibido = 9;
      8'h53: this.term_recibido = 10;
      8'h54: this.term_recibido = 11;
      8'h15: this.term_recibido = 12;
      8'h25: this.term_recibido = 13;
      8'h35: this.term_recibido = 14;
      8'h45: this.term_recibido = 15;
    endcase
  endfunction

  function void term_a_enviar(int term_a_enviar); //Pasa de un numero entero de envio a un id en fila y columna
    case (term_a_enviar)
      0: begin this.row = 0; this.column = 1; end
      1: begin this.row = 0; this.column = 2; end
      2: begin this.row = 0; this.column = 3; end
      3: begin this.row = 0; this.column = 4; end
      4: begin this.row = 1; this.column = 0; end
      5: begin this.row = 2; this.column = 0; end
      6: begin this.row = 3; this.column = 0; end
      7: begin this.row = 4; this.column = 0; end
      8: begin this.row = 5; this.column = 1; end
      9: begin this.row = 5; this.column = 2; end
      10: begin this.row = 5; this.column = 3; end
      11: begin this.row = 5; this.column = 4; end
      12: begin this.row = 1; this.column = 5; end
      13: begin this.row = 2; this.column = 5; end
      14: begin this.row = 3; this.column = 5; end
      15: begin this.row = 4; this.column = 5; end
    endcase
  endfunction


  function void GetSrcAndId();
    case (term_envio)   //Se obienen el id fuente y del router que enviara el dato dependiendo de la terminal de envio
      0: begin this.src = 8'h01;  this.id = 8'h11; end
      1: begin this.src = 8'h02;  this.id = 8'h12; end
      2: begin this.src = 8'h03;  this.id = 8'h13; end
      3: begin this.src = 8'h04;  this.id = 8'h14; end
      4: begin this.src = 8'h10;  this.id = 8'h11; end
      5: begin this.src = 8'h20;  this.id = 8'h21; end
      6: begin this.src = 8'h30;  this.id = 8'h31; end
      7: begin this.src = 8'h40;  this.id = 8'h41; end
      8: begin this.src = 8'h51;  this.id = 8'h41; end
      9: begin this.src  = 8'h52;  this.id = 8'h42; end
      10: begin this.src  = 8'h53;  this.id = 8'h43; end
      11: begin this.src  = 8'h54;  this.id = 8'h44; end
      12: begin this.src  = 8'h15;  this.id = 8'h14; end
      13: begin this.src  = 8'h25;  this.id = 8'h24; end
      14: begin this.src  = 8'h35;  this.id = 8'h34; end
      15: begin this.src  = 8'h45;  this.id = 8'h44; end
    endcase
  endfunction

  function void BuildPackage(); // funcion para concatenar el paquete
    this.paquete = {this.nxt_jump,this.row,this.column,this.mode,this.payload};
  endfunction

  function void UnPackage();//Deshace el paquete
    this.nxt_jump = this.paquete[`ancho-1:`ancho-8];
    this.row = this.paquete[`ancho-9:`ancho-12];
    this.column = this.paquete[`ancho-13:`ancho-16];
    this.mode = this.paquete[`ancho-17];
    this.payload = this.paquete[`ancho-18:0];
  endfunction
  
endclass


class secuence_test_agent extends uvm_sequence;
  int num_transacciones = 15; 		 //Valores establecidos por default
  int retardo_max = 10;					 //Retardo maximo pord defecto de 10 ciclos de reloj 
  int trans_x_terminal = `profundidad;//Transacciones por terminal por defecto igua a la profundidad de la fifos
  
  
  //Para el caso especifico
  int retardo_espec;				//Retardo especifico
  bit [3:0] row_espec;				//Fila especifica
  bit [3:0] column_espec;			//Columna epecifica
  bit mode_espec;					//Modo especifico
  bit [`ancho - 17:0] pyld_espec;	//Payload especifico
  int term_envio_espec; 			//terminal desde la que se envia el paquete especifico
  
  `uvm_object_utils_begin(secuence_test_agent);
    `uvm_field_int (num_transacciones, UVM_DEFAULT )
    `uvm_field_int (retardo_max , UVM_DEFAULT )
    `uvm_field_int (trans_x_terminal, UVM_DEFAULT )
    `uvm_field_int (retardo_espec, UVM_DEFAULT )
    `uvm_field_int (row_espec, UVM_DEFAULT )
    `uvm_field_int (column_espec, UVM_DEFAULT )
    `uvm_field_int (mode_espec, UVM_DEFAULT )
    `uvm_field_int (pyld_espec, UVM_DEFAULT )
    `uvm_field_int (term_envio_espec, UVM_DEFAULT )
  `uvm_object_utils_end
  
  function new(string name="secuence_test_agent");
    super.new(name);
  endfunction
  
  virtual task body();
    //Transaccion aleatoria (Se hacen las transacciones dependiendo del numero de transacciones seteado)
    begin
      secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item");
      start_item(m_item);
      m_item.tipo = 1;
      m_item.retardo_max = retardo_max;
      m_item.term_envio = term_envio_espec;
      m_item.randomize();
      m_item.GetSrcAndId();
      m_item.BuildPackage();
      m_item.term_dest();
      //`uvm_info("SEQUENCER", "Transaccion aleatoria creada", UVM_LOW);
      //m_item.print(); //Hora de probarlo 
      finish_item(m_item);
    end 
    
    #200
    //Transaccion especifica
    begin
      secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item");
      start_item(m_item);
      m_item.tipo = 1;
      m_item.retardo = retardo_espec;
      m_item.row = row_espec;
      m_item.column = column_espec;
      m_item.mode = mode_espec;
      m_item.payload = pyld_espec;
      m_item.term_envio = term_envio_espec;
      m_item.GetSrcAndId();
      m_item.BuildPackage();
      m_item.term_dest();
      //`uvm_info("SEQUENCER", "Transaccion especifica creada", UVM_LOW);
      //m_item.print(); //Hora de probarlo 
      finish_item(m_item);
    end 
    
    #200
    //Seccion de transacciones aleatorias
    
    for(int i = 0; i < num_transacciones; i++) begin
      secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      start_item(m_item);//Inicio del item 
      m_item.tipo = 1;
      m_item.retardo_max = retardo_max; //Establece el retardo maximo
      m_item.randomize(); //Randomiza las variables de la transaccion
      m_item.GetSrcAndId(); //Genera el id source y del router desde donde se enviara el paquete 
      m_item.BuildPackage(); //Une el paquete 
      m_item.term_dest(); //Genera la terminal de destino
     // m_item.print();
      finish_item(m_item);
     
    end
    //`uvm_info("SEQUENCER", "Transacciones aleatorias creadas", UVM_LOW);
    
    
    #200
    //Transacciones aleatorias por terminal 
    for (int i = 0; i < (`filas*2+`columnas*2) ; i++) begin // i = indice de terminal					     
      for (int j = 0; j < trans_x_terminal; j++) begin// j = indice de cantidad de transacciones por terminal
        
        secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      	start_item(m_item);//Inicio del item 
        m_item.tipo = 1;
        m_item.retardo_max = retardo_max; //Le pone el retardo maximo
        m_item.randomize(); //Randomiza los valores de la transaccion
        m_item.term_envio = i; //Le indida desde cual terminal enviar el paquete 
        m_item.GetSrcAndId(); //Genera el id source y de router que enviara el dato
        m_item.BuildPackage(); //Une el paquete
        m_item.term_dest(); //Obtiene la terminal de destino
        //m_item.print();
        finish_item(m_item);
        
      end
    end
    
    //`uvm_info("SEQUENCER", "Transacciones aleatorias por terminal creadas", UVM_LOW);
    
    
    #200
    //Todas a todas
    
    for (int i = 0; i < (`filas*2+`columnas*2); i=i+1) begin // i = índice de terminal que envia
      for (int j = 0; j < 1; j=j+1) begin // j = índice de cantidad de transacciones por terminal
        for (int k = 0; k < 16; k++ ) begin // k = índice del terminal al que se le va a enviar
          secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      	  start_item(m_item);//Inicion del item 
          m_item.tipo = 1;
         
          m_item.mode = $random; //Modo aleatorio
          m_item.payload = $urandom; //Payload aleatorio que no se puede repetir
          m_item.retardo = $urandom_range(0,retardo_max); //Retardo aleatorio en un rango especifico
          m_item.term_a_enviar(k); //Se le indica a que terminal enviara el dato
          m_item.term_envio = i; //Se le indica desde donde se enviara el dato
          m_item.GetSrcAndId(); //Se genera el id source y de router que enviara el dato
          m_item.BuildPackage(); //Une el paquete
          m_item.term_dest(); //Guarda el valor de la terminal de destino
          
          //m_item.print();
          finish_item(m_item);
          
        end
      end
    end
    
   // `uvm_info("SEQUENCER", "Transacciones de todas a todas creadas", UVM_LOW);
    
    
    #200
    //Todas a todas modo especifico
    
    for (int i = 0; i < (`filas*2+`columnas*2); i=i+1) begin // i = índice de terminal que envia
      for (int j = 0; j < 1; j=j+1) begin // j = índice de cantidad de transacciones por terminal
        for (int k = 0; k < 16; k++ ) begin // k = índice del terminal al que se le va a enviar

          secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      	  start_item(m_item);//Inicion del item 
          m_item.tipo = 1;
          m_item.mode = mode_espec; //Se establece el modo especifico
          m_item.payload = $urandom; //Payload aleatorio sin repetir
          m_item.retardo = $urandom_range(0,retardo_max); //Retardo aleatorio en un rango determinado
          m_item.term_a_enviar(k); //Terminal a la que se enviara el dato
          m_item.term_envio = i; //Terminal desde donde se enviara
          m_item.GetSrcAndId(); //Se obtien el id del source y el router que enviara el dato
          m_item.BuildPackage(); //Une el paquete 
          m_item.term_dest(); //Obtiene la terminal de destino
          
          //m_item.print();
          finish_item(m_item);
          
        end
      end
    end
    
    //`uvm_info("SEQUENCER", "Transacciones de todas a todas modo especifico creadas", UVM_LOW);
    
    
    
    #200
    //Una a todas 
    
    for (int i = 0; i < (`filas*2+`columnas*2); i=i+1) begin // i = índice de terminal
      for (int j = 0; j < 1; j=j+1) begin // j = índice de cantidad de transacciones por terminal

        secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      	start_item(m_item);//Inicion del item 
        m_item.tipo = 1;
        m_item.mode = $random; //Modo aleatorio
        m_item.payload = $urandom; //Payload aleatorio sin repetir
        m_item.retardo = $urandom_range(0,retardo_max); // Retardo aleatorio en un rango determinado
        m_item.term_a_enviar(i); //se le indica la termial a la que se le enviara el dato
        m_item.term_envio = term_envio_espec; //se indica especificamente desde donde se enviara
        m_item.GetSrcAndId(); //Se obtiene el id source y del router desde donde se enviara el dato
        m_item.BuildPackage(); //Une el paquete 
        m_item.term_dest(); //Determina el destino del paquete.
       
        //m_item.print();
        finish_item(m_item);
        
      end
    end
    
    //`uvm_info("SEQUENCER", "Transacciones de todas a todas creadas", UVM_LOW);
    
    
    #200
    //Llenas fifos
    
    for (int i = 0; i < 16 ; i++) begin // i = indice de terminal
      for (int j = 0; j < `profundidad; j++) begin// j = indice de cantidad de transacciones por terminal
        secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
      	start_item(m_item);//Inicion del item 
        m_item.tipo = 1;
        m_item.retardo_max = 0; //Retardo 0
        m_item.randomize(); //Randomiza el paquete
        m_item.term_envio = i; //Terminal la cual se va a llenar 
        m_item.GetSrcAndId(); //Se obtiene el id source y del router que enviara el dato
        m_item.BuildPackage(); //Se une el paquete
        m_item.term_dest(); //Se obtiene el id de destino
        
        //m_item.print();
        finish_item(m_item);
        
      end
    end
    
    //`uvm_info("SEQUENCER", "Transacciones de todas a todas creadas", UVM_LOW);
  endtask
  
endclass

  
  
  
  
  
  