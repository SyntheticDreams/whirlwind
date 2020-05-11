set_global_assignment -entity "pll0" -library "lib_pll0" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll0" -library "lib_pll0" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "pll0" -library "lib_pll0" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll0" -name SPD_FILE [file join $::quartus(sip_path) "pll0.spd"]

set_global_assignment -library "lib_pll0" -name MISC_FILE [file join $::quartus(sip_path) "pll0_sim/pll0.vo"]
