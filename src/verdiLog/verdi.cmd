simSetSimulator "-vcssv" -exec "./salida" -args " " -uvmDebug on
debImport "-i" "-simflow" "-dbdir" "./salida.daidir"
srcTBInvokeSim
srcHBSelect "tb.DUT" -win $_nTrace1
wvCreateWindow
srcHBAddObjectToWave -clipboard
wvDrop -win $_nWave3
srcTBRunSim
verdiDockWidgetMaximize -dock windowDock_nWave_3
wvSetCursor -win $_nWave3 74666.949272 -snap {("DUT" 6)}
wvSetCursor -win $_nWave3 74517.264768 -snap {("G2" 0)}
wvZoom -win $_nWave3 74755.331035 74930.893417
wvSetCursor -win $_nWave3 74870.172593 -snap {("DUT" 2)}
wvSetCursor -win $_nWave3 74755.331035 -snap {("DUT" 1)}
verdiDockWidgetRestore -dock windowDock_nWave_3
srcDeselectAll -win $_nTrace1
wvSelectSignal -win $_nWave3 {( "DUT" 5 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 5 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 3 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectGroup -win $_nWave3 {G2}
wvSetCursor -win $_nWave3 74772.947197 -snap {("G2" 0)}
wvSelectGroup -win $_nWave3 {DUT}
wvSelectSignal -win $_nWave3 {( "DUT" 1 )} 
verdiDockWidgetMaximize -dock windowDock_nWave_3
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSetPosition -win $_nWave3 {("DUT" 2)}
wvExpandBus -win $_nWave3
wvSetPosition -win $_nWave3 {("DUT" 24)}
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSelectSignal -win $_nWave3 {( "DUT" 2 )} 
wvSetPosition -win $_nWave3 {("DUT" 2)}
wvCollapseBus -win $_nWave3
wvSetPosition -win $_nWave3 {("DUT" 2)}
wvSetPosition -win $_nWave3 {("DUT" 8)}
wvSelectSignal -win $_nWave3 {( "DUT" 1 )} 
wvSetPosition -win $_nWave3 {("DUT" 1)}
wvExpandBus -win $_nWave3
wvSetPosition -win $_nWave3 {("DUT" 24)}
wvZoomOut -win $_nWave3
wvZoomOut -win $_nWave3
wvZoomOut -win $_nWave3
wvZoomOut -win $_nWave3
wvZoomOut -win $_nWave3
wvSetCursor -win $_nWave3 73974.606630 -snap {("G2" 0)}
wvSetCursor -win $_nWave3 74072.197181 -snap {("DUT" 16)}
wvSetCursor -win $_nWave3 42807.578163 -snap {("DUT" 12)}
wvZoomAll -win $_nWave3
debExit
