/**
* DoD:S Stats by Root
*
* Description:
*    A stats plugin (SQLite & MySQL) with many features, full point customization and GunGame/DeathMatch support.
*
* Version 1.9
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]==================================================================
#include <sourcemod>

// Added: 1.8
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

// ====[ CONSTANTS ]=================================================================
#define PLUGIN_NAME    "DoD:S Stats"
#define PLUGIN_VERSION "1.9"

// ====[ PLUGIN ]====================================================================
#include "dodstats/init.sp"
#include "dodstats/pluginstart.sp"
#include "dodstats/convars.sp"
#include "dodstats/database.sp"
#include "dodstats/display.sp"
#include "dodstats/commands.sp"
#include "dodstats/events.sp"
#include "dodstats/gg_natives.sp"

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
 * ---------------------------------------------------------------------------------- */
public OnMapStart()
{
	// Update global player count at every mapchange for servers with MySQL database
	if (!sqlite) GetPlayerCount();

	// Get previous connects of all players from a database and remove inactives
	RemoveOldPlayers();
}

/* OnClientPutInServer()
 *
 * Called when a client is entering the game.
 * ---------------------------------------------------------------------------------- */
public OnClientPutInServer(client)
{
	// Checking if client is valid and wasn't online before
	if (IsValidClient(client))
	{
		if (bool:dod_stats_online[client] == false)
		{
			// Load or create client stats
			PrepareClient(client);

			// Show welcome message to a player in 30 seconds after connecting
			dodstats_info[client] = CreateTimer(30.0, Timer_WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
		}

		// Enable stats if there is enough players on a server
		if (!roundend && GetClientCount(true) >= GetConVar[MinPlayers][Value])
			rankactive = true;
	}
}

/* OnClientDisconnect(client)
 *
 * When a client disconnects from the server.
 * ---------------------------------------------------------------------------------- */
public OnClientDisconnect(client)
{
	// Once again check if player is valid
	if (IsValidClient(client))
	{
		// If player disconnected in <30 seconds - kill timer to prevent errors
		if (dodstats_info[client] != INVALID_HANDLE)
		{
			CloseHandle(dodstats_info[client]);
			dodstats_info[client] = INVALID_HANDLE;
		}

		// Save stats only if client is connected before map change! Otherwise database tables may be corrupted (because stats wasnt loaded well and saved in same way)
		if (bool:dod_stats_online[client] == true)
		{
			// Save stats for a player
			SavePlayer(client);
		}
	}
}

/* OnSayCommand()
 *
 * Hook the say and say_team cmds for chat triggers.
 * ---------------------------------------------------------------------------------- */
public Action:OnSayCommand(client, const String:command[], argc)
{
	// Get the message
	decl String:text[13], index;

	// Retrieves the entire command argument string in one lump from the message
	GetCmdArgString(text, sizeof(text));

	// Remove quotes from the argument (otherwise triggers will never be detected)
	StripQuotes(text);

	// Get triggers value from trie
	if (GetTrieValue(dodstats_triggers, text, index))
	{
		// Get trie index, and do action depends on defined trigger
		switch (index)
		{
			case RANK:      QueryRankStats(client);
			case STATSME:   QueryStats(client);
			case SESSION:   ShowSession(client);
			case NOTIFY:    ToggleNotify(client);
			case TOP10:     QueryTopPlayers(client, TOP_PLAYERS);
			case TOPGRADES: QueryTopGrades(client,  TOP_PLAYERS);
			case TOPGG:     QueryTopGG(client,      TOP_PLAYERS);
		}

		// Arent triggers should be hidden?
		if (GetConVar[HideChat][Value])
			return Plugin_Handled;
	}

	// Continue (otherwise plugin will block say/say_team commands)
	return Plugin_Continue;
}

/* Timer_WelcomePlayer()
 *
 * Shows welcome message to a client.
 * ---------------------------------------------------------------------------------- */
public Action:Timer_WelcomePlayer(Handle:timer, any:client)
{
	// Client is already received a message - kill timer for now
	dodstats_info[client] = INVALID_HANDLE;
	if (IsClientInGame(client)) CPrintToChat(client, "%t", "Welcome message");
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ---------------------------------------------------------------------------------- */
bool:IsValidClient(client) return (client > 0 && !IsFakeClient(client)) ? true : false;