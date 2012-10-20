/** SQLite database settings (optional)
 	"dodstats"
	{
		"driver"			"sqlite"
		"database"			"dodstats-sqlite"
		"timeout"			"1"
	}
*/

/* CreateTables()
 *
 * Creates database tables when the plugin starts.
 * --------------------------------------------------------------------- */
CreateTables()
{
	// For simplest queries are ones which do not return results ( CREATE, DROP, UPDATE, INSERT, and DELETE ) use SQL_FastQuery
	if (sqlite)
		SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS dod_stats (steamid TEXT, name TEXT, score INTEGER, kills INTEGER, deaths INTEGER, headshots INTEGER, teamkills INTEGER, teamkilled INTEGER, captured INTEGER, blocked INTEGER, planted INTEGER, defused INTEGER, gg_played INTEGER, gg_won INTEGER, gg_levelsteal INTEGER, gg_leveldown INTEGER, online BOOL, notify BOOL, timeplayed INTEGER, last_connect INTEGER, PRIMARY KEY (steamid));");
	else /* And dont forget to create tables for MySQL */
		SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS dod_stats (steamid varchar(64) NOT NULL, name varchar(32) NOT NULL, score int(6) NOT NULL, kills int(6) NOT NULL, deaths int(6) NOT NULL, headshots int(6) NOT NULL, teamkills int(6) NOT NULL, teamkilled int(6) NOT NULL, captured int(6) NOT NULL, blocked int(6) NOT NULL, planted int(6) NOT NULL, defused int(6) NOT NULL, gg_played int(6) NOT NULL, gg_won int(6) NOT NULL, gg_levelsteal int(6) NOT NULL, gg_leveldown int(6) NOT NULL, online BOOL, notify BOOL, timeplayed int(32) NOT NULL, last_connect int(32) NOT NULL, PRIMARY KEY (steamid)) ENGINE = MyISAM DEFAULT CHARSET = utf8;");
}

/* GetPlayerCount()
 *
 * Gets global count of players from database.
 * --------------------------------------------------------------------- */
GetPlayerCount()
{
	if (db != INVALID_HANDLE)
	{
		decl String:query[128];

		Format(query, sizeof(query), "SELECT * FROM dod_stats");
		SQL_TQuery(db, PlayerCountCallback, query);
	}
}

/* PrepareClient()
 *
 * Loads a client's stats on connect.
 * --------------------------------------------------------------------- */
PrepareClient(client)
{
	// It is important to check steamid of every connected player. Otherwise on every disconnect client will lost his stats.
	decl String:client_steamid[64], String:query[512];
	GetClientAuthString(client, client_steamid, sizeof(client_steamid));

	// last_connect ?
	Format(query, sizeof(query), "SELECT score, kills, deaths, headshots, teamkills, teamkilled, captured, blocked, planted, defused, gg_played, gg_won, gg_levelsteal, gg_leveldown, online, notify, timeplayed FROM dod_stats WHERE steamid = '%s'", client_steamid);

	SQL_TQuery(db, PrepareClientData, query, GetClientUserId(client));
}

/* PrepareClientData()
 *
 * Connects to a database via a thread.
 * --------------------------------------------------------------------- */
