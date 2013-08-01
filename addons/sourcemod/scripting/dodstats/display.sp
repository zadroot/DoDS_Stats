/* ShowInfo()
 *
 * Prints player's points & grade on connect.
 * ----------------------------------------------------------------- */
ShowInfo(client)
{
	// That's how we can define awards.
	decl i, award, String:grade[64];
	for (i = 0; i < sizeof(grade_names); i++)
	{
		// DM has no flags
		if (gameplay)
		{
			if (dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
		else /* Get kills & captures only for normal gameplay */
		{
			if (dod_stats_captures[client] >= grade_captures[i] && dod_stats_kills[client] >= grade_kills[i])
			award = i;
		}
	}

	Format(grade, sizeof(grade), "%t", grade_names[award]);

	// Player is ingame and fully authorized - show message to everybody!
	CPrintToChatAll("%t", "Connected stats", client, dod_stats_score[client], grade);
}

/* ShowRank()
 *
 * Prints player's rank in chat.
 * ----------------------------------------------------------------- */
ShowRank(client, rank, next_score)
{
	decl i, award, String:grade[64], String:color[10];
	FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");

	// Calc points to next position
	new delta, score = dod_stats_score[client], kills = dod_stats_kills[client];
	if (next_score > score) delta = next_score - score;

	// Grades
	for (i = 0; i < sizeof(grade_names); i++)
	{
		if (gameplay)
		{
			if (kills >= grade_kills[i])
			award = i;
		}
		else
		{
			if (dod_stats_captures[client] >= grade_captures[i] && kills >= grade_kills[i])
			award = i;
		}
	}

	// Translate grade string
	Format(grade, sizeof(grade), "%t", grade_names[award]);

	if (!delta) CPrintToChatAll("%t", "First in rank", color, client, grade, score, kills);
	else        CPrintToChatAll("%t", "Rank display",  color, client, rank,  dod_global_player_count, score, delta, kills, dod_stats_deaths[client]);
}

/* ShowSession()
 *
 * Displays a current client session stats.
 * ----------------------------------------------------------------- */
ShowSession(client)
{
	decl String:data[16], String:title[32];

	new Handle:session = CreatePanel();

	new score      = dod_stats_session_score[client];
	new kills      = dod_stats_session_kills[client];
	new deaths     = dod_stats_session_deaths[client];
	new headshots  = dod_stats_session_headshots[client];
	new timeplayed = (GetTime() - dod_stats_time_joined[client]);

	// Translate to our phrase
	Format(title, sizeof(title), "%T:", "Session Stats", client);
	SetPanelTitle(session, title);

	Format(title, sizeof(title), "%T", "Session points", client);

	// Show '+' if player is in actual plus.
	Format(data, sizeof(data), "%s%i", (score <= 0 ? NULL_STRING : "+"), score);
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	Format(title, sizeof(title), "%T", "Session kills", client);
	FormatEx(data, sizeof(data), "%i", kills);
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	Format(title, sizeof(title), "%T", "Session deaths", client);
	FormatEx(data, sizeof(data), "%i", deaths);
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	Format(title, sizeof(title), "%T", "Session headshots", client);
	FormatEx(data, sizeof(data), "%i (%.0f%%)", headshots, FloatDiv(float(headshots), float(kills)) * 100.0);
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	Format(title, sizeof(title), "%T", "Session KDR", client);
	FormatEx(data, sizeof(data), "%.2f", FloatDiv(float(kills), float((deaths == 0)?1:deaths)));
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	Format(title, sizeof(title), "%T", "Session time", client);
	Format(data, sizeof(data), "%T", "Session timestamp", client, (timeplayed % 86400) / 3600, (timeplayed % 3600) / 60);
	DrawPanelItem(session, title);
	DrawPanelText(session, data);

	// Display menu for 20 seconds
	SendPanelToClient(session, client, Handler_DoNothing, MENU_TIME_FOREVER);
	CloseHandle(session);
}

/* ShowStats()
 *
 * Displays a stats to a client
 * ----------------------------------------------------------------- */
ShowStats(client, rank)
{
	decl i, award, String:data[128], String:title[64], String:grade[64];

	// Creates a MenuPanel from a MenuStyle.
	new Handle:stats = CreatePanel();

	new score      = dod_stats_score[client];
	new kills      = dod_stats_kills[client];
	new deaths     = dod_stats_deaths[client];
	new headshots  = dod_stats_headshots[client];
	new captures   = dod_stats_captures[client];

	new timeplayed = dod_stats_time_played[client] + (GetTime() - dod_stats_time_joined[client]);

	// Sets the panel's title
	Format(title, sizeof(title), "%T", "Player Stats", client);
	DrawPanelItem(stats, title);

	Format(data, sizeof(data), "%T", "Nickname", client, client);
	DrawPanelText(stats, data);

	Format(data, sizeof(data), "%T", "Position", client, rank, dod_global_player_count);
	DrawPanelText(stats, data);

	Format(data, sizeof(data), "%T", "Points earned", client, score);
	DrawPanelText(stats, data);

	// Overall online time.
	Format(data, sizeof(data), "%T", "Overall timeplayed", client, timeplayed / 86400, (timeplayed % 86400) / 3600, (timeplayed % 3600) / 60);
	DrawPanelText(stats, data);

	// Kills stats (kills/deaths/headshots/tks)
	Format(title, sizeof(title), "%T", "Kill Stats", client);
	DrawPanelItem(stats, title);

	// Grade
	for (i = 0; i < sizeof(grade_names); i++)
	{
		if (gameplay)
		{
			if (kills >= grade_kills[i])
			award = i;
		}
		else /* For DM we will sort grades only by kills */
		{
			if (captures >= grade_captures[i] && kills >= grade_kills[i])
			award = i;
		}
	}

	Format(grade, sizeof(grade), "%t", grade_names[award]);
	Format(data, sizeof(data), "%T", "Grade", client, grade);
	DrawPanelText(stats, data);

	Format(data, sizeof(data), "%T", "Kills & deaths", client, kills, deaths, FloatDiv(float(kills), float((deaths == 0)?1:deaths)));
	DrawPanelText(stats, data);

	Format(data, sizeof(data), "%T", "Accuracy", client, FloatDiv(float(dod_stats_weaponhits[client]), float(dod_stats_weaponshots[client])) * 100.0);
	DrawPanelText(stats, data);

	Format(data, sizeof(data), "%T", "Overall headshots", client, headshots, FloatDiv(float(headshots), float(kills)) * 100.0);
	DrawPanelText(stats, data);

	// If player have not killed any teammate (or mp_friendlyfire = 0) is not necessary to show TKs
	if (dod_stats_teamkills[client]
	|| dod_stats_teamkilled[client])
	{
		Format(data, sizeof(data), "%T", "Teamkills & teamkilled", client, dod_stats_teamkills[client], dod_stats_teamkilled[client]);
		DrawPanelText(stats, data);
	}

	if (gameplay == GUNGAME)
	{
		new roundsplayed = dod_stats_gg_roundsplayed[client];
		new roundswon    = dod_stats_gg_roundswon[client];
		new levelsup     = dod_stats_gg_levelup[client];
		new levelsdown   = dod_stats_gg_leveldown[client];

		Format(title, sizeof(title), "%T", "GunGame Stats", client);
		DrawPanelItem(stats, title);

		Format(data, sizeof(data), "%T", "Played & won", client, roundsplayed, roundswon, FloatDiv(float(roundswon), float((roundsplayed == 0)?1:roundsplayed)));
		DrawPanelText(stats, data);

		Format(data, sizeof(data), "%T", "Steal & lost", client, levelsup, levelsdown, FloatDiv(float(levelsup), float((levelsdown == 0)?1:levelsdown)));
		DrawPanelText(stats, data);
	}

	// Show objective stats only for normal gameplay
	else if (gameplay == DEFAULT)
	{
		new capblocks = dod_stats_capblocks[client];
		new planted   = dod_stats_planted[client];
		new defused   = dod_stats_defused[client];

		if (captures || capblocks || planted || defused)
		{
			Format(title, sizeof(title), "%T", "Objective Stats", client);
			DrawPanelItem(stats, title);

			if (captures)
			{
				Format(data, sizeof(data), "%T", "Captures", client, captures);
				DrawPanelText(stats, data);
			}

			if (capblocks)
			{
				Format(data, sizeof(data), "%T", "Blocked captures", client, capblocks);
				DrawPanelText(stats, data);
			}

			// If player is not planted a TNT yet - dont show
			if (planted)
			{
				Format(data, sizeof(data), "%T", "Bombs planted", client, planted);
				DrawPanelText(stats, data);
			}

			// Same about 'defused', because server may not run maps with TNT
			if (defused)
			{
				Format(data, sizeof(data), "%T", "Bombs defused", client, defused);
				DrawPanelText(stats, data);
			}
		}
	}

	SendPanelToClient(stats, client, Handler_DoNothing, MENU_TIME_FOREVER);

	// If the menu has ended, destroy it
	CloseHandle(stats);
}

/* ShowTop10()
 *
 * Displays top10 to a client.
 * ----------------------------------------------------------------- */
public ShowTop10(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client, row;

		// Data is always zero. Stop threading if client is zero.
		if ((client = GetClientOfUserId(data)))
		{
			decl top_score, top_kills, top_deaths, String:top_name[MAX_NAME_LENGTH], String:title[32], String:buffer[TOP_PLAYERS + 1][64];

			new Handle:top10 = CreatePanel();
			Format(title, sizeof(title), "%T:", "Top10", client);
			SetPanelTitle(top10, title);

			// Yay we've got a result.
			if (SQL_HasResultSet(handle))
			{
				while (SQL_FetchRow(handle))
				{
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_score  = SQL_FetchInt(handle, 1);
					top_kills  = SQL_FetchInt(handle, 2);
					top_deaths = SQL_FetchInt(handle, 3);

					// If there is more than 3 players in top10, but less than 10 - show their numbers (because this is a PanelText)
					if (row > 3 && row <= TOP_PLAYERS)
						Format(buffer[row], 64, "%i. %t", row, "Top10 > 3", top_name, FloatDiv(float(top_kills), float((top_deaths == 0)?1:top_deaths)), top_score);
					else if (row <= TOP_PLAYERS)
						Format(buffer[row], 64, "%t", "Top10 stats",        top_name, FloatDiv(float(top_kills), float((top_deaths == 0)?1:top_deaths)), top_score);
				}
				if (row > TOP_PLAYERS)
					row = TOP_PLAYERS;

				// i = 1
				for (new i = 1; i <= row; i++)
				{
					/* Draws a raw line of text on a panel, without any markup other than a newline. */
					if (i > 3) DrawPanelText(top10, buffer[i]);

					/* Draws an item on a panel. */
					else DrawPanelItem(top10, buffer[i]);
				}
			}

			SendPanelToClient(top10, client, Handler_DoNothing, MENU_TIME_FOREVER);
			CloseHandle(top10);
		}
	}
	else LogError("Top10 command error: %s", error);
}

/* ShowTopGrades()
 *
 * Displays topgrades to a client.
 * ----------------------------------------------------------------- */
public ShowTopGrades(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client, row;
		if ((client = GetClientOfUserId(data)))
		{
			decl i, award, top_flags, top_kills, String:top_name[MAX_NAME_LENGTH], String:grade[64], String:title[48], String:buffer[TOP_PLAYERS + 1][96];

			new Handle:top10_awards = CreatePanel();
			Format(title, sizeof(title), "%T:", "TopGrades", client);
			SetPanelTitle(top10_awards, title);

			if (SQL_HasResultSet(handle))
			{
				while (SQL_FetchRow(handle))
				{
					// Parse rows
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_flags = SQL_FetchInt(handle, 1);
					top_kills = SQL_FetchInt(handle, 2);

					// Grades
					for (i = 0; i < sizeof(grade_names); i++)
					{
						if (gameplay)
						{
							if (top_kills >= grade_kills[i])
							award = i;
						}
						else
						{
							if (top_flags >= grade_captures[i] && top_kills >= grade_kills[i])
							award = i;
						}
					}

					Format(grade, sizeof(grade), "%t", grade_names[award]);

					if (row > 3 && row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%i. %t", row, "TopGrades > 3", top_name, grade, top_kills);
					/* If there is less than 10 players AND less than 3 - dont show numbers, because this is PanelItem. */
					else if (row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%t", "TopGrades stats",        top_name, grade, top_kills);
				}
				// Is good if there is more than 10 players stored in database, but we gonna show only 10!
				if (row > TOP_PLAYERS)
					row = TOP_PLAYERS;

				for (new j = 1; j <= row; j++)
				{
					if (j > 3) DrawPanelText(top10_awards, buffer[j]);
					else DrawPanelItem(top10_awards, buffer[j]);
				}
			}
			// That means that if the client does not select an item within 20 seconds, the menu will be canceled.
			SendPanelToClient(top10_awards, client, Handler_DoNothing, MENU_TIME_FOREVER);

			// Make sure we close the file!
			CloseHandle(top10_awards);
		}
	}
	else LogError("TopGrades command error: %s", error);
}

/* ShowTopGG()
 *
 * Displays topgg to a client.
 * ----------------------------------------------------------------- */
public ShowTopGG(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client, row;

		// Data is always zero. Stop threading if client is zero.
		if ((client = GetClientOfUserId(data)))
		{
			decl top_wins, top_steal, String:top_name[MAX_NAME_LENGTH], String:title[32], String:buffer[TOP_PLAYERS + 1][64];

			new Handle:topGG = CreatePanel();
			Format(title, sizeof(title), "%T:", "TopGG", client);
			SetPanelTitle(topGG, title);

			// Yay we've got a result.
			if (SQL_HasResultSet(handle))
			{
				while (SQL_FetchRow(handle))
				{
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_wins  = SQL_FetchInt(handle, 1);
					top_steal = SQL_FetchInt(handle, 2);

					if (row > 3 && row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%i. %t", row, "TopGG > 3", top_name, top_wins, top_steal);
					/* If there is less than 10 players AND less than 3 - dont show numbers, because this is PanelItem. */
					else if (row <= TOP_PLAYERS)
						Format(buffer[row], 96, "%t", "TopGG stats",        top_name, top_wins, top_steal);
				}
				// Is good if there is more than 10 players stored in database, but we gonna show only 10!
				if (row > TOP_PLAYERS)
					row = TOP_PLAYERS;

				for (new i = 1; i <= row; i++)
				{
					if (i > 3) DrawPanelText(topGG, buffer[i]);
					else DrawPanelItem(topGG, buffer[i]);
				}
			}
			SendPanelToClient(topGG, client, Handler_DoNothing, MENU_TIME_FOREVER);
			CloseHandle(topGG);
		}
	}
	else LogError("topGG command error: %s", error);
}

/* Handler_DoNothing()
 *
 * Called when a menu action is completed.
 * ----------------------------------------------------------------- */
public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2){}

/* public ShowTop10(Handle:owner, Handle:handle, const String:error[], any:data)
{
	if (handle != INVALID_HANDLE)
	{
		new client, row;

		if ((client = GetClientOfUserId(data)))
		{
			decl top_score, top_kills, top_deaths, String:top_name[MAX_NAME_LENGTH], String:title[32], String:translate[32], String:buffer[TOP_PLAYERS + 1][64];

			new Handle:top10 = CreatePanel();
			Format(title, sizeof(title), "%T:", "Top", client);
			SetPanelTitle(top10, title);

			if (SQL_HasResultSet(handle))
			{
				while (SQL_FetchRow(handle))
				{
					row++;
					SQL_FetchString(handle, 0, top_name, sizeof(top_name));
					top_score  = SQL_FetchInt(handle, 1);
					top_kills  = SQL_FetchInt(handle, 2);
					top_deaths = SQL_FetchInt(handle, 3);

					//if (row > 3 && row <= TOP_PLAYERS)
					Format(buffer[row], 64, "%i. %t", row + dod_stats_top_page[client] * TOP_PLAYERS, "Top > 3", top_name, float(top_kills) / (top_deaths == 0 ? 1.0 : float(top_deaths)), top_score);
					//else if (row <= TOP_PLAYERS)
						//Format(buffer[row], 64, "%t", "Top stats", top_name, float(top_kills) / (top_deaths == 0 ? 1.0 : float(top_deaths)), top_score);
				}

				Format(translate, sizeof(translate), "%T", "Next", client);
				DrawPanelItem(top10, translate);
				SetPanelCurrentKey(top10, 1);

				for (new i = 1; i <= row; i++)
				{
					DrawPanelText(top10, buffer[i]);
				}

				if (dod_stats_top_page[client])
				{
					Format(translate, sizeof(translate), "%T", "Previous", client);
					DrawPanelItem(top10, translate);
					SetPanelCurrentKey(top10, 2);
				}

				DrawPanelItem(top10, NULL_STRING, ITEMDRAW_SPACER);

				Format(translate, sizeof(translate), "%T", "Exit", client);
				SetPanelCurrentKey(top10, TOP_PLAYERS);
				DrawPanelItem(top10, translate, ITEMDRAW_CONTROL);

				SendPanelToClient(top10, client, Menu_Top10, 20);
			}
		}
	}
	else LogError("Top command error: %s", error);
}

public Menu_Top10(Handle:menu, MenuAction:action, client, param)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param)
			{
				case 1:
				{
					dod_stats_top_page[client]++;
					QueryTopPlayers(client, dod_stats_top_page[client] * TOP_PLAYERS);
				}
				case 2:
				{
					dod_stats_top_page[client]--;

					if (dod_stats_top_page[client] == 1)
						 QueryTopPlayers(client, TOP_PLAYERS);
					else QueryTopPlayers(client, dod_stats_top_page[client] * TOP_PLAYERS);
				}
			}
		}
		case MenuAction_End: CloseHandle(menu);
    }
} */