
module param_gen;

    class param_randomizer;

        rand int unsigned PROFUNDIDAD;

        constraint control_ { 
                        PROFUNDIDAD inside { [5:30] }; //Le pone limites a la profundidad
        }

        function void printPackage;
            int f = $fopen("parameters_pkg.sv");
            $fdisplay(f, "package params_pkg;");
            $fdisplay(f, "parameter PROFUNDIDAD = %0d;",PROFUNDIDAD);
            $fdisplay(f, "endpackage");
        endfunction
    endclass

    param_randomizer my_class; //Declara la clase para randomizar la profundidad
    initial begin
        my_class = new(); //Inicializa la clase 
        my_class.randomize(); //Randomiza el valor
        my_class.printPackage();
    end
endmodule