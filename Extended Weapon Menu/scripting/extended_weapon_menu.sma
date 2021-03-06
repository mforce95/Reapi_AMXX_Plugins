/*
		Extended Weapon Menu
			v1.4 by mforce
	
	Changes:
	
	v1.1 - Multilang added, strip_user_weapons fixed, "hardcoded" things fixed,
	unnecessary cvar removed, using Safety1st method for money block, ColorChat included.
	
	v1.2 - AMXX 1.8.3 support fixed, minimal improvements (less cvar hook)
	v1.21 - Multilang fix.
	v1.3 - Plugin pause removed. Added files for modify weapon menu items.
	v1.4 - Added give and drop by Safety1st, menu builds by Vaqtincha's plugin.
*/


#include <amxmodx>
#include <reapi>

new const PLUGIN[] = "[ReApi] Extended Weapon Menu";
new const VERSION[] = "1.4";
new const AUTHOR[] = "mforce";


new const PREFIX[] = "^4[EWM]";

#if AMXX_VERSION_NUM < 183
#include <colorchat>
const MAX_PLAYERS = 32;
#endif
const HUD_HIDE_MONEY = 1<<5;

new Array:g_Primary_MenuItems, Array:g_Secondary_MenuItems;
new g_iPrim_TotalItems, g_iSec_TotalItems;
new g_iPrim_EquipMenuID, g_iSec_EquipMenuID;
enum _:weapinfo {weap_name[32], bpammo};
enum _:PCVARS {AwpMinPlayers, MaxAwps, PistolMenu, MaxHeg, MaxFlash, MaxSmoke}
enum _:TEAMS {TE, CT};
enum _:MAXGRENADES {HE, FLASH, SMOKE};
enum _:AWPCVARS {MinPlayers, MaxAwp};
new g_Cvars[PCVARS], bool:g_AllowAWP, g_Awps[TEAMS], bool:g_Used[MAX_PLAYERS+1], g_Grenades[MAXGRENADES], g_AWPCvarHook[AWPCVARS];


new const g_szWeaponNames[CSW_P90+1][] = {
	"","weapon_p228","weapon_shield","weapon_scout","weapon_hegrenade","weapon_xm1014","weapon_c4",
	"weapon_mac10","weapon_aug","weapon_smokegrenade","weapon_elite","weapon_fiveseven","weapon_ump45",
	"weapon_sg550","weapon_galil","weapon_famas","weapon_usp","weapon_glock18","weapon_awp",
	"weapon_mp5navy","weapon_m249","weapon_m3","weapon_m4a1","weapon_tmp","weapon_g3sg1",
	"weapon_flashbang","weapon_deagle","weapon_sg552","weapon_ak47","weapon_knife","weapon_p90"
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_dictionary("extended_weapon_menu.txt");
	g_Cvars[AwpMinPlayers] = register_cvar("ewm_awpminplayers", "4")
	g_Cvars[MaxAwps] = register_cvar("ewm_maxawp", "3")
	g_Cvars[PistolMenu] = register_cvar("ewm_pistolmenu", "0")
	g_Cvars[MaxHeg] = register_cvar("ewm_maxheg", "1")
	g_Cvars[MaxFlash] = register_cvar("ewm_maxflash", "2")
	g_Cvars[MaxSmoke] = register_cvar("ewm_maxsmoke", "1")
	RegisterHookChain(RG_CBasePlayer_Spawn, "weapmenu", true);
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	new const commands[][] = {"say /gun", "say /guns", "say /weap", "say_team /gun", "say_team /guns", "say_team /weap"};
	for(new i; i < sizeof(commands); i++) {
		register_clcmd(commands[i], "weapmenu");
	}
	
	register_event("ResetHUD", "Event_ResetHUD", "b")
	register_event("HideWeapon", "Event_HideWeapon", "b")
	set_msg_block(get_user_msgid("Money"), BLOCK_SET)
	set_member_game(m_bCTCantBuy, true)
	set_member_game(m_bTCantBuy, true)
	
	g_Primary_MenuItems = ArrayCreate(weapinfo);
	g_Secondary_MenuItems = ArrayCreate(weapinfo);
}

