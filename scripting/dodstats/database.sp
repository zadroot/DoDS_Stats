/** SQLite database settings (optional)
 	"dodstats"
	{
		"driver"			"sqlite"
		"database"			"dodstats-sqlite"
	}
*/

/* CreateTables()
 *
 * Creates database tables when the plugin starts.
 * ----------------------------------------------------------------- */
CreateTables()
{
	// For simplest queries are ones which do not return results ( CREATE, DROP, UPDATE, INSERT, and DELETE ) use SQL_FastQuery
	if (sqlite)
		SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS dodstats (steamid TEXT, name TEXT, score INTEGER, kills INTEGER, deaths INTEGER, headshots INTEGER, teamkills INTEGER, teamkilled INTEGER, captured INTEGER, blocked INTEGER, planted INTEGER, defused INTEGER, gg_played INTEGER, gg_leader INTEGER, gg_levelup INTEGER, gg_leveldown INTEGER, hits INTEGER, shots INTEGER, timeplayed INTEGER, notify BOOL, last_connect INTEGER);");
	else /* And dont forget to create tables for MySQL */
		SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS dodstats (steamid varchar(32) NOT NULL, name varchar(32) NOT NULL, score int(6) NOT NULL, kills int(6) NOT NULL, deaths int(6) NOT NULL, headshots int(6) NOT NULL, teamkills int(6) NOT NULL, teamkilled int(6) NOT NULL, captured int(6) NOT NULL, blocked int(6) NOT NULL, planted int(6) NOT NULL, defused int(6) NOT NULL, gg_played int(6) NOT NULL, gg_leader int(6) NOT NULL, gg_levelup int(6) NOT NULL, gg_leveldown int(6) NOT NULL, hits int(32) NOT NULL, shots int(32) NOT NULL, timeplayed int(32) NOT NULL, notify BOOL, last_connect int(32) NOT NULL) ENGINE = MyISAM DEFAULT CHARSET = utf8;");

	SQL_UnlockDatabase(db);
}

/* GetPlayerCount()
 *
 * Gets global count of players from database.
 * ----------------------------------------------------------------- */
GetPlayerCount()
{
	return SQL_TQuery(db, PlayerCountCallback, "SELECT * FROM dodstats");
}

/* PrepareClient()
 *
 * Loads a client's stats on connect.
 * ----------------------------------------------------------------- */
PrepareClient(client)
{
	// It is important to check steamid of every connected player. Otherwise on every disconnect client will lost his stats.
	// decl is bad.
	new String:client_steamid[MAX_STEAMID_LENGTH], String:safe_steamid[(MAX_STEAMID_LENGTH*2)+1], String:query[MAX_QUERY_LENGTH];

	if (GetClientAuthString(client, client_steamid, sizeof(client_steamid)))
	{
		SQL_EscapeString(db, client_steamid, safe_steamid, sizeof(safe_steamid));

		// last_connect ?
		FormatEx(query, sizeof(query), "SELECT score, kills, deaths, headshots, teamkills, teamkilled, captured, blocked, planted, defused, gg_played, gg_leader, gg_levelup, gg_leveldown, hits, shots, timeplayed, notify FROM dodstats WHERE steamid = '%s'", safe_steamid);
		SQL_TQuery(db, PrepareClientData, query, GetClientUserId(client));
	}
}

/* PrepareClientData()
 *
 * Connects to a database via a thread.
 * ----------------------------------------------------------------- */
