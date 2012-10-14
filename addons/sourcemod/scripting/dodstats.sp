/**
* DoD:S Stats by Root
*
* Description:
*    A stats plugin (SQLite/MySQL) with many features, full point customization and GunGame/DeathMatch support.
*
* Version 1.6
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]=================================================
#include <sourcemod>
#include <colors>

// ====[ CONSTANTS ]================================================
#define PLUGIN_NAME        "DoD:S Stats"
#define PLUGIN_AUTHOR      "Root"
#define PLUGIN_DESCRIPTION "A stats with awards, captures, headshots & more..."
#define PLUGIN_VERSION     "1.6"
#define PLUGIN_CONTACT     "http://www.dodsplugins.com/"

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
	author      = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version     = PLUGIN_VERSION,
	url         = PLUGIN_CONTACT
};


/* OnMapStart()
 *
 * When the map starts.
 * ------------------------------------------------------------------ */
public OnMapStart()
{
	// Update global player count at every mapchange for servers with MySQL database
	if (!sqlite) GetPlayerCount();
}

/* OnClientPutInServer()
 *
 * Called when a client is entering the game.
 * ------------------------------------------------------------------ */
public OnClientPutInServer(client)
{
	// Take player stats if database is ok
	if (db != INVALID_HANDLE)
	{
		// Checking if client is valid and not a bot
		if (client > 0 && !IsFakeClient(client))
		{
			PrepareClient(client);

			// Show welcome message to a player
			dodstats_info[client] = CreateTimer(30.0, Timer_WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

/* OnClientDisconnect(client)
 *
 * When a client disconnects from the server.
 * ------------------------------------------------------------------ */
public OnClientDisconnect(client)
{
	// Once again check if player is valid
	if (client > 0 && !IsFakeClient(client))
	{
		// Is player disconnected in <30 seconds? kill timer
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
 * ------------------------------------------------------------------ */
public Action:Command_Say(client, const String:command[], argc)
{
	decl String:text[192];

	if (!GetCmdArgString(text, sizeof(text))) return Plugin_Continue;

	new trigger = 0;
	if (text[strlen(text)-1] == '"')
	{
		text[strlen(text)-1] = '\0';
		trigger = 1;
	}

	// Rank triggers
	if (strcmp(text[trigger], "rank") == 0 || strcmp(text[trigger], "!rank") == 0 || strcmp(text[trigger], "/rank") == 0)
	{
		QueryRankStats(client);
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}
	// Top10 triggers
	else if (strcmp(text[trigger], "top10") == 0 || strcmp(text[trigger], "!top10") == 0 || strcmp(text[trigger], "/top10") == 0)
	{
		QueryTop10(client); /* Aren't triggers should be hidden? */
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}
	// TopGrades triggers
	else if (strcmp(text[trigger], "top") == 0 || strcmp(text[trigger], "!top") == 0 || strcmp(text[trigger], "/top") == 0 || strcmp(text[trigger], "topgrades") == 0 || strcmp(text[trigger], "!topgrades") == 0 || strcmp(text[trigger], "/topgrades") == 0)
	{
		QueryTopGrades(client);
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}
	// Stats triggers
	else if (strcmp(text[trigger], "stats") == 0 || strcmp(text[trigger], "statsme") == 0 || strcmp(text[trigger], "!stats") == 0 || strcmp(text[trigger], "!statsme") == 0 || strcmp(text[trigger], "/stats") == 0 || strcmp(text[trigger], "/statsme") == 0)
	{
		QueryStats(client);
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}
	// Session triggers
	else if (strcmp(text[trigger], "session") == 0 || strcmp(text[trigger], "!session") == 0 || strcmp(text[trigger], "/session") == 0)
	{
		// No need to query database for session, enough to show it
		ShowSession(client);
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}
	// Notify triggers
	else if (strcmp(text[trigger], "notify") == 0 || strcmp(text[trigger], "!notify") == 0 || strcmp(text[trigger], "/notify") == 0)
	{
		// Enable or disable notify
		ToggleNotify(client);
		if (GetConVarBool(dodstats_hidechat)) return Plugin_Handled;
	}

	return Plugin_Continue;
}

/* Timer_WelcomePlayer()
 *
 * Shows welcome message to a client.
 * ------------------------------------------------------------------ */
public Action:Timer_WelcomePlayer(Handle:timer, any:client)
{
	// Client is already received a message - kill timer
	dodstats_info[client] = INVALID_HANDLE;
	if (IsClientInGame(client)) CPrintToChat(client, "%t", "Welcome message");
}