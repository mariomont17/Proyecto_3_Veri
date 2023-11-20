source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools.sh;

# Para variar la profundidad de las FIFOS se debe ingresa dicha cantidad desde la consola de linux
 
# Sin embargo, La prueba del DUT se corre siempre con la misma semilla (default)

read -p "Ingrese la profundidad de las FIFOs del DUT y del driver (entero entre 0 y 30): " profundidad

printf "package params_pkg;\n" > parameters_pkg.sv
printf "  parameter PROFUNDIDAD = %d;\n" $profundidad >> parameters_pkg.sv
printf "endpackage" >> parameters_pkg.sv

vcs -Mupdate tb_dut.sv -o salida -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert -ntb_opts uvm-1.2 -timescale=1ns/1ns;

./salida -cm line+tgl+cond+fsm+branch+assert;