public PrepareClientData(Handle:owner, Handle:handle, const String:error[], any:client)
{
	if (handle != INVALID_HANDLE)
	{
		// Data is always zero. Stop threading if client is zero.
		if ((client = GetClientOfUserId(client)))
		{
			// For writing names I recommend use MAX_NAME_LENGTH, because that's way makes easier definition of "clean" name
			// decl is bad
			new	String:query[MAX_QUERY_LENGTH],
				String:client_steamid[MAX_STEAMID_LENGTH],
				String:safe_steamid[(MAX_STEAMID_LENGTH*2)+1],
				String:client_name[MAX_NAME_LENGTH],
				String:safe_name[(MAX_NAME_LENGTH*2)+1];

			if (GetClientAuthString(client, client_steamid, sizeof(client_steamid)))
			{
				new time = GetTime(), startpoints = GetConVar[StartPoints][Value];

				GetClientName(client, client_name, sizeof(client_name));
				SQL_EscapeString(db,  client_name, safe_name, sizeof(safe_name));

				// That's how we remove bad characters from nicknames.
				SQL_EscapeString(db, client_steamid, safe_steamid, sizeof(safe_steamid));

				// Is player was connected before?
				if (SQL_MoreRows(handle))
				{
					// Then we're gonna only update his nickname and date of last visit.
					FormatEx(query, sizeof(query), "UPDATE dodstats SET name = '%s', last_connect = %i WHERE steamid = '%s'", safe_name, time, safe_steamid);
					SQL_TQuery(db, DB_CheckErrors, query);

					// And get player's previous data.
					while (SQL_FetchRow(handle))
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
						dod_stats_gg_levelup[client]      = SQL_FetchInt(handle, 12);
						dod_stats_gg_leveldown[client]    = SQL_FetchInt(handle, 13);
						dod_stats_weaponhits[client]      = SQL_FetchInt(handle, 14);
						dod_stats_weaponshots[client]     = SQL_FetchInt(handle, 15);
						dod_stats_time_played[client]     = SQL_FetchInt(handle, 16);
						dod_stats_client_notify[client]   = bool:SQL_FetchInt(handle, 17);
						break;
					}
				}
				else // Nope player is new
				{
					// Yep. Creating tables.
					if (sqlite)
						FormatEx(query, sizeof(query), "INSERT INTO dodstats VALUES ('%s', '%s', %i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, %i)", safe_steamid, safe_name, startpoints, time);
					else /* Because MySQL is different */
						FormatEx(query, sizeof(query), "INSERT INTO dodstats (steamid, name, score, kills, deaths, headshots, teamkills, teamkilled, captured, blocked, planted, defused, gg_played, gg_leader, gg_levelup, gg_leveldown, hits, shots, timeplayed, notify, last_connect) VALUES ('%s', '%s', %i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, %i)", safe_steamid, safe_name, startpoints, time);

					SQL_TQuery(db, DB_CheckErrors, query);

					/** Initialize tables. */
					// Start score depends on start points value.
					dod_stats_score[client] = startpoints;

					dod_stats_kills[client] =
					dod_stats_deaths[client] =
					dod_stats_headshots[client] =
					dod_stats_teamkills[client] =
					dod_stats_teamkilled[client] =
					dod_stats_captures[client] =
					dod_stats_capblocks[client] =
					dod_stats_planted[client] =
					dod_stats_defused[client] =
					dod_stats_gg_roundsplayed[client] =
					dod_stats_gg_roundswon[client] =
					dod_stats_gg_levelup[client] =
					dod_stats_gg_leveldown[client] =
					dod_stats_weaponhits[client] =
					dod_stats_weaponshots[client] =
					dod_stats_time_played[client] =
					dod_stats_client_notify[client] = false;

					dod_global_player_count++;
				}

				// Check whether or not player's info should announce on connect
				if (GetConVar[Announce][Value]) ShowInfo(client);

				// Player just joined now. Start time tracking
				dod_stats_time_joined[client] = time;
				dod_stats_online[client]      = true;

				// Session stats
				dod_stats_session_score[client] =
				dod_stats_session_kills[client] =
				dod_stats_session_deaths[client] =
				dod_stats_session_headshots[client] = 0;
			}
		}
	}
	else LogError("Could not prepare client stats: %s", error);
}

/* QueryRankStats()
 *
 * Executes a query Handle for receiving the results for rank.
 * ----------------------------------------------------------------- */
QueryRankStats(client)
{
	decl String:query[MAX_QUERY_LENGTH];
	FormatEx(query, sizeof(query), "SELECT DISTINCT score FROM dodstats WHERE score > %i ORDER BY score ASC", dod_stats_score[client]);

	// We need handles for getting positions. Query database again...
	SQL_TQuery(db, QueryRank, query, GetClientUserId(client));
}

/* QueryRank()
 *
 * Executes a simple query via a thread for rank.
 * ----------------------------------------------------------------- */
public QueryRank(Handle:owner, Handle:handle, const String:error[], any:client)
{
	if (handle != INVALID_HANDLE)
	{
		if ((client = GetClientOfUserId(client)))
		{
			// Getting rank position of all players.
			new	rank = SQL_GetRowCount(handle),
				next_score, bool:rankup = true;

			// Success! Database isn't empty!
			if (SQL_HasResultSet(handle) && SQL_FetchRow(handle))
			{
				rank = SQL_GetRowCount(handle) + 1;
				rankup = false;
				next_score = SQL_FetchInt(handle, false);
			}
			if (rankup) rank++;

			// Data is ready, run command
			ShowRank(client, rank, next_score);
		}
	}
	else LogError("Could not query rank: %s", error);
}

