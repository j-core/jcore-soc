
define include_vhdl_var
 LOCAL_TEMP_VAR :=
 VHDLS := LOCAL_TEMP_VAR
 include $(1)/build.mk
 LOCAL_TEMP_VAR := $$(addprefix $(1)/,$$(LOCAL_TEMP_VAR))
endef

define include_vhdl
 $(eval $(call include_vhdl_var,$(1))) $(LOCAL_TEMP_VAR)
endef
