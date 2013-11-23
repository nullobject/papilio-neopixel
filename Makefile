BUILD_DIR = build
PROJECT   = neopixel
PART      = xc6slx9-2-tqg144

all: $(BUILD_DIR)/$(PROJECT).bin

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/$(PROJECT).ngc: control.vhd dual_port_async_ram.vhd ws2812.vhd $(PROJECT).vhd $(PROJECT).prj | $(BUILD_DIR)
	@cd $(BUILD_DIR); \
	echo "run -ifn ../$(PROJECT).prj -ifmt mixed -ofn $(PROJECT) -ofmt NGC -p $(PART) -top $(PROJECT) -opt_mode Speed -opt_level 1" | xst

$(BUILD_DIR)/$(PROJECT).ngd: papilio-pro.ucf $(BUILD_DIR)/$(PROJECT).ngc
	@cd $(BUILD_DIR); \
	ngdbuild -p $(PART) -uc ../papilio-pro.ucf $(PROJECT).ngc

$(BUILD_DIR)/$(PROJECT).ncd: $(BUILD_DIR)/$(PROJECT).ngd
	@cd $(BUILD_DIR); \
	map -intstyle ise -p $(PART) \
		-detail -ir off -ignore_keep_hierarchy -pr b -timing -ol high -logic_opt on \
		-w -o $(PROJECT).ncd $(PROJECT).ngd $(PROJECT).pcf

$(BUILD_DIR)/parout.ncd: $(BUILD_DIR)/$(PROJECT).ncd
	@cd $(BUILD_DIR); \
	par -w $(PROJECT).ncd parout.ncd $(PROJECT).pcf

$(BUILD_DIR)/$(PROJECT).bit: $(BUILD_DIR)/parout.ncd
	@cd $(BUILD_DIR); \
	bitgen -g CRC:Enable -g StartUpClk:CClk -g Compress -w parout.ncd $(PROJECT).bit $(PROJECT).pcf

$(BUILD_DIR)/$(PROJECT).bin: $(BUILD_DIR)/$(PROJECT).bit
	@cd $(BUILD_DIR); \
	promgen -w -spi -p bin -o ${PROJECT}.bin -s 1024 -u 0 ${PROJECT}.bit

clean:
	rm -rf $(BUILD_DIR) control.vhd

program: $(BUILD_DIR)/$(PROJECT).bit
	papilio-prog -s p -f $(BUILD_DIR)/$(PROJECT).bit
