vlib work
vlog tb_interrupt_controller.v
vsim tb +testname=random_priority
add wave sim:/tb/u0/*
#add wave sim:/tb/*
run -all