/* QueryTopPlayers()
 *
 * Executes a query Handle for receiving the results for top10.
 * ----------------------------------------------------------------- */
QueryTopPlayers(client, count)
{
	decl String:query[MAX_QUERY_LENGTH];

	// DESC LIMIT = 10 because we need to query only 10 players!
	FormatEx(query, sizeof(query), "SELECT name, score, kills, deaths FROM dodstats ORDER BY score DESC LIMIT %i, 10", count);
	SQL_TQuery(db, ShowTop10, query, GetClientUserId(client));
}

/* QueryTopGrades()
 *
 * Executes a query Handle for receiving the results for topgrades.
 * ----------------------------------------------------------------- */
QueryTopGrades(client, count)
{
	decl String:query[MAX_QUERY_LENGTH];
	FormatEx(query, sizeof(query), "SELECT name, captured, kills FROM dodstats ORDER BY kills DESC LIMIT %i, 10", count);

	// Data is queried and received, show top players.
	SQL_TQuery(db, ShowTopGrades, query, GetClientUserId(client));
}

/* QueryTopGG()
 *
 * Executes a query Handle for receiving the results for topgg.
 * ----------------------------------------------------------------- */
QueryTopGG(client, count)
{
	if (gameplay == GUNGAME)
	{
		decl String:query[MAX_QUERY_LENGTH];
		FormatEx(query, sizeof(query), "SELECT name, gg_leader, gg_levelup FROM dodstats ORDER BY gg_leader DESC LIMIT %i, 10", count);
		SQL_TQuery(db, ShowTopGG, query, GetClientUserId(client));
	}
}

/* QueryStats()
 *
 * Executes a query Handle for receiving the results for stats.
 * ----------------------------------------------------------------- */
QueryStats(client)
{
	decl String:query[MAX_QUERY_LENGTH];
	FormatEx(query, sizeof(query), "SELECT DISTINCT score FROM dodstats WHERE score > %i ORDER BY score ASC", dod_stats_score[client]);

	// We need handles for getting positions. Query database again...
	SQL_TQuery(db, QueryStatsMe, query, GetClientUserId(client));
}

/* QueryStats()
 *
 * Executes a simple query via a thread for statsme.
 * ----------------------------------------------------------------- */
public QueryStatsMe(Handle:owner, Handle:handle, const String:error[], any:client)
{
	// Almost same as rank
	if (handle != INVALID_HANDLE)
	{
		if ((client = GetClientOfUserId(client)))
		{
			new	rank = SQL_GetRowCount(handle),
				bool:rankup = true;

			if (SQL_HasResultSet(handle) && SQL_FetchRow(handle))
			{
				rank = SQL_GetRowCount(handle) + 1;
				rankup = false;
			}
			if (rankup) rank++;

			// Data is ready, show stats
			ShowStats(client, rank);
		}
	}
	else LogError("Could not query player's stats: %s", error);
}

/* PlayerCountCallback()
 *
 * Getting number of all players from the database via a thread.
 * ----------------------------------------------------------------- */
public PlayerCountCallback(Handle:owner, Handle:handle, const String:error[], any:data)
{
	// SQL_FetchInt are not working with MySQL, I try SQL_GetRowCount instead
	if (handle != INVALID_HANDLE)
	{
		dod_global_player_count = SQL_GetRowCount(handle);
	}
}

/* RemoveOldPlayers()
 *
 * Querying last connect and delete a player if inactive > days.
 * ----------------------------------------------------------------- */
RemoveOldPlayers()
{
	// If purge value is initialized - check last connect of all players from a database
	if (GetConVar[Purge][Value])
	{
		// Create a single query for purge.
		decl String:query[MAX_QUERY_LENGTH]; // Current date - purge value * 24 hours.
		FormatEx(query, sizeof(query), "DELETE FROM dodstats WHERE last_connect <= %i; VACUUM", GetTime() - (GetConVar[Purge][Value] * 86400));
		SQL_TQuery(db, DB_PurgeCallback, query);
	}
}

/* SetEncoding()
 *
 * Sets all database characters to UTF-8 encode.
 * ----------------------------------------------------------------- */
