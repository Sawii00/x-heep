vivado-fpga:
	fusesoc --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --setup --build ecocloud:biomedical_platform:top_level 2>&1 | tee buildvivado.log

vivado-fpga-nobuild:
	fusesoc --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --setup ecocloud:biomedical_platform:top_level 2>&1 | tee buildvivado.log