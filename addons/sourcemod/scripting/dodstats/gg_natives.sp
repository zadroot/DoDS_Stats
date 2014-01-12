/* OnLevelDown()
 *
 * Called when player is losing a level.
 * ----------------------------------------------------------------- */
public Action:OnLevelDown(client)
{
	if (IsValidClient(client))
	{
		dod_stats_gg_leveldown[client]++;

		new ldpoints = GetConVar[GG_LevelDown][Value];
		if (ldpoints)
		{
			dod_stats_score[client]         -= ldpoints;
			dod_stats_session_score[client] -= ldpoints;

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Level down", color, ldpoints);
			}
		}
	}
}

/* OnLevelSteal()
 *
 * Called when player is stealing a level.
 * ----------------------------------------------------------------- */
public Action:OnLevelSteal(client)
{
	if (IsValidClient(client))
	{
		dod_stats_gg_levelup[client]++;

		new lspoints = GetConVar[GG_LevelSteal][Value];
		if (lspoints)
		{
			dod_stats_score[client]         += lspoints;
			dod_stats_session_score[client] += lspoints;

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Level up", lspoints, color);
			}
		}
	}
}

/* OnGGWin()
 *
 * Called when player is winning a GunGame round.
 * ----------------------------------------------------------------- */
public Action:OnGGWin(winner)
{
	if (IsValidClient(winner))
	{
		// Client won the round - save it to database.
		dod_stats_gg_roundswon[winner]++;

		// Write Roundsplayed into database for all ingame players.
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client))
			{
				dod_stats_gg_roundsplayed[client]++;
			}
		}

		// Check points for victory.
		new lwponits = GetConVar[GG_RoundWin][Value];
		if (lwponits)
		{
			// And encourage.
			dod_stats_score[winner]         += lwponits;
			dod_stats_session_score[winner] += lwponits;

			// And notify winner!
			if (dod_stats_client_notify[winner])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(winner) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(winner, "%t", "GunGame victory", color, lwponits);
			}
		}
	}
}