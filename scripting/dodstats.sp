/**
* DoD:S Stats by Root
*
* Description:
*    A stats plugin (SQLite and MySQL) with many features, full point customization and GunGame / DeathMatch support.
*
* Version 1.9.3
* Changelog & more info at http://goo.gl/4nKhJ
*/

// ====[ INCLUDES ]==============================================================
#include <morecolors>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

// ====[ CONSTANTS ]=============================================================
#define PLUGIN_NAME    "DoD:S Stats"
#define PLUGIN_VERSION "1.9.3"

// ====[ PLUGIN ]================================================================
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
	description = "A stats with awards, captures, headshots & more",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};

/* OnMapStart()
 *
 * When the map starts.
 * ------------------------------------------------------------------------------ */
public OnMapStart()
{
	if (!sqlite)
	{
		// Update global player's count at every mapchange for servers with MySQL database only
		GetPlayerCount();
	}

	// Purge dodstats database at a every map change
	RemoveOldPlayers();
}

/* OnClientPostAdminCheck()
 *
 * When a client is in game and fully authorized.
 * ------------------------------------------------------------------------------ */
public OnClientPostAdminCheck(client)
{
	// Checking if client is valid and wasn't connected before
	if (IsValidClient(client))
	{
		if (!dod_stats_online[client])
		{
			// Load player stats or create if client wasnt found in database
			PrepareClient(client);

			// Show welcome message to a player in 30 seconds after connecting
			CreateTimer(30.0, Timer_WelcomePlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}

		// Enable stats if there is enough players on a server at the moment
		if (!roundend && GetClientCount(true) >= GetConVar[MinPlayers][Value])
		{
			rankactive = true;
		}
	}
}

/* OnClientDisconnect(client)
 *
 * When a client is disconnected from the server.
 * ------------------------------------------------------------------------------ */
public OnClientDisconnect(client)
{
	if (IsValidClient(client))
	{
		// Save stats only if client is connected before map change - otherwise database tables may broke (because stats wasnt loaded and saved in proper way)
		if (dod_stats_online[client])
		{
			SavePlayer(client);
		}
	}
}

/* OnClientSayCommand()
 *
 * When a client says something.
 * ------------------------------------------------------------------------------ */
public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (IsValidClient(client))
	{
		decl String:text[13], trigger;

		// Copy original message
		strcopy(text, sizeof(text), sArgs);

		// Remove quotes from destination string (otherwise triggers will never be detected!)
		StripQuotes(text);

		// Loop through all chars and get rid of capital chars
		for (trigger = 0; trigger < strlen(text); trigger++)
		{
			// CharToLower is already checks for IsCharUpper btw
			text[trigger] = CharToLower(text[trigger]);
		}

		// Converting is needed to compare with trie
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

			// Suppress rank messages if needed
			if (GetConVar[HideChat][Value])
				return Plugin_Handled;
		}
	}

	// Continue (otherwise plugin will block say or/and say_team commands)
	return Plugin_Continue;
}

/* Timer_WelcomePlayer()
 *
 * Shows welcome message to a client.
 * ------------------------------------------------------------------------------ */
public Action:Timer_WelcomePlayer(Handle:timer, any:client)
{
	if ((client = GetClientOfUserId(client)))
	{
		CPrintToChat(client, "%t", "Welcome message");
	}
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ----------------------------------------------------------------------------- */
bool:IsValidClient(client) return (1 <= client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client)) ? true : false;