/* Command_Reset()
 *
 * Admin command to reset stats database.
 * --------------------------------------------------------------------- */
public Action:Command_Reset(client, args)
{
	SQL_TQuery(db, DB_CheckErrors, "DELETE FROM dod_stats");

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
 * --------------------------------------------------------------------- */
public Action:Command_DeletePlayer(client, args)
{
	if (args == 0) ReplyToCommand(client, "%t", "Delete player");
	else if (args == 1)
	{
		decl String:arg[64], String:query[128];
		GetCmdArg(1, arg, sizeof(arg));

		Format(query, sizeof(query), "DELETE FROM dod_stats WHERE steamid = '%s';", arg);
		SQL_TQuery(db, DB_CheckErrors, query);

		LogAction(client, -1, "\"%L\" have been removed \"%s\" from the database.", client, arg);

		// Notify admin about deleted steamid.
		if (client > 0) CPrintToChat(client, "%t", "Removed from database", arg);

		// Duplicates: fuck 'em.
		dod_global_player_count--;
		return Plugin_Handled;
	}
	else if (args > 1) ReplyToCommand(client, "%t", "Delete player");
	return Plugin_Handled;
}

/* Command_ShowTargetStats()
 *
 * Admin command to view target's stats.
 * --------------------------------------------------------------------- */
public Action:Command_ShowTargetStats(client, args)
{
	if (args == 0) ReplyToCommand(client, "%t", "Show target");
	else if (args == 1)
	{
		decl String:name[MAX_NAME_LENGTH];

		// If more than 1 client matches.
		if (!GetCmdArgString(name, sizeof(name)))
		{
			ReplyToCommand(client, "%t", "Show target");
			return Plugin_Handled;
		}

		new rank, target = FindTarget(client, name);

		// Target found?
		if (target > 0 && IsClientInGame(target))
		{
			// Yeah, query his stats
			QueryStats(target);

			// And show to admin
			ShowStats(client, target, rank);
		}
	}
	return Plugin_Handled;
}