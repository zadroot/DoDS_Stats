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
	SetTrieValue(dodstats_triggers, "session",  SESSION);
	SetTrieValue(dodstats_triggers, "!session", SESSION);
	SetTrieValue(dodstats_triggers, "/session", SESSION);

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
	SQL_TQuery(db, DB_CheckErrors, "DELETE FROM dodstats; VACUUM;");

	// Log action.
	LogAction(client, -1, "\"%L\" have been reset all stats.", client);

	dod_global_player_count = DEFAULT;

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
		decl String:arg[MAX_STEAMID_LENGTH],
			 String:arg_escaped[(MAX_STEAMID_LENGTH*2)+1],
			 String:query[MAX_QUERY_LENGTH];

		GetCmdArg(1, arg, sizeof(arg));
		SQL_EscapeString(db, arg, arg_escaped, sizeof(arg_escaped));

		// Make sure its STEAMID
		if (arg_escaped[5] == '_'
		&&  arg_escaped[7] == ':')
		{
			FormatEx(query, sizeof(query), "DELETE FROM dodstats WHERE steamid = '%s'", arg_escaped);
			SQL_TQuery(db, DB_CheckErrors, query);

			LogAction(client, -1, "\"%L\" have been removed \"%s\" from the database.", client, arg_escaped);

			// Notify admin about deleted steamid.
			if (IsValidClient(client))
				CReplyToCommand(client, "%t", "Removed from database", arg_escaped);

			// Duplicates: fuck 'em.
			dod_global_player_count--;
		}
		else ReplyToCommand(client, "%t", "Delete player");
	}
	else ReplyToCommand(client, "%t", "Delete player");
	return Plugin_Handled;
}