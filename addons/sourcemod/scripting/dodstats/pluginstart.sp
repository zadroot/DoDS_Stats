/* OnPluginStart()
 *
 * When the plugin starts up.
 * --------------------------------------------------------------------- */
public OnPluginStart()
{
	decl String:error[256];

	if (SQL_CheckConfig("dodstats"))
		db = SQL_Connect("dodstats", true, error, sizeof(error));
	else /* If dodstats config is unexist or not specified - store data in local SQLite database */
		db = SQL_Connect("storage-local", true, error, sizeof(error));

	if (db == INVALID_HANDLE)
	{
		LogError("ERROR! Could not connect to database: %s", error);
		return;
	}

	// Check DB driver (SQLite or MySQL)
	decl String:driver[16];
	SQL_ReadDriver(db, driver, sizeof(driver));

	if (strcmp(driver, "mysql") == 0 && db != INVALID_HANDLE)
	{
		sqlite = false;
		LogMessage("Connected to a MySQL database!");
	}
	else if (strcmp(driver, "sqlite") == 0 && db != INVALID_HANDLE)
	{
		sqlite = true;
		LogMessage("Using SQLite database.");
	}
	else LogError("ERROR! Invalid database type: driver should be \"mysql\" or \"sqlite\"");

	// Load common.phrases as well to prevent some errors with targeting.
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.dodstats");

	// Create CoVars
	dodstats_version           = CreateConVar("sm_dodstats_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	dodstats_announce          = CreateConVar("dodstats_announce",        "1",    "Whether or not print player's information on connect ( points & grade )",     FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	dodstats_hidechat          = CreateConVar("dodstats_hidechat",        "0",    "Whether or not hide chat triggers ( rank/top/top10/stats/session/notify )",   FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	dodstats_purge             = CreateConVar("dodstats_purge",           "0",    "Number of days to delete inactive players from a database",                   FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0);
	dodstats_bonusround        = CreateConVar("dodstats_bonusround",      "1",    "Whether or not enable stats at bonusround",                                   FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	stats_points_start         = CreateConVar("dodstats_start_points",    "1000", "Sets the starting points for a new player",                                   FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0);
	stats_points_k_value       = CreateConVar("dodstats_k_value",         "10",   "The K-Value. Set to 0 to disable kill points",                                FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_min           = CreateConVar("dodstats_points_min",      "3",    "Sets the minimum points to take on kill\nShould not be higher than K-Value!", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_tk_penalty    = CreateConVar("dodstats_tk_penalty",      "10",   "Amount of points to take on team kill (TNT kills will be ignored)",           FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_suicide       = CreateConVar("dodstats_points_suicide",  "5",    "Amount of points to take on suicide",                                         FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_capture       = CreateConVar("dodstats_points_capture",  "3",    "Amount of points to give for capturing area",                                 FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_block         = CreateConVar("dodstats_points_block",    "3",    "Amount of points to give for blocking capture",                               FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_bomb_explode  = CreateConVar("dodstats_points_explode",  "3",    "Amount of points to add for exploding an object",                             FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_bomb_planted  = CreateConVar("dodstats_points_plant",    "3",    "Amount of points to give for planting a TNT",                                 FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_bomb_defused  = CreateConVar("dodstats_points_defuse",   "3",    "Amount of points to add for defusing a TNT",                                  FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_headshot      = CreateConVar("dodstats_points_headshot", "1",    "Amount of points to add for a headshot kill",                                 FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_victory       = CreateConVar("dodstats_points_victory",  "2",    "Amount of points to give for members of team which won the round",            FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_gg_levelsteal = CreateConVar("dodstats_points_lvlsteal", "5",    "Amount of points to give for stealing a level (GG only)",                     FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);
	stats_points_gg_maxlevel   = CreateConVar("dodstats_points_ggwin",    "25",   "Amount of points to give to a GG winner (GG only)",                           FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 25.0);

	// Hook say messages for triggers
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	// Admin commands
	RegAdminCmd("sm_resetstats",  Command_Reset,           ADMFLAG_ROOT,    "Reset all stats");
	RegAdminCmd("sm_resetplayer", Command_DeletePlayer,    ADMFLAG_ROOT,    "Delete a steamid from the database");
	RegAdminCmd("sm_pstats",      Command_ShowTargetStats, ADMFLAG_GENERIC, "Show target's stats");

	// Hook events
	HookEvent("player_disconnect", Event_Player_Disconnect);
	HookEvent("player_hurt",       Event_Player_Hurt);
	HookEvent("player_death",      Event_Player_Death);

	HookEvent("dod_point_captured",  Event_Point_Captured);
	HookEvent("dod_capture_blocked", Event_Capture_Blocked);

	// Event_Point_Captured also fired with it
	HookEvent("dod_bomb_exploded", Event_Bomb_Exploded);

	// Event_Capture_Blocked also fired with two those
	HookEvent("dod_kill_planter", Event_Bomb_Blocked);
	HookEvent("dod_kill_defuser", Event_Bomb_Blocked);

	HookEvent("dod_bomb_planted", Event_Bomb_Planted);
	HookEvent("dod_bomb_defused", Event_Bomb_Defused);

	// For bonusround
	HookEvent("dod_round_win",   Event_Round_End);
	HookEvent("dod_round_start", Event_Round_Start);

	// Create and exec plugin.dodstats config in cfg/sourcemod folder
	AutoExecConfig(true);

	// Create database tables
	CreateTables();

	// Get global player count
	GetPlayerCount();
}

/* OnAllPluginsLoaded()
 *
 * Called after all plugins have been loaded.
 * --------------------------------------------------------------------- */
public OnAllPluginsLoaded()
{
	// Checking if server is running DeathMatch
	dodstats_gameplay = FindConVar("deathmatch_version");
	{
		if (dodstats_gameplay != INVALID_HANDLE)
		{
			gameplay = 1;
			LogMessage("Server is running DeathMatch > appropriate stats mode enabled.");
		}
		else /* Cant find DM cvar. Lets check for GunGame now */
		{
			dodstats_gameplay = FindConVar("sm_gungame_version");
			{
				if (dodstats_gameplay != INVALID_HANDLE)
				{
					gameplay = 2; /* If mod detected - accept mode and print to server console */
					LogMessage("Server is running GunGame > appropriate stats mode enabled.");
				}
				else LogMessage("Plugin loaded! Default stats mode enabled.");
			}
		}
	}

	// Set all db characters to UTF8 (MySQL only)
	SetEncoding();

	// Check last connect of all players from a database
	RemoveOldPlayers();

	// Work around A2S_RULES bug in linux orangebox
	SetConVarString(dodstats_version, PLUGIN_VERSION);
}