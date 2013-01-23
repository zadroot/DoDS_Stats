/* CreateTriggersTrie()
 *
 * Creates a Trie structure for chat triggers.
 * ----------------------------------------------------------------- */
CreateTriggersTrie()
{
	dodstats_triggers = CreateTrie();

	// Rank triggers
	SetTrieValue(dodstats_triggers, "rank",  RANK);
	SetTrieValue(dodstats_triggers, "!rank", RANK);
	SetTrieValue(dodstats_triggers, "/rank", RANK);

	// Stats triggers
	SetTrieValue(dodstats_triggers, "stats",    STATSME);
	SetTrieValue(dodstats_triggers, "statsme",  STATSME);
	SetTrieValue(dodstats_triggers, "!stats",   STATSME);
	SetTrieValue(dodstats_triggers, "!statsme", STATSME);
	SetTrieValue(dodstats_triggers, "/stats",   STATSME);
	SetTrieValue(dodstats_triggers, "/statsme", STATSME);

	// No need to query database for session - enough to show it
	SetTrieValue(dodstats_triggers, "session",   SESSION);
	SetTrieValue(dodstats_triggers, "!sesssion", SESSION);
	SetTrieValue(dodstats_triggers, "/session",  SESSION);

	// Enable/disable notifications on trigger match
	SetTrieValue(dodstats_triggers, "notify",  NOTIFY);
	SetTrieValue(dodstats_triggers, "!notify", NOTIFY);
	SetTrieValue(dodstats_triggers, "/notify", NOTIFY);

	// Top10 triggers
	SetTrieValue(dodstats_triggers, "top",    TOP10);
	SetTrieValue(dodstats_triggers, "top10",  TOP10);
	SetTrieValue(dodstats_triggers, "!top",   TOP10);
	SetTrieValue(dodstats_triggers, "!top10", TOP10);
	SetTrieValue(dodstats_triggers, "/top",   TOP10);
	SetTrieValue(dodstats_triggers, "/top10", TOP10);

	// TopGrades triggers
	// Renamed 'top' to 'topkills' for grades
	SetTrieValue(dodstats_triggers, "topgrades",  TOPGRADES);
	SetTrieValue(dodstats_triggers, "topkills",   TOPGRADES);
	SetTrieValue(dodstats_triggers, "!topgrades", TOPGRADES);
	SetTrieValue(dodstats_triggers, "!topkills",  TOPGRADES);
	SetTrieValue(dodstats_triggers, "/topgrades", TOPGRADES);
	SetTrieValue(dodstats_triggers, "/topkills",  TOPGRADES);

	// TopGG triggers
	// Working only with gungame 4.2 and above
	SetTrieValue(dodstats_triggers, "topgg",  TOPGG);
	SetTrieValue(dodstats_triggers, "!topgg", TOPGG);
	SetTrieValue(dodstats_triggers, "/topgg", TOPGG);
}

/* Command_Reset()
 *
 * Admin command to reset stats database.
 * ----------------------------------------------------------------- */
public Action:Command_Reset(client, args)
{
	SQL_TQuery(db, DB_CheckErrors, "DELETE FROM dodstats");

	// Log action.
	LogAction(client, -1, "\"%L\" have been reset all stats.", client);

	dod_global_player_count = 0;

	// Print message to all clients
	CPrintToChatAll("%t", "Stats have been reset");
	return Plugin_Handled;
}

/* Command_DeletePlayer()
 *
 * Admin command to delete player from database.
 * ----------------------------------------------------------------- */
public Action:Command_DeletePlayer(client, args)
{
	if (args == 1)
	{
		decl String:arg[MAX_STEAMID_LENGTH], String:query[128];
		GetCmdArg(1, arg, sizeof(arg));

		Format(query, sizeof(query), "DELETE FROM dodstats WHERE steamid = '%s'", arg);
		SQL_TQuery(db, DB_CheckErrors, query);

		LogAction(client, -1, "\"%L\" have been removed \"%s\" from the database.", client, arg);

		// Notify admin about deleted steamid.
		if (client > 0) CReplyToCommand(client, "%t", "Removed from database", arg);

		// Duplicates: fuck 'em.
		dod_global_player_count--;
		return Plugin_Handled;
	}
	else ReplyToCommand(client, "%t", "Delete player");
	return Plugin_Handled;
}