public plugin_cfg() {
	new sBuffer[256], sFile[128], sData[2][32], pFile; 
	get_localinfo("amxx_configsdir", sFile, charsmax(sFile));
	add(sFile, charsmax(sFile), "/ewm_weapons.ini");
 
	pFile = fopen(sFile, "rt");
	if(!pFile) set_fail_state("Error reading weapon menu items config file.");
	
	new Trie:tCheckWeaponName = TrieCreate();
	new Trie:tCheckAddedItems = TrieCreate()
	
	for(new i = 0; i< sizeof(g_szWeaponNames); i++)
		TrieSetCell(tCheckWeaponName, g_szWeaponNames[i], 1);
	
	new bSection, menudata[weapinfo];
	
	while(!feof(pFile)) {
		fgets(pFile, sBuffer, charsmax(sBuffer)); trim(sBuffer);
		if(!sBuffer[0] || sBuffer[0] == ';' || sBuffer[0] == '#') continue;
		
		if(sBuffer[0] == '[') {
			if(equali(sBuffer, "[weapons]")) bSection = 1;
			else if(equali(sBuffer, "[pistols]")) bSection = 2;
			else bSection = 0;
			
			continue;
		}

		if(parse(sBuffer, sData[0], charsmax(sData[]), sData[1], charsmax(sData[]))) {
			format(sData[0], charsmax(sData[]), "weapon_%s", sData[0]);
			strtolower(sData[0]);
			
			if(!sData[0][0] || !TrieKeyExists(tCheckWeaponName, sData[0])) {
				server_print("WARNING: Invalid weapon name ^"%s^" will be skipped!", sData[0]);
				continue;
			}
			if(TrieKeyExists(tCheckAddedItems, sData[0])) {
				server_print("WARNING: Item ^"%s^" is already added!", sData[0]);
				continue;
			}
			
			copy(menudata[weap_name], charsmax(menudata[weap_name]), sData[0]);
			menudata[bpammo] = str_to_num(sData[1]);
			TrieSetCell(tCheckAddedItems, sData[0], 1);
			
			if(bSection == 1) {
				ArrayPushArray(g_Primary_MenuItems, menudata);
				g_iPrim_TotalItems++
			}
			else if(bSection == 2) {
				ArrayPushArray(g_Secondary_MenuItems, menudata);
				g_iSec_TotalItems++
			}
		}
	}
	
	fclose(pFile);
	TrieDestroy(tCheckWeaponName);
	TrieDestroy(tCheckAddedItems);
	
	if(!g_iPrim_TotalItems || !g_iSec_TotalItems) set_fail_state("Error! The menu doesn't contain any weapons.");
	
	build_menu();
}

build_menu() {
	g_iPrim_EquipMenuID = menu_create(PLUGIN, "Prim_WeaponMenuHandler")
	g_iSec_EquipMenuID = menu_create(PLUGIN, "Sec_WeaponMenuHandler")
	// menu_setprop(g_iPrim_EquipMenuID, MPROP_NUMBER_COLOR, "\r")

	new szMenuText[64], menudata[weapinfo], szNum[3], i;
	
	for(i = 0; i < g_iPrim_TotalItems; i++) {
		ArrayGetArray(g_Primary_MenuItems, i, menudata)
		strtoupper(menudata[weap_name]);
		formatex(szMenuText, charsmax(szMenuText), "%s", menudata[weap_name][7]);
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(g_iPrim_EquipMenuID, szMenuText, szNum, 0)
	}
	
	for(i = 0; i < g_iSec_TotalItems; i++) {
		ArrayGetArray(g_Secondary_MenuItems, i, menudata)
		strtoupper(menudata[weap_name]);
		formatex(szMenuText, charsmax(szMenuText), "%s", menudata[weap_name][7]);
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(g_iSec_EquipMenuID, szMenuText, szNum, 0)
	}
	
	menu_setprop(g_iPrim_EquipMenuID, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(g_iSec_EquipMenuID, MPROP_EXIT, MEXIT_ALL);
	formatex(szMenuText, charsmax(szMenuText), "%L", LANG_SERVER, "EWM_MENU_BACK");
	menu_setprop(g_iPrim_EquipMenuID, MPROP_BACKNAME, szMenuText);
	menu_setprop(g_iSec_EquipMenuID, MPROP_BACKNAME, szMenuText);
	formatex(szMenuText, charsmax(szMenuText), "%L", LANG_SERVER, "EWM_MENU_NEXT");
	menu_setprop(g_iPrim_EquipMenuID, MPROP_NEXTNAME, szMenuText);
	menu_setprop(g_iSec_EquipMenuID, MPROP_NEXTNAME, szMenuText);
	formatex(szMenuText, charsmax(szMenuText), "%L", LANG_SERVER, "EWM_MENU_EXIT");
	menu_setprop(g_iPrim_EquipMenuID, MPROP_EXITNAME, szMenuText);
	menu_setprop(g_iSec_EquipMenuID, MPROP_EXITNAME, szMenuText);
}

public Prim_WeaponMenuHandler(id, iMenu, iItem) {
	if(iItem == MENU_EXIT) return PLUGIN_HANDLED;

	new szNum[3], iAccess, cb;
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, cb);

	new iItemIndex = str_to_num(szNum);
	new menudata[weapinfo];
	
	ArrayGetArray(g_Primary_MenuItems, iItemIndex, menudata);
	new TeamName:iTeam = get_member(id, m_iTeam);
	
	if(equal(menudata[weap_name], "weapon_awp")) {
		if(!g_AllowAWP) {
			client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_SERVER, "EWM_AWP_ALLOWFROM", g_AWPCvarHook[MinPlayers], g_AWPCvarHook[MinPlayers]);
			weapmenu(id);
			return PLUGIN_HANDLED;
		}
		else if(g_AWPCvarHook[MaxAwp]) {
			switch(iTeam) {
				case TEAM_TERRORIST: {
					if(g_Awps[TE] < g_AWPCvarHook[MaxAwp]) g_Awps[TE]++;
					else {
						client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_SERVER, "EWM_AWP_TOOMANY", g_AWPCvarHook[MaxAwp]);
						weapmenu(id);
						return PLUGIN_HANDLED;
					}
				}
				case TEAM_CT: {
					if(g_Awps[CT] < g_AWPCvarHook[MaxAwp]) g_Awps[CT]++;
					else {
						client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_SERVER, "EWM_AWP_TOOMANY", g_AWPCvarHook[MaxAwp]);
						weapmenu(id);
						return PLUGIN_HANDLED;
					}
				}
			}
		}
	}
	
	if(get_pcvar_num(g_Cvars[PistolMenu]) == 1) {
		menu_display(id, g_iSec_EquipMenuID, 0);
	}
	else {
		rg_give_item(id, "weapon_deagle", GT_REPLACE);
		rg_set_user_bpammo(id, WEAPON_DEAGLE, 35);
	}
	
	add_weapon(id, menudata[weap_name], menudata[bpammo]);
	rg_set_user_armor(id, 100, ARMOR_VESTHELM);
	if(iTeam == TEAM_CT) rg_give_defusekit(id);
	give_grenades(id);
	strtoupper(menudata[weap_name]);
	client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_SERVER, "EWM_CHOOSED", menudata[weap_name][7]);
	g_Used[id] = true;

	return PLUGIN_HANDLED;
}

