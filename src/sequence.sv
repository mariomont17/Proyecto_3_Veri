typedef enum {trans_especifica, trans_aleat_x_terminal, una_a_todas_mode_esp, todas_a_todas_mode_esp} instruccion_seq;

class secuence_test_agent extends uvm_sequence;
    
    int num_transacciones = 15; 		      //Valores establecidos por default
    int retardo_max = 10;					 //Retardo maximo pord defecto de 10 ciclos de reloj 
    int trans_x_terminal = `profundidad;    //Transacciones por terminal por defecto igua a la profundidad de la fifos
    
    
    //Para el caso especifico
    int retardo_espec;				//Retardo especifico
    bit [3:0] row_espec;			//Fila especifica
    bit [3:0] column_espec;			//Columna epecifica
    bit mode_espec;					//Modo especifico
    bit [`ancho - 17:0] pyld_espec;	//Payload especifico
    int term_envio_espec; 			//terminal desde la que se envia el paquete especifico
    instruccion_seq instruccion; 
    
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
        
        secuence_item_test_agent m_item;
        
        
        case (instruccion) 
            trans_especifica: begin
                m_item = secuence_item_test_agent::type_id::create("m_item");
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
                m_item.cola_rutas = m_item.ObtenerRuta(m_item.paquete, m_item.id);
               // `uvm_info("SEQ", "Transaccion especifica creada", UVM_LOW);
                //m_item.print(); //Hora de probarlo 
                finish_item(m_item);
            end
            trans_aleat_x_terminal: begin
                for (int i = 0; i < 16 ; i++) begin // i = indice de terminal					     
                    for (int j = 0; j < trans_x_terminal; j++) begin// j = indice de cantidad de transacciones por terminal
                        
                        m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
                        start_item(m_item);//Inicio del item 
                        m_item.tipo = 1;
                        m_item.retardo_max = retardo_max; //Le pone el retardo maximo
                        m_item.randomize(); //Randomiza los valores de la transaccion
                        m_item.term_envio = i; //Le indida desde cual terminal enviar el paquete 
                        m_item.GetSrcAndId(); //Genera el id source y de router que enviara el dato
                        m_item.BuildPackage(); //Une el paquete
                        m_item.term_dest(); //Obtiene la terminal de destino
                        m_item.cola_rutas = m_item.ObtenerRuta(m_item.paquete, m_item.id);
                        //m_item.print();
                        finish_item(m_item);
                        
                    end
                end
            end
            todas_a_todas_mode_esp: begin
                for (int i = 0; i < (`filas*2+`columnas*2); i=i+1) begin // i = índice de terminal que envia
                    for (int j = 0; j < 1; j=j+1) begin // j = índice de cantidad de transacciones por terminal
                        for (int k = 0; k < 16; k++ ) begin // k = índice del terminal al que se le va a enviar

                        m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
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
                        m_item.cola_rutas = m_item.ObtenerRuta(m_item.paquete, m_item.id);
                        //m_item.print();
                        finish_item(m_item);
                        
                        end
                    end
                end
            end
            una_a_todas_mode_esp: begin
                for (int i = 0; i < (`filas*2+`columnas*2); i=i+1) begin // i = índice de terminal
                    for (int j = 0; j < 1; j=j+1) begin // j = índice de cantidad de transacciones por terminal

                        m_item = secuence_item_test_agent::type_id::create("m_item"); //Crea la transaccion
                        start_item(m_item);//Inicion del item 
                        m_item.tipo = 1;
                        m_item.mode = mode_espec; //Modo aleatorio
                        m_item.payload = $urandom; //Payload aleatorio sin repetir
                        m_item.retardo = $urandom_range(0,retardo_max); // Retardo aleatorio en un rango determinado
                        m_item.term_a_enviar(i); //se le indica la termial a la que se le enviara el dato
                        m_item.term_envio = term_envio_espec; //se indica especificamente desde donde se enviara
                        m_item.GetSrcAndId(); //Se obtiene el id source y del router desde donde se enviara el dato
                        m_item.BuildPackage(); //Une el paquete 
                        m_item.term_dest(); //Determina el destino del paquete.
                        m_item.cola_rutas = m_item.ObtenerRuta(m_item.paquete, m_item.id);
                        //m_item.print();
                        finish_item(m_item);
                        
                    end
                end 
            end
            default: begin
                `uvm_fatal("SEQ", "Instruccion inválida")
                $finish;
            end
        endcase


        
        

  endtask
  
endclass