typedef enum {trans_aleatoria, trans_especifica, brdcst, sec_trans_aleatorias, trans_aleat_x_terminal, todas_a_todas, una_a_todas, llenar_fifos,todas_a_todas_mode_esp} instruccion_test; //Tipo de instruccion que se envia al secuenciador, el secuenciador ya prepara las secuencias.

typedef bit [10:0] cola_de_rutas[$];

//Se declara el item que se enviara al secuenciador
class secuence_item_test_agent #(parameter ancho = 40) extends uvm_secuence_item;
  
  //Declaro las variables del objeto
  
  // se definen primero los bits de contenido del paquete
  bit 	 [ancho-1:0] paquete; // paquete completo que entra al DUT

  // METADATOS
  bit 	 [7:0] nxt_jump; // 8 bits más significativos del paquete, NXT JUMP
  rand bit [3:0] row; // 4 bits para identificador de fila de destino
  rand bit [3:0] colum; // 4 bits para identificador de columna de destino
  rand bit mode; // 1 bit de modo

  // MENSAJE
  rand bit [ancho-18:0] payload; // bits restantes del paquete para payload
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
        colum >= 0; colum < 6;
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
    {row,colum} dist {  8'h01:/6,
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
  `uvm_object_utils_begin(secuence_test_agent)
    `uvm_field_int (paquete, UVM_DEFAULT)
    `uvm_field_int (nxt_jump, UVM_DEFAULT)
    `uvm_field_int (row, UVM_DEFAULT)
    `uvm_field_int (column, UVM_DEFAULT)
    `uvm_field_int (mode, UVM_DEFAULT)
    `uvm_field_int (payload, UVM_DEFAULT)
    `uvm_field_int (src, UVM_DEFAULT)
    `uvm_field_int (id, UVM_DEFAULT)
    `uvm_field_int (retado_max, UVM_DEFAULT)
    `uvm_field_int (retardo, UVM_DEFAULT)
    `uvm_field_int (term_envio, UVM_DEFAULT)
    `uvm_field_int (term_recibido, UVM_DEFAULT)
    `uvm_field_int (tiempo_envio, UVM_DEFAULT)
    `uvm_field_int (tiempo_recibido, UVM_DEFAULT)
    `uvm_field_int (cola_rutas, UVM_DEFAULT)
  `uvm_object_utils_end 
  
  function new(string name = "secuence_item_test_agent");
  	super.new(name);
  endfunction
  
  //Agrego las demas funciones que actuan sobre los mismos valores 
  
  function void term_dest(); //Pasa de un id en fila y columna a un numero entero
    case({row,colum})
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
      0: begin this.row = 0; this.colum = 1; end
      1: begin this.row = 0; this.colum = 2; end
      2: begin this.row = 0; this.colum = 3; end
      3: begin this.row = 0; this.colum = 4; end
      4: begin this.row = 1; this.colum = 0; end
      5: begin this.row = 2; this.colum = 0; end
      6: begin this.row = 3; this.colum = 0; end
      7: begin this.row = 4; this.colum = 0; end
      8: begin this.row = 5; this.colum = 1; end
      9: begin this.row = 5; this.colum = 2; end
      10: begin this.row = 5; this.colum = 3; end
      11: begin this.row = 5; this.colum = 4; end
      12: begin this.row = 1; this.colum = 5; end
      13: begin this.row = 2; this.colum = 5; end
      14: begin this.row = 3; this.colum = 5; end
      15: begin this.row = 4; this.colum = 5; end
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
    this.paquete = {this.nxt_jump,this.row,this.colum,this.mode,this.payload};
  endfunction

  function void UnPackage();//Deshace el paquete
    this.nxt_jump = this.paquete[ancho-1:ancho-8];
    this.row = this.paquete[ancho-9:ancho-12];
    this.colum = this.paquete[ancho-13:ancho-16];
    this.mode = this.paquete[ancho-17];
    this.payload = this.paquete[ancho-18:0];
  endfunction
  
endclass


class secuence_test_agent #(parameter filas = 4; parameter columnas = 4, parameter ancho = 40, parameter profundidad = 4, parameter broadcast ={8{1'b1}}) extends uvm_secuence;
  int num_trasacciones = 15; 		 //Valores establecidos por default
  int retardo = 10;					 //Retardo maximo pord defecto de 10 ciclos de reloj 
  int trans_x_terminal = profundidad;//Transacciones por terminal por defecto igua a la profundidad de la fifos
  
  
  //Para el caso especifico
  int retardo_espec;				//Retardo especifico
  bit [3:0] row_espec;				//Fila especifica
  bit [3:0] column_espec;			//Columna epecifica
  bit mode_espec;					//Modo especifico
  bit [ancho - 17:0] pyld_espec;	//Payload especifico
  int term_envio_espec; 			//terminal desde la que se envia el paquete especifico
  
  `uvm_object_utils_begin(secuence_test_agent);
    `uvm_field_int (num_transacciones, UVM_DEFAULT )
    `uvm_field_int (retardo, UVM_DEFAULT )
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
    secuence_item_test_agent m_item = secuence_item_test_agent::type_id::create("m_item");
    start_item(m_item);
    m_item.randomize();
    m_item.retardo_max = retardo_max;
    m_item.term_envio = term_envio_espec;
    m_item.GetSrcAndId();
    m_item.BuildPackage();
    m_item.term_dest();
    m_item.print(); //Hora de probarlo 
    finish_item(m_item);
  endtask
  
endclass

  
  
  
  
  
  