stock add_weapon(id, const weapname[], bp_ammo) {
	rg_give_item(id, weapname, GT_REPLACE);
	new weaponid = rg_get_weapon_info(weapname, WI_ID);
	rg_set_user_bpammo(id, WeaponIdType:weaponid, bp_ammo);
}

public Sec_WeaponMenuHandler(id, iMenu, iItem) {
	if(iItem == MENU_EXIT) return PLUGIN_HANDLED;

	new szNum[3], iAccess, cb;
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, cb);

	new iItemIndex = str_to_num(szNum);
	new menudata[weapinfo];
	
	ArrayGetArray(g_Secondary_MenuItems, iItemIndex, menudata);
	
	add_weapon(id, menudata[weap_name], menudata[bpammo]);
	
	return PLUGIN_HANDLED;
}

public Event_NewRound() {
	arrayset(g_Used, false, sizeof(g_Used));
	arrayset(g_Awps, 0, sizeof(g_Awps));
	g_AWPCvarHook[MinPlayers] = get_pcvar_num(g_Cvars[AwpMinPlayers]);
	g_AllowAWP = (get_member_game(m_iNumTerrorist) >= g_AWPCvarHook[MinPlayers] && get_member_game(m_iNumCT) >= g_AWPCvarHook[MinPlayers]) ? true : false;
	g_Grenades[HE] = get_pcvar_num(g_Cvars[MaxHeg]);
	g_Grenades[FLASH] = get_pcvar_num(g_Cvars[MaxFlash]);
	g_Grenades[SMOKE] = get_pcvar_num(g_Cvars[MaxSmoke]);
	g_AWPCvarHook[MaxAwp] = get_pcvar_num(g_Cvars[MaxAwps]);
}

public weapmenu(id) {
	if (!is_user_alive(id) || g_Used[id]) return;
	
	menu_display(id, g_iPrim_EquipMenuID, 0);
}

give_grenades(id) {
	if(g_Grenades[HE])
		rg_give_item(id, "weapon_hegrenade", GT_APPEND);

	if(g_Grenades[FLASH]) {
		rg_give_item(id, "weapon_flashbang", GT_APPEND);
		if(g_Grenades[FLASH] >= 2)
			rg_give_item(id, "weapon_flashbang", GT_APPEND);
	}

	if(g_Grenades[SMOKE])
		rg_give_item(id, "weapon_smokegrenade", GT_APPEND);
}

public plugin_end() {
	ArrayDestroy(g_Primary_MenuItems);
	ArrayDestroy(g_Secondary_MenuItems);
}

public Event_ResetHUD(id) {
	set_member(id, m_iClientHideHUD, 0)
	set_member(id, m_iHideHUD, HUD_HIDE_MONEY)
}

public Event_HideWeapon(id) {
	// for compatibility with other plugins using that message; ZP for example
	new iFlags = read_data(1)
	if(~iFlags & HUD_HIDE_MONEY) {
		set_member(id, m_iClientHideHUD, 0)
		set_member(id, m_iHideHUD, iFlags|HUD_HIDE_MONEY)
	}
}