SetEncoding()
{
	if (!sqlite && !SQL_SetCharset(db, "utf8"))
	{
		SQL_TQuery(db, DB_CheckErrors, "SET NAMES utf8");
	}
}

/* ToggleNotify()
 *
 * Updates notiy preferences via a thread.
 * ----------------------------------------------------------------- */
ToggleNotify(client)
{
	// Get client data.
	// decl is bad
	new	String:client_steamid[MAX_STEAMID_LENGTH],
		String:safe_steamid[(MAX_STEAMID_LENGTH*2)+1],
		String:query[MAX_QUERY_LENGTH],
		String:status[8];

	if (GetClientAuthString(client, client_steamid, sizeof(client_steamid)))
	{
		SQL_EscapeString(db, client_steamid, safe_steamid, sizeof(safe_steamid));

		// Toggle player notifications
		dod_stats_client_notify[client] = !dod_stats_client_notify[client];

		// No need to save notify all time, just update it once.
		FormatEx(query, sizeof(query), "UPDATE dodstats SET notify = %i WHERE steamid = '%s'", dod_stats_client_notify[client], safe_steamid);
		FormatEx(status, sizeof(status), "%T", dod_stats_client_notify[client] ? "On" : "Off", client);
		CPrintToChat(client, "%t", "Toggled notifications", status);
		SQL_TQuery(db, DB_CheckErrors, query);
	}
}

/* DB_CheckErrors()
 *
 * Checks errors on every query.
 * ----------------------------------------------------------------- */
public DB_CheckErrors(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (error[0]) LogError(error);
}

/* DB_PurgeCallback()
 *
 * Set characters to UTF-8.
 * ----------------------------------------------------------------- */
public DB_PurgeCallback(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new rows = SQL_GetAffectedRows(owner);

		// If more or equal rows was changed - log message
		if (rows)
		{
			LogMessage("Database has been purged: %i player(s) was removed due of inactivity.", rows);
			dod_global_player_count -= rows;
		}
	}
	else LogError("Could not purge database: %s", error);
}

/* SavePlayer()
 *
 * Update and save player's stats into database.
 * ----------------------------------------------------------------- */
SavePlayer(client)
{
	// decl is bad
	new	String:client_steamid[MAX_STEAMID_LENGTH],
		String:safe_steamid[(MAX_STEAMID_LENGTH*2)+1],
		String:client_name[MAX_NAME_LENGTH],
		String:safe_name[(MAX_NAME_LENGTH*2)+1];

	if (GetClientAuthString(client, client_steamid, sizeof(client_steamid)))
	{
		// "Dirty" name
		GetClientName(client, client_name, sizeof(client_name));
		SQL_EscapeString(db,  client_name, safe_name, sizeof(safe_name));

		// Make SQL safer
		SQL_EscapeString(db, client_steamid, safe_steamid, sizeof(safe_steamid));

		decl String:query[MAX_QUERY_LENGTH];
		Format(query, sizeof(query), "UPDATE dodstats SET \
		name = '%s', \
		score = %i, \
		kills = %i, \
		deaths = %i, \
		headshots = %i, \
		teamkills = %i, \
		teamkilled = %i, \
		captured = %i, \
		blocked = %i, \
		planted = %i, \
		defused = %i, \
		gg_played = %i, \
		gg_leader = %i, \
		gg_levelup = %i, \
		gg_leveldown = %i, \
		hits = %i, \
		shots = %i, \
		timeplayed = %i \
		WHERE steamid = '%s'",
		safe_name,
		dod_stats_score[client],
		dod_stats_kills[client],
		dod_stats_deaths[client],
		dod_stats_headshots[client],
		dod_stats_teamkills[client],
		dod_stats_teamkilled[client],
		dod_stats_captures[client],
		dod_stats_capblocks[client],
		dod_stats_planted[client],
		dod_stats_defused[client],
		dod_stats_gg_roundsplayed[client],
		dod_stats_gg_roundswon[client],
		dod_stats_gg_levelup[client],
		dod_stats_gg_leveldown[client],
		dod_stats_weaponhits[client],
		dod_stats_weaponshots[client],
		dod_stats_time_played[client] + (GetTime() - dod_stats_time_joined[client]),
		safe_steamid);

		// Queries can cause noticeable gameplay lag, and supporting threading is often a good idea if your queries occur in the middle of gameplay.
		SQL_TQuery(db, DB_CheckErrors, query);
	}
}