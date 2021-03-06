#include <amxmodx>
#include <reapi>

#define MAXJUMPS	2			// maximum jumps


new const PLUGIN[] = "Multijump"
new const VERSION[] = "1.0"
new const AUTHOR[] = "serfreeman1337"	// Reapi modification by mforce


enum _:jdata {
	bool:DOJUMP,
	JUMPCOUNT
}

new player_jumps[33][jdata]

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	RegisterHookChain(RG_CBasePlayer_Jump, "Hook_PlayerJump", false);
}

public Hook_PlayerJump(id) {
	static bitFlags; bitFlags =  get_entvar(id, var_flags)
	
	if(~bitFlags & FL_ONGROUND && ~get_entvar(id, var_oldbuttons) & IN_JUMP) {
		if(player_jumps[id][JUMPCOUNT] < MAXJUMPS - 1) {
			player_jumps[id][DOJUMP] = true
			player_jumps[id][JUMPCOUNT] ++
		}
	}
	else if(bitFlags & FL_ONGROUND) {
		player_jumps[id][JUMPCOUNT] = 0
	}
	
	if(player_jumps[id][DOJUMP]) {
		static Float:velocity[3]
		get_entvar(id, var_velocity, velocity)
		velocity[2] = random_float(265.0,285.0)
		set_entvar(id, var_velocity, velocity)
		
		player_jumps[id][DOJUMP] = false
	}
}

public client_disconnect(id) {
	arrayset(player_jumps[id], 0, jdata)
}