public PrepareClientData(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client, time = GetTime();

		// Data is always zero. Stop threading if client is zero.
		if ((client = GetClientOfUserId(data)) > 0)
		{
			// For writing names I recommend use MAX_NAME_LENGTH, because that's way makes easier definition of "clean" name
			decl String:query[512], String:client_steamid[64], String:client_name[MAX_NAME_LENGTH], String:safe_name[(MAX_NAME_LENGTH*2)+1];

			GetClientName(client, client_name, sizeof(client_name));
			GetClientAuthString(client, client_steamid, sizeof(client_steamid));

			// That's how we remove bad characters from nicknames.
			SQL_EscapeString(db, client_name, safe_name, sizeof(safe_name));

			// Is player was connected before?
			if (SQL_MoreRows(handle))
			{
				// Then we're gonna only update his nickname and date of last visit.
				Format(query, sizeof(query), "UPDATE dod_stats SET name = '%s', last_connect = %i WHERE steamid = '%s'", safe_name, time, client_steamid);
				SQL_TQuery(db, DB_CheckErrors, query);

				// And get player's previous data.
				while(SQL_FetchRow(handle))
				{
					dod_stats_score[client]           = SQL_FetchInt(handle, 0);
					dod_stats_kills[client]           = SQL_FetchInt(handle, 1);
					dod_stats_deaths[client]          = SQL_FetchInt(handle, 2);
					dod_stats_headshots[client]       = SQL_FetchInt(handle, 3);
					dod_stats_teamkills[client]       = SQL_FetchInt(handle, 4);
					dod_stats_teamkilled[client]      = SQL_FetchInt(handle, 5);
					dod_stats_captures[client]        = SQL_FetchInt(handle, 6);
					dod_stats_capblocks[client]       = SQL_FetchInt(handle, 7);
					dod_stats_planted[client]         = SQL_FetchInt(handle, 8);
					dod_stats_defused[client]         = SQL_FetchInt(handle, 9);
					dod_stats_gg_roundsplayed[client] = SQL_FetchInt(handle, 10);
					dod_stats_gg_roundswon[client]    = SQL_FetchInt(handle, 11);
					dod_stats_gg_levelsteal[client]   = SQL_FetchInt(handle, 12);
					dod_stats_gg_leveldown[client]    = SQL_FetchInt(handle, 13);
					dod_stats_online[client]          = SQL_FetchInt(handle, 14);
					dod_stats_client_notify[client]   = SQL_FetchInt(handle, 15);
					dod_stats_time_played[client]     = SQL_FetchInt(handle, 16);
				}
			}
			else // Nope player is new
			{
				// Yep. Creating tables.
				if (sqlite)
					Format(query, sizeof(query), "INSERT INTO dod_stats VALUES ('%s', '%s', %i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, %i)", client_steamid, safe_name, GetConVarInt(stats_points_start), GetTime());
				else /* Because MySQL is different */
					Format(query, sizeof(query), "INSERT INTO dod_stats (steamid, name, score, kills, deaths, headshots, teamkills, teamkilled, captured, blocked, planted, defused, gg_played, gg_won, gg_levelsteal, gg_leveldown, online, notify, timeplayed, last_connect) VALUES ('%s', '%s', %i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, %i)", client_steamid, safe_name, GetConVarInt(stats_points_start), GetTime());
				SQL_TQuery(db, DB_CheckErrors, query);

				/** Initialize tables. */
				// Start score depends on start points value.
				dod_stats_score[client] = GetConVarInt(stats_points_start);
				dod_stats_kills[client] = 0;
				dod_stats_deaths[client] = 0;
				dod_stats_headshots[client] = 0;
				dod_stats_teamkills[client] = 0;
				dod_stats_teamkilled[client] = 0;
				dod_stats_captures[client] = 0;
				dod_stats_capblocks[client] = 0;
				dod_stats_planted[client] = 0;
				dod_stats_defused[client] = 0;
				dod_stats_gg_roundsplayed[client] = 0;
				dod_stats_gg_roundswon[client] = 0;
				dod_stats_gg_levelsteal[client] = 0;
				dod_stats_gg_leveldown[client] = 0;
				dod_stats_online[client] = false;
				dod_stats_client_notify[client] = false;
				dod_stats_time_played[client] = 0;
				dod_stats_time_joined[client] = time;
				dod_global_player_count++;
			}

			// New session feature: session stats will not reset after mapchange.
			if (!dod_stats_online[client])
			{
				// Check whether or not player's info should announce on connect
				if (GetConVarBool(dodstats_announce)) ShowInfo(client);

				dod_stats_online[client] = true;

				// Player just joined now. Start time tracking
				dod_stats_time_joined[client] = time;

				// Session stats
				dod_stats_session_score[client] = 0;
				dod_stats_session_kills[client] = 0;
				dod_stats_session_deaths[client] = 0;
				dod_stats_session_headshots[client] = 0;

				Format(query, sizeof(query), "UPDATE dod_stats SET online = 1 WHERE steamid = '%s'", client_steamid);
				SQL_TQuery(db, DB_CheckErrors, query);
			}
		}
	}
	else LogError("Could not create or load client data: %s", error);
}

/* QueryRankStats()
 *
 * Executes a query Handle for receiving the results for rank. (threaded)
 * --------------------------------------------------------------------- */
QueryRankStats(client)
{
	decl String:query[512];
	Format(query, sizeof(query), "SELECT DISTINCT score FROM dod_stats WHERE score > %i ORDER BY score ASC;", dod_stats_score[client]);

	// We need handles for getting positions. Query database again...
	SQL_TQuery(db, QueryRank, query, GetClientUserId(client));
}

