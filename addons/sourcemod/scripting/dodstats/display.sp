/* ShowInfo()
 *
 * Prints player's points & grade on connect.
 * --------------------------------------------------------------------- */
public ShowInfo(client)
{
	decl String:client_name[MAX_NAME_LENGTH];
	GetClientName(client, client_name, sizeof(client_name));

	// That's how we can define awards.
	new award;
	for (new i = 0; i < AWARDS; i++)
	{
		// Get kills & captures only for normal gameplay
		if (gameplay == 0)
		{
			if (dod_stats_captures[client] >= grade_captures[i] && dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
		else /* but DM & GG has no flags */
		{
			if (dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
	}

	// Player is ingame and fully authorized - show message to everybody!
	CPrintToChatAll("%t", "Connected stats", client_name, dod_stats_score[client], grade_names[award]);
}

/* ShowRank()
 *
 * Prints player's rank in chat.
 * --------------------------------------------------------------------- */
public ShowRank(client, rank, next_score)
{
	// No need to refine nicknames here.
	decl String:client_name[MAX_NAME_LENGTH];
	GetClientName(client, client_name, sizeof(client_name));

	// Calc points to next position
	new delta = 0;
	if (next_score > dod_stats_score[client]) delta = next_score - dod_stats_score[client];

	// Grades
	new award;
	for (new i = 0; i < AWARDS; i++)
	{
		if (gameplay == 0)
		{
			if (dod_stats_captures[client] >= grade_captures[i] && dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
		else /* I anyway want to use awards for DM & GG */
		{
			if (dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
	}

	if (delta == 0) CPrintToChatAll("%t", "First in rank", client_name, grade_names[award], dod_stats_score[client], dod_stats_kills[client]);
	else            CPrintToChatAll("%t", "Rank display",  client_name, rank, dod_global_player_count, dod_stats_score[client], delta, dod_stats_kills[client], dod_stats_deaths[client]);
}

/* ShowSession()
 *
 * Displays a current client session stats.
 * --------------------------------------------------------------------- */
public ShowSession(client)
{
	decl String:data[16], String:title[32];

	new Handle:sessioninfo = CreatePanel();

	// Translate to our phrase
	Format(title, sizeof(title), "%T:", "Session Stats", client);
	SetPanelTitle(sessioninfo, title);

	Format(title, sizeof(title), "%T", "Session points", client);

	// Show '+' if player is in actual plus.
	Format(data, sizeof(data), "%s%i", (dod_stats_session_score[client] <= 0 ? NULL_STRING : "+"), dod_stats_session_score[client]);
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	Format(title, sizeof(title), "%T", "Session kills", client);
	Format(data, sizeof(data), "%i", dod_stats_session_kills[client]);
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	Format(title, sizeof(title), "%T", "Session deaths", client);
	Format(data, sizeof(data), "%i", dod_stats_session_deaths[client]);
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	Format(title, sizeof(title), "%T", "Session headshots", client);
	Format(data, sizeof(data), "%i (%.0f%%)", dod_stats_session_headshots[client], float(dod_stats_session_headshots[client]) / (dod_stats_session_kills[client]) * 100);
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	Format(title, sizeof(title), "%T", "Session KDR", client);
	Format(data, sizeof(data), "%.2f", float(dod_stats_session_kills[client]) / (dod_stats_session_deaths[client]/*  > 0 ? float(dod_stats_session_deaths[client]) : 1.0 */));
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	// Session time.
	new g_timeplayed = (GetTime() - dod_stats_time_joined[client]);

	Format(title, sizeof(title), "%T", "Session time", client);
	Format(data, sizeof(data), "%T", "Session timestamp", client, (g_timeplayed % 86400) / 3600, (g_timeplayed % 3600) / 60);
	DrawPanelItem(sessioninfo, title);
	DrawPanelText(sessioninfo, data);

	// Display menu for 20 seconds
	SendPanelToClient(sessioninfo, client, Handler_DoNothing, 20);
	CloseHandle(sessioninfo);
}

/* ShowStats()
 *
 * Displays a stats to a client
 * --------------------------------------------------------------------- */
public ShowStats(target, client, rank)
{
	// Is client & target is valid and not a server?
	if (client > 0 && target > 0)
	{
		decl String:data[128], String:title[64], String:client_name[MAX_NAME_LENGTH];
		GetClientName(client, client_name, sizeof(client_name));

		// Creates a MenuPanel from a MenuStyle.
		new Handle:statsinfo = CreatePanel();

		// Sets the panel's title
		Format(title, sizeof(title), "%T", "Player Stats", client);
		DrawPanelItem(statsinfo, title);

		Format(data, sizeof(data), "%T", "Nickname", client, client_name);
		DrawPanelText(statsinfo, data);

		Format(data, sizeof(data), "%T", "Position", client, rank, dod_global_player_count);
		DrawPanelText(statsinfo, data);

		Format(data, sizeof(data), "%T", "Points earned", client, dod_stats_score[client]);
		DrawPanelText(statsinfo, data);

		// Overall online time.
		new g_timeplayed = dod_stats_time_played[client] + (GetTime() - dod_stats_time_joined[client]);
		Format(data, sizeof(data), "%T", "Overall timeplayed", client, g_timeplayed / 86400, (g_timeplayed % 86400) / 3600, (g_timeplayed % 3600) / 60);
		DrawPanelText(statsinfo, data);

		// Kills stats (kills/deaths/headshots/tks)
		Format(title, sizeof(title), "%T", "Kill Stats", client);
		DrawPanelItem(statsinfo, title);

		// Grade
		new award;
		for (new i = 0; i < AWARDS; i++)
		{
			if (gameplay == 0)
			{
				if (dod_stats_captures[client] >= grade_captures[i] && dod_stats_kills[client] >= grade_kills[i])
				award = i;
			}
			else /* For DM & GG we will sort grades only by kills */
			{
				if (dod_stats_kills[client] >= grade_kills[i])
				award = i;
			}
		}

		Format(data, sizeof(data), "%T", "Grade", client, grade_names[award]);
		DrawPanelText(statsinfo, data);

		Format(data, sizeof(data), "%T", "Kills & deaths", client, dod_stats_kills[client], dod_stats_deaths[client], float(dod_stats_kills[client]) / (dod_stats_deaths[client]/*  > 0 ? float(dod_stats_deaths[client]) : 1.0 */));
		DrawPanelText(statsinfo, data);

		Format(data, sizeof(data), "%T", "Overall headshots", client, dod_stats_headshots[client], float(dod_stats_headshots[client]) / (dod_stats_kills[client]) * 100);
		DrawPanelText(statsinfo, data);

		// If player have not killed any teammate (or mp_friendlyfire = 0) is not necessary to show TKs
		if (dod_stats_teamkills[client] > 0 || dod_stats_teamkilled[client] > 0)
		{
			Format(data, sizeof(data), "%T", "Teamkills & teamkilled", client, dod_stats_teamkills[client], dod_stats_teamkilled[client]);
			DrawPanelText(statsinfo, data);
		}

		// Show objective stats only for normal gameplay
		if (dod_stats_captures[client] > 0 || dod_stats_capblocks[client] > 0 || dod_stats_planted[client] > 0 || dod_stats_defused[client] > 0)
		{
			Format(title, sizeof(title), "%T", "Objective Stats", client);
			DrawPanelItem(statsinfo, title);

			if (dod_stats_captures[client] > 0)
			{
				Format(data, sizeof(data), "%T", "Captures", client, dod_stats_captures[client]);
				DrawPanelText(statsinfo, data);
			}

			if (dod_stats_capblocks[client] > 0)
			{
				Format(data, sizeof(data), "%T", "Blocked captures", client, dod_stats_capblocks[client]);
				DrawPanelText(statsinfo, data);
			}

			// If player is not planted a TNT yet - dont show
			if (dod_stats_planted[client] > 0)
			{
				Format(data, sizeof(data), "%T", "Bombs planted", client, dod_stats_planted[client]);
				DrawPanelText(statsinfo, data);
			}

			// Same about 'defused', because server may not run maps with TNT
			if (dod_stats_defused[client] > 0)
			{
				Format(data, sizeof(data), "%T", "Bombs defused", client, dod_stats_defused[client]);
				DrawPanelText(statsinfo, data);
			}
		}

		// Show GG stats
		if (gameplay == 2)
		{
			Format(title, sizeof(title), "%T", "GunGame Stats", client);
			DrawPanelItem(statsinfo, title);

			Format(data, sizeof(data), "%T", "Played & won", client, dod_stats_gg_roundsplayed[client], dod_stats_gg_roundswon[client]);
			DrawPanelText(statsinfo, data);

			Format(data, sizeof(data), "%T", "Steal & lost", client, dod_stats_gg_levelsteal[client], dod_stats_gg_leveldown[client]);
			DrawPanelText(statsinfo, data);
		}

		SendPanelToClient(statsinfo, client, Handler_DoNothing, 20);

		// If command wasnt called by client, then that was an admin
		if (client != target) SendPanelToClient(statsinfo, target, Handler_DoNothing, 20);

		// If the menu has ended, destroy it
		CloseHandle(statsinfo);
	}
}

/* ShowTop10()
 *
 * Displays top10 to a client.
 * --------------------------------------------------------------------- */
public ShowTop10(Handle:owner, Handle:handle, const String:error[], any:data)
{
	new client;
	if (handle != INVALID_HANDLE)
	{
		// Data is always zero. Stop threading if client is zero.
		if ((client = GetClientOfUserId(data)) > 0)
		{
			new row = 0, top_score, top_kills, top_deaths;

			decl String:top_name[MAX_NAME_LENGTH], String:title[32], String:buffer[TOP_PLAYERS+1][64];

			new Handle:top10 = CreatePanel();
			Format(title, sizeof(title), "%T:", "Top10", client);
			SetPanelTitle(top10, title);

			// Yay we've got a result.
			if (SQL_HasResultSet(handle))
			{
				while(SQL_FetchRow(handle))
				{
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_score = SQL_FetchInt(handle, 1);
					top_kills = SQL_FetchInt(handle, 2);
					top_deaths = SQL_FetchInt(handle, 3);

					// If there is more than 3 players in top10, but less than 10 - show their numbers (because this is a PanelText)
					if (row > 3 && row <= TOP_PLAYERS)
						Format(buffer[row], 64, "%i. %t", row, "Top10 > 3", top_name, float(top_kills) / (top_deaths == 0 ? 1.0 : float(top_deaths)), top_score);
					else if (row <= TOP_PLAYERS)
						Format(buffer[row], 64, "%t", "Top10 stats", top_name, float(top_kills) / (top_deaths == 0 ? 1.0 : float(top_deaths)), top_score);
				}
				if (row > TOP_PLAYERS)
					row = TOP_PLAYERS;

				for (new i = 1; i <= row; i++)
				{
					/* Draws a raw line of text on a panel, without any markup other than a newline. */
					if (i > 3) DrawPanelText(top10, buffer[i]);

					/* Draws an item on a panel. */
					else DrawPanelItem(top10, buffer[i]);
				}
			}
			SendPanelToClient(top10, client, Handler_DoNothing, 20);
			CloseHandle(top10);
		}
	}
	else LogError("Top10 command error: %s", error);
}

/* ShowTopGrades()
 *
 * Displays topgrades to a client.
 * --------------------------------------------------------------------- */
public ShowTopGrades(Handle:owner, Handle:handle, const String:error[], any:data)
{
	new client;
	if (handle != INVALID_HANDLE)
	{
		if ((client = GetClientOfUserId(data)) > 0)
		{
			new row = 0, top_flags, top_kills;
			decl String:top_name[MAX_NAME_LENGTH], String:title[48], String:buffer[TOP_PLAYERS+1][96];

			new Handle:top10_awards = CreatePanel();
			Format(title, sizeof(title), "%T:", "TopGrades", client);
			SetPanelTitle(top10_awards, title);

			if (SQL_HasResultSet(handle))
			{
				while(SQL_FetchRow(handle))
				{
					// Parse rows
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_flags = SQL_FetchInt(handle, 1);
					top_kills = SQL_FetchInt(handle, 2);

					// Grades
					decl award;
					for (new i = 0; i < AWARDS; i++)
					{
						if (gameplay == 0)
						{
							if (top_flags >= grade_captures[i] && top_kills >= grade_kills[i])
							award = i;
						}
						else
						{
							if (top_kills >= grade_kills[i])
							award = i;
						}
					}

					if (row > 3 && row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%i. %t", row, "TopGrades > 3", top_name, grade_names[award], top_kills);
					/* If there is less than 10 players AND less than 3 - dont show numbers, because this is PanelItem. */
					else if (row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%t", "TopGrades stats", top_name, grade_names[award], top_kills);
				}
				// Is good if there is more than 10 players stored in database, but we gonna show only 10!
				if (row > TOP_PLAYERS)
					row = TOP_PLAYERS;

				for (new i = 1; i <= row; i++)
				{
					if (i > 3) DrawPanelText(top10_awards, buffer[i]);
					else DrawPanelItem(top10_awards, buffer[i]);
				}
			}
			// That means that if the client does not select an item within 20 seconds, the menu will be canceled.
			SendPanelToClient(top10_awards, client, Handler_DoNothing, 20);

			// Make sure we close the file!
			CloseHandle(top10_awards);
		}
	}
	else LogError("TopGrades command error: %s", error);
}

/* Handler_DoNothing()
 *
 * Called when a menu action is completed.
 * --------------------------------------------------------------------- */
public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2){}