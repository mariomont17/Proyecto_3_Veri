source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools.sh;


vcs -Mupdate tb_dut.sv -o salida -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert -ntb_opts uvm-1.2 -timescale=1ns/1ns;

./salida -cm line+tgl+cond+fsm+branch+assert;