/* QueryRank()
 *
 * Executes a simple query via a thread for rank.
 * --------------------------------------------------------------------- */
public QueryRank(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client;
		if ((client = GetClientOfUserId(data)) > 0)
		{
			// Getting rank position of all players.
			new rank = SQL_GetRowCount(handle),
				next_score = 0,
				bool:rankup = true;

			// Success! Database isn't empty!
			if (SQL_HasResultSet(handle) && SQL_FetchRow(handle))
			{
				rank = SQL_GetRowCount(handle);
				rank++;
				rankup = false;
				next_score = SQL_FetchInt(handle, 0);
			}
			if (rankup) rank++;

			// Data is ready, run command
			ShowRank(client, rank, next_score);
		}
	}
	else LogError("Could not query rank: %s", error);
}

/* QueryTop10()
 *
 * Executes a query Handle for receiving the results for top10.
 * --------------------------------------------------------------------- */
QueryTop10(client)
{
	decl String:query[512];

	// DESC LIMIT = 10 because we need to query only 10 players!
	Format(query, sizeof(query), "SELECT name, score, kills, deaths FROM dod_stats ORDER BY score DESC LIMIT 10;");

	SQL_TQuery(db, ShowTop10, query, GetClientUserId(client));
}

/* QueryTopGrades()
 *
 * Executes a query Handle for receiving the results for topgrades.
 * --------------------------------------------------------------------- */
QueryTopGrades(client)
{
	decl String:query[512];
	Format(query, sizeof(query), "SELECT name, captured, kills FROM dod_stats ORDER BY kills DESC LIMIT 10;");

	// Data is queried and received, show top players.
	SQL_TQuery(db, ShowTopGrades, query, GetClientUserId(client));
}

/* QueryStats()
 *
 * Executes a query Handle for receiving the results for stats. (threaded)
 * --------------------------------------------------------------------- */
QueryStats(client)
{
	decl String:query[512];
	Format(query, sizeof(query), "SELECT DISTINCT score FROM dod_stats WHERE score > %i ORDER BY score ASC;", dod_stats_score[client]);

	// We need handles for getting positions. Query database again...
	SQL_TQuery(db, QueryStatsMe, query, GetClientUserId(client));
}

/* QueryStats()
 *
 * Executes a simple query via a thread for statsme.
 * --------------------------------------------------------------------- */
public QueryStatsMe(Handle:owner, Handle:handle, const String:error[], any:data)
{
	// Almost same as rank
	if (handle != INVALID_HANDLE)
	{
		new client;
		if ((client = GetClientOfUserId(data)) > 0)
		{
			new rank = SQL_GetRowCount(handle),
				bool:rankup = true;

			if (SQL_HasResultSet(handle) && SQL_FetchRow(handle))
			{
				rank = SQL_GetRowCount(handle);
				rank++;
				rankup = false;
			}
			if (rankup) rank++;

			// Data is ready, show stats
			ShowStats(client, client, rank);
		}
	}
	else LogError("Could not query player stats: %s", error);
}

/* PlayerCountCallback()
 *
 * Getting number of all players from the database via a thread.
 * --------------------------------------------------------------------- */
public PlayerCountCallback(Handle:owner, Handle:handle, const String:error[], any:data)
{
	// SQL_FetchInt are not working with MySQL, I try SQL_GetRowCount instead
	if (handle != INVALID_HANDLE) dod_global_player_count = SQL_GetRowCount(handle);
}

/* RemoveOldPlayers()
 *
 * Querying last connect and delete a player if inactive > days.
 * --------------------------------------------------------------------- */
RemoveOldPlayers()
{
	// If purge value is initialized - check last connect of all players from a database
	if (GetConVarInt(dodstats_purge) > 0)
	{
		// Create a single query for purge.
		decl String:query[512];

		// Current date - purge value * 24 hours.
		new days = GetTime() - (GetConVarInt(dodstats_purge) * 86400);

		Format(query, sizeof(query), "DELETE FROM dod_stats WHERE last_connect <= %i", days);

		SQL_TQuery(db, DB_PurgeCallback, query);
	}
}

/* SetEncoding()
 *
 * Sets all database characters to UTF-8 encode.
 * --------------------------------------------------------------------- */
