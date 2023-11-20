source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools.sh;

max=30
for (( i=0; i <= $max; ++i ))
do
    vcs -Mupdate module_params.sv -o salida_params -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert;

    ./salida_params +ntb_random_seed_automatic; # esta salida genera un nuevo archivo llamado "parameters_pkg.sv", este package se ingresa en el Testbench

    vcs -Mupdate tb_dut.sv -o salida -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert -ntb_opts uvm-1.2 -timescale=1ns/1ns;

    ./salida -cm line+tgl+cond+fsm+branch+assert;

done