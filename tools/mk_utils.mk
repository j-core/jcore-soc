
define include_vhdl_var
 LOCAL_TEMP_VAR :=
 VHDLS := LOCAL_TEMP_VAR
 include $(1)/build.mk
 LOCAL_TEMP_VAR := $$(addprefix $(1)/,$$(LOCAL_TEMP_VAR))
endef

define include_vhdl
 $(eval $(call include_vhdl_var,$(1))) $(LOCAL_TEMP_VAR)
endef

# try to include build_sim.mk if it exists, otherwise include build.mk
define include_sim_vhdl_var
 LOCAL_TEMP_VAR :=
 VHDLS := LOCAL_TEMP_VAR
 include $(firstword $(wildcard $(1)/build_sim.mk) $(wildcard $(1)/build.mk))
 LOCAL_TEMP_VAR := $$(addprefix $(1)/,$$(LOCAL_TEMP_VAR))
endef

define include_sim_vhdl
 $(eval $(call include_sim_vhdl_var,$(1))) $(LOCAL_TEMP_VAR)
endef

# try to include build_fpga.mk if it exists, otherwise include build.mk
define include_fpga_vhdl_var
 LOCAL_TEMP_VAR :=
 VHDLS := LOCAL_TEMP_VAR
 include $(firstword $(wildcard $(1)/build_fpga.mk) $(wildcard $(1)/build.mk))
 LOCAL_TEMP_VAR := $$(addprefix $(1)/,$$(LOCAL_TEMP_VAR))
endef

define include_fpga_vhdl
 $(eval $(call include_fpga_vhdl_var,$(1))) $(LOCAL_TEMP_VAR)
endef

# try to include build_asic.mk if it exists, otherwise include build.mk
define include_asic_vhdl_var
 LOCAL_TEMP_VAR :=
 VHDLS := LOCAL_TEMP_VAR
 include $(firstword $(wildcard $(1)/build_asic.mk) $(wildcard $(1)/build.mk))
 LOCAL_TEMP_VAR := $$(addprefix $(1)/,$$(LOCAL_TEMP_VAR))
endef

define include_asic_vhdl
 $(eval $(call include_asic_vhdl_var,$(1))) $(LOCAL_TEMP_VAR)
endef
