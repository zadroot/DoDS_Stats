/* OnPluginStart()
 *
 * When the plugin starts up.
 * ----------------------------------------------------------------- */
public OnPluginStart()
{
	decl String:error[256];

	if (SQL_CheckConfig("dodstats"))
		db = SQL_Connect("dodstats", true, error, sizeof(error));
	else /* If dodstats config is unexist or not specified - store data in local SQLite database */
		db = SQL_Connect("storage-local", true, error, sizeof(error));

	if (db != INVALID_HANDLE)
	{
		// Check DB driver (SQLite or MySQL)
		decl String:driver[16];
		SQL_ReadDriver(db, driver, sizeof(driver));

		if (StrEqual(driver, "mysql"))
		{
			sqlite = false;
			LogMessage("Connected to a MySQL database.");
		}
		else if (StrEqual(driver, "sqlite"))
		{
			sqlite = true;
			LogMessage("Using SQLite database.");
		}
		else SetFailState("Fatal Error: Invalid database type: driver should be \"mysql\" or \"sqlite\"!");
	}
	else SetFailState("Fatal Error: Could not connect to database: %s", error);

	// Load common.phrases as well to prevent some errors with targeting.
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.dodstats");

	// Create CoVars
	CreateConVar("sm_dodstats_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	dodstats_announce          = CreateConVar("dodstats_announce",         "1",    "Whether or not print player's information on connect ( points & grade )",         FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodstats_hidechat          = CreateConVar("dodstats_hidechat",         "0",    "Whether or not hide chat triggers ( rank/top/top10/topgg/stats/session/notify )", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodstats_purge             = CreateConVar("dodstats_purge",            "0",    "Number of days to delete inactive players from the database",                     FCVAR_PLUGIN, true, 0.0);
	dodstats_bonusround        = CreateConVar("dodstats_bonusround",       "1",    "Whether or not enable stats during bonusround",                                   FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodstats_minplayers        = CreateConVar("dodstats_minplayers",       "4",    "Minimum players required to record stats\nSet to 0 to disable player check",      FCVAR_PLUGIN, true, 0.0, true, 32.0);
	stats_points_start         = CreateConVar("dodstats_start_points",     "1000", "Sets the starting points for a new player",                                       FCVAR_PLUGIN, true, 0.0);
	stats_points_min           = CreateConVar("dodstats_points_min",       "2",    "Sets the minimum points to take on kill\nSet 0 to disable kill points",           FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_tk_penalty    = CreateConVar("dodstats_tk_penalty",       "8",    "Amount of points to take on team kill (TNT kills will be ignored)",               FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_suicide       = CreateConVar("dodstats_points_suicide",   "5",    "Amount of points to take on suicide",                                             FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_capture       = CreateConVar("dodstats_points_capture",   "2",    "Amount of points to give for capturing area",                                     FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_block         = CreateConVar("dodstats_points_block",     "2",    "Amount of points to give for blocking capture",                                   FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_bomb_explode  = CreateConVar("dodstats_points_explode",   "3",    "Amount of points to add for exploding an object",                                 FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_bomb_planted  = CreateConVar("dodstats_points_plant",     "2",    "Amount of points to give for planting a TNT",                                     FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_bomb_defused  = CreateConVar("dodstats_points_defuse",    "2",    "Amount of points to add for defusing a TNT",                                      FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_headshot      = CreateConVar("dodstats_points_headshot",  "1",    "Amount of points to add for a headshot kill",                                     FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_victory       = CreateConVar("dodstats_points_victory",   "1",    "Amount of points to give for members of team which won the round",                FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_gg_levelup    = CreateConVar("dodstats_points_levelup",   "5",    "Amount of points to give for stealing a level (GG only)",                         FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_gg_leveldown  = CreateConVar("dodstats_points_leveldown", "5",    "Amount of points to take on level lost (GG only)",                                FCVAR_PLUGIN, true, 0.0, true, 25.0);
	stats_points_gg_victory    = CreateConVar("dodstats_points_ggvictory", "10",   "Amount of points to give to a GunGame winner (GG only)",                          FCVAR_PLUGIN, true, 0.0, true, 25.0);

	// Hook say messages for triggers
	AddCommandListener(OnSayCommand, "say");
	AddCommandListener(OnSayCommand, "say_team");

	// Admin commands
	RegAdminCmd("sm_resetstats",  Command_Reset,           ADMFLAG_ROOT,    "Reset all stats");
	RegAdminCmd("sm_resetplayer", Command_DeletePlayer,    ADMFLAG_ROOT,    "Delete a steamid from the database");
	RegAdminCmd("sm_pstats",      Command_ShowTargetStats, ADMFLAG_GENERIC, "Show target's stats");

	// Hook events
	HookEvent("player_disconnect", Event_Player_Disconnect);

	HookEvent("dod_stats_player_damage", Event_Player_Death);
	HookEvent("dod_stats_weapon_attack", Event_Weapon_Fire);

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
	HookEvent("dod_round_active", Event_Round_Start);
	HookEvent("dod_round_win",    Event_Round_End);

	// Create and exec plugin.dodstats config in cfg/sourcemod folder
	AutoExecConfig(true, "dod_stats");

	// Create database tables
	CreateTables();

	// Get global player count
	GetPlayerCount();
}

/* OnAllPluginsLoaded()
 *
 * Called after all plugins have been loaded.
 * ----------------------------------------------------------------- */
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
				else gameplay = 0;
			}
		}
	}

	if (LibraryExists("updater")) Updater_AddPlugin(UPDATE_URL);

	// Set all db characters to UTF8 (MySQL only)
	SetEncoding();
}