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

		if (GetConVarInt(stats_points_gg_leveldown) > 0)
		{
			dod_stats_score[client]         -= GetConVarInt(stats_points_gg_leveldown);
			dod_stats_session_score[client] -= GetConVarInt(stats_points_gg_leveldown);

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Level down", color, GetConVarInt(stats_points_gg_leveldown));
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

		if (GetConVarInt(stats_points_gg_levelup) > 0)
		{
			dod_stats_score[client]         += GetConVarInt(stats_points_gg_levelup);
			dod_stats_session_score[client] += GetConVarInt(stats_points_gg_levelup);

			// GunGame message on spade kill.
			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Level up", GetConVarInt(stats_points_gg_levelup), color);
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
		if (GetConVarInt(stats_points_gg_victory) > 0)
		{
			// And encourage.
			dod_stats_score[winner]         += GetConVarInt(stats_points_gg_victory);
			dod_stats_session_score[winner] += GetConVarInt(stats_points_gg_victory);

			// And notify winner!
			if (dod_stats_client_notify[winner])
			{
				CPrintToChat(winner, "%t", "GunGame victory", color, GetConVarInt(stats_points_gg_victory));
			}
		}
	}
}