SetEncoding()
{
	if (!sqlite)
	{
		decl String:query[255];
		Format(query, sizeof(query), "SET NAMES utf8");

		// Set codepage to utf8
		SQL_TQuery(db, DB_SetEncoding, query);
	}
}

/* ToggleNotify()
 *
 * Updates notiy preferences via a thread.
 * --------------------------------------------------------------------- */
ToggleNotify(client)
{
	if (db != INVALID_HANDLE)
	{
		// Get client data.
		decl String:client_steamid[64], String:query[128];
		GetClientAuthString(client, client_steamid, sizeof(client_steamid));

		// Client's preferences of `notify` is enabled.
		if (dod_stats_client_notify[client])
		{
			dod_stats_client_notify[client] = false;

			CPrintToChat(client, "%t", "Notifications disabled");

			// No need to save notify all time, just update it once.
			Format(query, sizeof(query), "UPDATE dod_stats SET notify = 0 WHERE steamid = '%s'", client_steamid);
			SQL_TQuery(db, DB_CheckErrors, query);
		}
		else /* Notify was disabled. Enable it now. */
		{
			dod_stats_client_notify[client] = true;

			// Player changed his notify preferences - notify him 8)
			CPrintToChat(client, "%t", "Notifications enabled");

			Format(query, sizeof(query), "UPDATE dod_stats SET notify = 1 WHERE steamid = '%s'", client_steamid);
			SQL_TQuery(db, DB_CheckErrors, query);
		}
	}
}

/* DB_CheckErrors()
 *
 * Checks errors on every query.
 * --------------------------------------------------------------------- */
public DB_CheckErrors(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (!StrEqual(NULL_STRING, error)) LogError("Database Error: %s", error);
}

/* DB_SetEncoding()
 *
 * Set characters to UTF-8.
 * --------------------------------------------------------------------- */
public DB_SetEncoding(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (!StrEqual(NULL_STRING, error)) LogError("Could not set encoding to UTF-8: %s", error);
}

/* DB_PurgeCallback()
 *
 * Set characters to UTF-8.
 * --------------------------------------------------------------------- */
public DB_PurgeCallback(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		// If more or equal rows was changed - log message
		if (SQL_GetAffectedRows(owner) > 0)
		{
			LogMessage("%i players was removed due of inactivity.", SQL_GetAffectedRows(owner));
			dod_global_player_count -= SQL_GetAffectedRows(owner);
		}
	}
	else LogError("Could not purge database: %s", error);
}

/* SavePlayer()
 *
 * Update and save player's stats into database.
 * --------------------------------------------------------------------- */
SavePlayer(client)
{
	if (db != INVALID_HANDLE)
	{
		new time = GetTime();
		decl String:client_name[MAX_NAME_LENGTH], String:client_steamid[64], String:safe_name[(MAX_NAME_LENGTH*2)+1];

		// "Dirty" name
		GetClientName(client, client_name, sizeof(client_name));
		GetClientAuthString(client, client_steamid, sizeof(client_steamid));

		// Make SQL safer
		SQL_EscapeString(db, client_name, safe_name, sizeof(safe_name));

		decl String:query[512];
		Format(query, sizeof(query), "UPDATE dod_stats SET name = '%s', score = %i, kills = %i, deaths = %i, headshots = %i, teamkills = %i, teamkilled = %i, captured = %i, blocked = %i, planted = %i, defused = %i, gg_played = %i, gg_won = %i, gg_levelsteal = %i, gg_leveldown = %i, timeplayed = %i WHERE steamid = '%s'", safe_name, dod_stats_score[client], dod_stats_kills[client], dod_stats_deaths[client], dod_stats_headshots[client], dod_stats_teamkills[client], dod_stats_teamkilled[client], dod_stats_captures[client], dod_stats_capblocks[client], dod_stats_planted[client], dod_stats_defused[client], dod_stats_gg_roundsplayed[client], dod_stats_gg_roundswon[client], dod_stats_gg_levelsteal[client], dod_stats_gg_leveldown[client], dod_stats_time_played[client] + (time - dod_stats_time_joined[client]), client_steamid);

		// Queries can cause noticeable gameplay lag, and supporting threading is often a good idea if your queries occur in the middle of gameplay.
		SQL_TQuery(db, DB_CheckErrors, query);
	}
}