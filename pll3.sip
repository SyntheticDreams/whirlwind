set_global_assignment -entity "pll3" -library "lib_pll3" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll3" -library "lib_pll3" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "pll3" -library "lib_pll3" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll3" -name SPD_FILE [file join $::quartus(sip_path) "pll3.spd"]

set_global_assignment -library "lib_pll3" -name MISC_FILE [file join $::quartus(sip_path) "pll3_sim/pll3.vo"]
