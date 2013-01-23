/* OnLevelDown()
 *
 * Called when player is losing a level.
 * ----------------------------------------------------------------- */
public Action:OnLevelDown(client)
{
	if (IsValidClient(client))
	{
		decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");

		dod_stats_gg_leveldown[client]++;

		if (GetConVar[GG_LevelDown][Value])
		{
			dod_stats_score[client]         -= GetConVar[GG_LevelDown][Value];
			dod_stats_session_score[client] -= GetConVar[GG_LevelDown][Value];

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Level down", color, GetConVar[GG_LevelDown][Value]);
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
		decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");

		dod_stats_gg_levelup[client]++;

		if (GetConVar[GG_LevelSteal][Value])
		{
			dod_stats_score[client]         += GetConVar[GG_LevelSteal][Value];
			dod_stats_session_score[client] += GetConVar[GG_LevelSteal][Value];

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Level up", GetConVar[GG_LevelSteal][Value], color);
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
		decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(winner) == 2 ? "{allies}" : "{axis}");

		// Client won the round - save it to database.
		dod_stats_gg_roundswon[winner]++;

		// Write Roundsplayed into database for all ingame players.
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				dod_stats_gg_roundsplayed[client]++;
			}
		}

		// Check points for victory.
		if (GetConVar[GG_RoundWin][Value])
		{
			// And encourage.
			dod_stats_score[winner]         += GetConVar[GG_RoundWin][Value];
			dod_stats_session_score[winner] += GetConVar[GG_RoundWin][Value];

			// And notify winner!
			if (dod_stats_client_notify[winner])
			{
				CPrintToChat(winner, "%t", "GunGame victory", color, GetConVar[GG_RoundWin][Value]);
			}
		}
	}
}