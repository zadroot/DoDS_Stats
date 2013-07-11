/**
* DoD:S Stats by Root
*
* Description:
*    A stats plugin (SQLite & MySQL) with many features, full point customization and GunGame/DeathMatch support.
*
* Version 1.9.1
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]=============================================================
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

// ====[ CONSTANTS ]============================================================
#define PLUGIN_NAME    "DoD:S Stats"
#define PLUGIN_VERSION "1.9.1"

// ====[ PLUGIN ]===============================================================
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
	description = "A stats with awards, captures, headshots and more...",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/* OnMapStart()
 *
 * When the map starts.
 * ----------------------------------------------------------------------------- */
public OnMapStart()
{
	// Update global player's count at every mapchange for servers with MySQL database
	if (!sqlite) GetPlayerCount();

	// Purge database at every map change
	RemoveOldPlayers();
}

/* OnClientPostAdminCheck()
 *
 * Called when a client is in game and fully authorized.
 * ----------------------------------------------------------------------------- */
public OnClientPostAdminCheck(client)
{
	// Checking if client is valid (and wasn't connected before)
	if (IsValidClient(client))
	{
		if (bool:dod_stats_online[client] == false)
		{
			// Load player stats or create if client wasnt found in database
			PrepareClient(client);

			// Show stats welcome message to a player in 30 seconds after connecting
			dodstats_info[client] = CreateTimer(30.0, Timer_WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
		}

		// Enable stats if there is enough players on a server
		if (!roundend && GetClientCount(true) >= GetConVar[MinPlayers][Value])
			rankactive = true;
	}
}

/* OnClientDisconnect(client)
 *
 * When a client is disconnected from the server.
 * ----------------------------------------------------------------------------- */
public OnClientDisconnect(client)
{
	if (IsValidClient(client))
	{
		// If player disconnected in less than 30 seconds, kill timer to prevent errors
		if (dodstats_info[client] != INVALID_HANDLE)
		{
			CloseHandle(dodstats_info[client]);
			dodstats_info[client] = INVALID_HANDLE;
		}

		// Save stats only if client is connected before map change - otherwise database tables may broke (because stats wasnt loaded and saved properly)
		if (bool:dod_stats_online[client] == true) SavePlayer(client);
	}
}

/* OnSayCommand()
 *
 * Hook the say and say_team cmds for chat triggers.
 * ----------------------------------------------------------------------------- */
public Action:OnSayCommand(client, const String:command[], argc)
{
	if (IsValidClient(client))
	{
		decl String:text[13], trigger;

		// Retrieves argument string from the command (i.e. sended message)
		GetCmdArgString(text, sizeof(text));

		// Remove quotes from the argument (or triggers will never be detected)
		StripQuotes(text);

		// Convert capital chars to lower
		for (trigger = 0; trigger < strlen(text); trigger++)
		{
			if (IsCharUpper(text[trigger]))
				text[trigger] = CharToLower(text[trigger]);
		}

		// Converting is needed to compare Trie's triggers
		if (GetTrieValue(dodstats_triggers, text, trigger))
		{
			switch (trigger)
			{
				case RANK:      QueryRankStats(client);
				case STATSME:   QueryStats(client);
				case SESSION:   ShowSession(client);
				case NOTIFY:    ToggleNotify(client);
				case TOP10:     QueryTopPlayers(client, TOP_PLAYERS);
				case TOPGRADES: QueryTopGrades(client,  TOP_PLAYERS);
				case TOPGG:     QueryTopGG(client,      TOP_PLAYERS);
			}

			// Suppress chat triggers if needed
			if (GetConVar[HideChat][Value])
				return Plugin_Handled;
		}
	}

	// Continue (otherwise plugin will block say/say_team commands)
	return Plugin_Continue;
}

/* Timer_WelcomePlayer()
 *
 * Shows welcome message to a client.
 * ----------------------------------------------------------------------------- */
public Action:Timer_WelcomePlayer(Handle:timer, any:client)
{
	dodstats_info[client] = INVALID_HANDLE;
	if (IsValidClient(client)) CPrintToChat(client, "%t", "Welcome message");
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ----------------------------------------------------------------------------- */
bool:IsValidClient(client) return (client > 0 && IsClientConnected(client) && !IsFakeClient(client)) ? true : false;