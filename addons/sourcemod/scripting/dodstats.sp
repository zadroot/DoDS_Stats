/**
* DoD:S Stats by Root
*
* Description:
*    A stats plugin (SQLite/MySQL) with many features, full point customization and DeathMatch support.
*
* Version 1.7.3
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]=================================================
#include <sourcemod>
#include <colors>

// ====[ CONSTANTS ]================================================
#define PLUGIN_NAME    "DoD:S Stats"
#define PLUGIN_VERSION "1.7.3"

// ====[ PLUGIN ]===================================================
#include "dodstats/init.sp"
#include "dodstats/pluginstart.sp"
#include "dodstats/database.sp"
#include "dodstats/display.sp"
#include "dodstats/admin.sp"
#include "dodstats/events.sp"

public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "A stats with awards, captures, headshots & more...",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/* OnMapStart()
 *
 * When the map starts.
 * ----------------------------------------------------------------- */
public OnMapStart()
{
	// Update global player count at every mapchange for servers with MySQL database
	if (!sqlite)
		GetPlayerCount();

	// Get previous connects of all players from a database and remove inactive players
	RemoveOldPlayers();
}

/* OnClientPutInServer()
 *
 * Called when a client is entering the game.
 * ----------------------------------------------------------------- */
public OnClientPutInServer(client)
{
	// Checking if client is valid and not a bot
	if (client > 0 && !IsFakeClient(client))
	{
		// Load or create client stats
		PrepareClient(client);

		// Show welcome message to a player then
		dodstats_info[client] = CreateTimer(30.0, Timer_WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);

		// Enable stats if there is enough players on a server right now
		if (!roundend && GetClientCount() >= GetConVarInt(dodstats_minplayers))
			rankactive = true;
	}
}

/* OnClientDisconnect(client)
 *
 * When a client disconnects from the server.
 * ----------------------------------------------------------------- */
public OnClientDisconnect(client)
{
	// Once again check if player is valid
	if (client > 0 && !IsFakeClient(client))
	{
		// If player disconnected in <30 seconds, kill timer
		if (dodstats_info[client] != INVALID_HANDLE)
		{
			CloseHandle(dodstats_info[client]);
			dodstats_info[client] = INVALID_HANDLE;
		}

		// Save stats for a player
		SavePlayer(client);
	}
}

/* Command_Say()
 *
 * Hook the say and say_team cmds for chat triggers.
 * ----------------------------------------------------------------- */
public Action:Command_Say(client, const String:command[], argc)
{
	// Variables will start with "garbage" contents
	decl String:text[192];

	// Retrieves the entire command argument string in one lump from the current console or server command
	if (!GetCmdArgString(text, sizeof(text)))
		return Plugin_Continue;

	// Refine & safe strings
	new trigger = 0;
	if (text[strlen(text)-1] == '"')
	{
		text[strlen(text)-1] = '\0';
		trigger = 1;
	}

	// Rank triggers
	if (StrEqual(text[trigger], "rank")
	||	StrEqual(text[trigger], "!rank")
	||	StrEqual(text[trigger], "/rank"))
	{
		QueryRankStats(client);
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// Top10 triggers
	if (StrEqual(text[trigger], "top10")
	||	StrEqual(text[trigger], "!top10")
	||	StrEqual(text[trigger], "/top10"))
	{
		QueryTop10(client);

		// Arent triggers should be hidden?
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// TopGrades triggers
	if (StrEqual(text[trigger], "top")
	||  StrEqual(text[trigger], "topgrades")
	||  StrEqual(text[trigger], "!top")
	||  StrEqual(text[trigger], "!topgrades")
	||  StrEqual(text[trigger], "/top")
	||  StrEqual(text[trigger], "/topgrades"))
	{
		QueryTopGrades(client);
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// Stats triggers
	if (StrEqual(text[trigger], "stats")
	||  StrEqual(text[trigger], "statsme")
	||  StrEqual(text[trigger], "!stats")
	||  StrEqual(text[trigger], "!statsme")
	||  StrEqual(text[trigger], "/stats")
	||  StrEqual(text[trigger], "/statsme"))
	{
		QueryStats(client);
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// Session triggers
	if (StrEqual(text[trigger], "session")
	||  StrEqual(text[trigger], "!session")
	||  StrEqual(text[trigger], "/session"))
	{
		// No need to query database for session, enough to show it
		ShowSession(client);
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// Notify triggers
	if (StrEqual(text[trigger], "!notify")
	||  StrEqual(text[trigger], "/notify"))
	{
		// Enable/disable notifications
		ToggleNotify(client);
		if (GetConVarBool(dodstats_hidechat))
			return Plugin_Handled;
	}

	// Continue, otherwise plugin will block say/say_team commands
	return Plugin_Continue;
}

/* Timer_WelcomePlayer()
 *
 * Shows welcome message to a client.
 * ----------------------------------------------------------------- */
public Action:Timer_WelcomePlayer(Handle:timer, any:client)
{
	// Client is already received a message - kill timer for now
	dodstats_info[client] = INVALID_HANDLE;

	if (IsClientInGame(client))
		CPrintToChat(client, "%t", "Welcome message");
}