/* AskPluginLoad2()
 *
 * Called before OnPluginStart.
 * ----------------------------------------------------------------- */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Needed to load properly on older versions of SourceMod
	MarkNativeAsOptional("GetUserMessageType");
	return APLRes_Success;
}

/* OnPluginStart()
 *
 * When the plugin starts up.
 * ----------------------------------------------------------------- */
public OnPluginStart()
{
	decl String:error[MAX_QUERY_LENGTH];

	if (SQL_CheckConfig("dodstats"))
		db = SQL_Connect("dodstats", true, error, sizeof(error));
	else /* If dodstats config is unexist or not specified - store data in local SQLite database */
		db = SQL_Connect("storage-local", true, error, sizeof(error));

	if (db != INVALID_HANDLE)
	{
		// Check DB driver (SQLite or MySQL)
		decl String:driver[10];
		SQL_ReadDriver(db, driver, sizeof(driver));

		if (StrEqual(driver, "mysql", false))
		{
			sqlite = false;
			LogMessage("Connected to a MySQL database.");
		}
		else if (StrEqual(driver, "sqlite", false))
		{
			sqlite = true;
			LogMessage("Using SQLite database.");
		}
		else SetFailState("Fatal error: \"driver\" in databases config should be \"mysql\" or \"sqlite\" !");

		SQL_LockDatabase(db);
	}
	else SetFailState("Plugin encountered fatal error: %s", error);

	// Load common.phrases as well to prevent some errors with targeting.
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("plugin.dodstats");

	// Load all plugin convars
	LoadConVars();

	// Admin commands
	RegAdminCmd("sm_resetstats",  Command_Reset,        ADMFLAG_ROOT, "Reset all stats");
	RegAdminCmd("sm_resetplayer", Command_DeletePlayer, ADMFLAG_ROOT, "Delete a steamid from the database");

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
	HookEvent("dod_round_active", Event_Round_Start, EventHookMode_PostNoCopy);
	HookEvent("dod_round_win",    Event_Round_End);

	// Periodic player stats save
	HookEvent("dod_tick_points", Event_SavePlayersStats, EventHookMode_PostNoCopy);

	// Create and exec plugin.dodstats config in cfg/sourcemod folder
	AutoExecConfig(true, "dod_stats");

	// Register triggers
	CreateTriggersTrie();

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

	if (dodstats_gameplay != INVALID_HANDLE)
	{
		gameplay = DEATHMATCH;
		LogMessage("Server is running DeathMatch > appropriate stats mode enabled.");
	}
	else /* Cant find DM cvar. Lets check for GunGame now */
	{
		dodstats_gameplay = FindConVar("sm_gungame_version");

		if (dodstats_gameplay != INVALID_HANDLE)
		{
			gameplay = GUNGAME; /* If mod detected - accept mode and print to server console */
			LogMessage("Server is running GunGame > appropriate stats mode enabled.");
		}
		else gameplay = DEFAULT;
	}

	if (LibraryExists("updater")) Updater_AddPlugin(UPDATE_URL);

	// Set all db characters to UTF8 (for MySQL only)
	SetEncoding();
}