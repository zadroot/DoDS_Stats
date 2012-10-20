// ====[ VARIABLES ]===================================================
#define DOD_MAXPLAYERS     33
#define AWARDS             21
#define TOP_PLAYERS        10

// Create Handles
new	Handle:dodstats_info[DOD_MAXPLAYERS],
	Handle:dodstats_announce          = INVALID_HANDLE,
	Handle:dodstats_hidechat          = INVALID_HANDLE,
	Handle:dodstats_purge             = INVALID_HANDLE,
	Handle:dodstats_bonusround        = INVALID_HANDLE,
	Handle:dodstats_minplayers        = INVALID_HANDLE,
	Handle:dodstats_gameplay          = INVALID_HANDLE,
	Handle:stats_points_start         = INVALID_HANDLE,
	Handle:stats_points_k_value       = INVALID_HANDLE,
	Handle:stats_points_min           = INVALID_HANDLE,
	Handle:stats_points_tk_penalty    = INVALID_HANDLE,
	Handle:stats_points_suicide       = INVALID_HANDLE,
	Handle:stats_points_capture       = INVALID_HANDLE,
	Handle:stats_points_block         = INVALID_HANDLE,
	Handle:stats_points_bomb_explode  = INVALID_HANDLE,
	Handle:stats_points_bomb_planted  = INVALID_HANDLE,
	Handle:stats_points_bomb_defused  = INVALID_HANDLE,
	Handle:stats_points_victory       = INVALID_HANDLE,
	Handle:stats_points_headshot      = INVALID_HANDLE,
	Handle:stats_points_gg_levelsteal = INVALID_HANDLE,
	Handle:stats_points_gg_maxlevel   = INVALID_HANDLE,
	Handle:db                         = INVALID_HANDLE;

// Other
new Handle:gungame_custom = INVALID_HANDLE,
	bool:rankactive = true,
	bool:roundend   = false,
	bool:sqlite     = false,
	gameplay = 0, /* 0 = Normal. 1 = DeathMatch. 2 = GunGame */
	dod_global_player_count;

// Awards
new String:grade_names[][] =
{
	"Civil",
	"Private",
	"Corporal",
	"Sergeant",
	"Staff Sergeant",
	"Sergeant First Class",
	"Sergeant Major",
	"Command Sergeant Major",
	"Warrant Officer One",
	"Second Lieutenant",
	"First Lieutenant",
	"Captain",
	"Major",
	"Lieutenant Colonel",
	"Colonel",
	"Brigadier General",
	"Major General",
	"Lieutenant General",
	"General",
	"General of the Army",
	"Marshal"
};

// Awards (captures & kills)
new grade_captures[] = { 0, 10, 63,  125, 196, 244, 305,  477,  596,  745,  1164, 1455, 1819, 2277, 2844,  3500,  4375,  5675,  7500,  8500,  10000 };
new grade_kills[]    = { 0, 40, 250, 500, 781, 977, 1221, 1907, 2384, 2980, 3725, 5821, 7276, 9095, 11369, 14211, 17500, 22500, 30000, 40000, 50000 };

// For database tracking
new dod_stats_online[DOD_MAXPLAYERS],
	dod_stats_score[DOD_MAXPLAYERS],
	dod_stats_kills[DOD_MAXPLAYERS],
	dod_stats_deaths[DOD_MAXPLAYERS],
	dod_stats_captures[DOD_MAXPLAYERS],
	dod_stats_capblocks[DOD_MAXPLAYERS],
	dod_stats_planted[DOD_MAXPLAYERS],
	dod_stats_defused[DOD_MAXPLAYERS],
	dod_stats_headshots[DOD_MAXPLAYERS],
	dod_stats_teamkills[DOD_MAXPLAYERS],
	dod_stats_teamkilled[DOD_MAXPLAYERS],
	dod_stats_time_joined[DOD_MAXPLAYERS],
	dod_stats_time_played[DOD_MAXPLAYERS],
	dod_stats_session_score[DOD_MAXPLAYERS],
	dod_stats_session_kills[DOD_MAXPLAYERS],
	dod_stats_session_deaths[DOD_MAXPLAYERS],
	dod_stats_session_headshots[DOD_MAXPLAYERS],
	dod_stats_client_notify[DOD_MAXPLAYERS],
	dod_stats_gg_roundsplayed[DOD_MAXPLAYERS],
	dod_stats_gg_roundswon[DOD_MAXPLAYERS],
	dod_stats_gg_levelsteal[DOD_MAXPLAYERS],
	dod_stats_gg_leveldown[DOD_MAXPLAYERS];