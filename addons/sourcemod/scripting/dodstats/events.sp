/* Event_Round_Start()
 *
 * Called when a round starts.
 * --------------------------------------------------------------------- */
public Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundend = false;

	// Enable ranking now
	if (!rankactive && GetClientCount() >= GetConVarInt(dodstats_minplayers))
	{
		rankactive = true;
		CPrintToChatAll("%t", "Ranking enabled");
	}

	// If rank is not active and player count not exceeded minimum player count, disable rank active 
	else if (rankactive && GetClientCount() < GetConVarInt(dodstats_minplayers))
	{
		rankactive = false;
		CPrintToChatAll("%t", "Not enough players", GetConVarInt(dodstats_minplayers));
	}
}

/* Event_Round_End()
 *
 * Called when a round ends.
 * --------------------------------------------------------------------- */
public Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		// Round ended only if any of team is won
		new win_team = GetEventInt(event, "team");

		for (new client = 1; client <= MaxClients; client++)
		{
			// Encourage players from winner's team
			if (IsClientInGame(client) && GetClientTeam(client) == win_team)
			{
				// POINTS!
				if (GetConVarInt(stats_points_victory) > 0)
				{
					dod_stats_score[client] += GetConVarInt(stats_points_victory);

					if (dod_stats_client_notify[client])
					{
						CPrintToChat(client, "%t", "Victory points", GetConVarInt(stats_points_victory));
					}
				}
			}
		}
	}

	// If ranking at bonusround should be disabled - turn it off
	if (!GetConVarBool(dodstats_bonusround))
	{
		// Added:minplayers update
		roundend   = true;
		rankactive = false;
		CPrintToChatAll("%t", "Ranking disabled");
	}
}

/* Event_Player_Disconnect()
 *
 * Called when a client disconnects from the server.
 * --------------------------------------------------------------------- */
public Event_Player_Disconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (db != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (client > 0 && !IsFakeClient(client))
		{
			decl String:client_steamid[64], String:query[128];
			GetClientAuthString(client, client_steamid, sizeof(client_steamid));

			// Reset session status when client disconnected.
			if (dod_stats_online[client])
			{
				dod_stats_online[client] = false;

				Format(query, sizeof(query), "UPDATE dod_stats SET online = 0 WHERE steamid = '%s'", client_steamid);
				SQL_TQuery(db, DB_CheckErrors, query);
			}

			if (GetClientCount() < GetConVarInt(dodstats_minplayers))
				rankactive = false;
		}
	}
}

/* Event_Player_Death()
 *
 * Called when a player dies.
 * --------------------------------------------------------------------- */
public Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new victim   = GetClientOfUserId(GetEventInt(event, "userid"));

		if (attacker > 0 && victim > 0 && !IsFakeClient(attacker))
		{
			decl String:weapon[32];

			// Check for suicide
			if (attacker == victim)
			{
				dod_stats_deaths[victim]++;
				dod_stats_session_deaths[victim]++;

				// If points to take on suicide is specified - continue. Skip otherwise
				if (GetConVarInt(stats_points_suicide) > 0)
				{
					dod_stats_score[victim]         -= GetConVarInt(stats_points_suicide);
					dod_stats_session_score[victim] -= GetConVarInt(stats_points_suicide);

					if (dod_stats_client_notify[victim])
					{
						CPrintToChat(victim, "%t", "Suicide penalty", GetConVarInt(stats_points_suicide));
					}
				}
			}
			// Teamkill
			else if (GetClientTeam(attacker) == GetClientTeam(victim))
			{
				// Give points for teamkill as a usual kill (because its DM)
				if (gameplay == 1)
				{
					dod_stats_kills[attacker]++;
					dod_stats_deaths[victim]++;
					dod_stats_session_kills[attacker]++;
					dod_stats_session_deaths[victim]++;

					// Use ELO formula if K-Value > 0 and save scores.
					if (GetConVarInt(stats_points_k_value) > 0)
					{
						// ELO formula. Divider = 400 by default.
						new Float:ELO = 1 / (Pow(10.0, float((dod_stats_score[victim] - dod_stats_score[attacker])) / 100) + 1);
						new score     = RoundToNearest(GetConVarFloat(stats_points_k_value) * (1 - ELO));

						// Forcing minimal value on kill.
						if (score < GetConVarInt(stats_points_min))
							score = GetConVarInt(stats_points_min);

						dod_stats_score[attacker]         += score;
						dod_stats_session_score[attacker] += score;
						dod_stats_score[victim]           -= score;
						dod_stats_session_score[victim]   -= score;

						if (dod_stats_client_notify[attacker])
						{
							CPrintToChat(attacker, "%t", "Kill points", score, victim);
						}
						else if (dod_stats_client_notify[victim])
						{
							CPrintToChat(victim, "%t", "Death points", attacker, score);
						}
					}
				}
				// Punish player for teamkill in normal mode.
				else
				{
					// Detecting a bomb
					GetEventString(event, "weapon", weapon, sizeof(weapon));

					// Dont count teamkills if teammates down by TNT (retards?)
					if (!StrEqual(weapon, "dod_bomb_target"))
					{
						dod_stats_teamkills[attacker]++;
						dod_stats_teamkilled[victim]++;

						// Still not sure about that. Should I decrease kills amount on tk or just take points?
						dod_stats_kills[attacker]--;
						dod_stats_session_kills[attacker]--;

						// If points to take on tk is specified - continue.
						if (GetConVarInt(stats_points_tk_penalty) > 0)
						{
							dod_stats_score[attacker]         -= GetConVarInt(stats_points_tk_penalty);
							dod_stats_session_score[attacker] -= GetConVarInt(stats_points_tk_penalty);

							// And show message for attacker if notifications is enabled for him.
							if (dod_stats_client_notify[attacker])
							{
								CPrintToChat(attacker, "%t", "Teamkill penalty", GetConVarInt(stats_points_tk_penalty));
							}
						}
					}
				}
			}
			// Otherwise it's a legitimate kill!
			else
			{
				// Add points for overall score and session.
				dod_stats_kills[attacker]++;
				dod_stats_deaths[victim]++;
				dod_stats_session_kills[attacker]++;
				dod_stats_session_deaths[victim]++;

				// Checking K-Value
				if (GetConVarInt(stats_points_k_value) > 0)
				{
					// I use divider = 100 because start points < 1600
					new Float:ELO = 1 / (Pow(10.0, float((dod_stats_score[victim] - dod_stats_score[attacker])) / 100 ) + 1);
					new score     = RoundToNearest(GetConVarFloat(stats_points_k_value) * (1 - ELO));

					if (score < GetConVarInt(stats_points_min))
						score = GetConVarInt(stats_points_min);

					dod_stats_score[attacker]         += score;
					dod_stats_session_score[attacker] += score;
					dod_stats_score[victim]           -= score;
					dod_stats_session_score[victim]   -= score;

					if (dod_stats_client_notify[attacker])
					{
						CPrintToChat(attacker, "%t", "Kill points", score, victim);
					}
					else if (dod_stats_client_notify[victim])
					{
						CPrintToChat(victim, "%t", "Death points", attacker, score);
					}
				}
			}
		}
	}
}

/* Event_Player_Hurt()
 *
 * Called when a player getting/taking damage.
 * --------------------------------------------------------------------- */
public Event_Player_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new victim   = GetClientOfUserId(GetEventInt(event, "userid"));

		if (attacker > 0 && victim > 0 && !IsFakeClient(attacker))
		{
			// Code taken from SuperLogs. Victim should be dead, because direct headshot from any weapon takes at least 100 health.
			if (GetEventInt(event, "health") < 1 && GetEventInt(event, "hitgroup") == 1)
			{
				// Count a headshot for teamkill, because this is DM
				if (gameplay == 1)
				{
					dod_stats_headshots[attacker]++;
					dod_stats_session_headshots[attacker]++;

					if (GetConVarInt(stats_points_headshot) > 0)
					{
						dod_stats_score[attacker]         += GetConVarInt(stats_points_headshot);
						dod_stats_session_score[attacker] += GetConVarInt(stats_points_headshot);

						if (dod_stats_client_notify[attacker])
						{
							CPrintToChat(attacker, "%t", "Headshot points", GetConVarInt(stats_points_headshot));
						}
					}
				}
				else if (gameplay == 0 && GetClientTeam(attacker) != GetClientTeam(victim))
				{
					// Thats no DM, we wont`t count a headshot for teamkill
					dod_stats_headshots[attacker]++;
					dod_stats_session_headshots[attacker]++;

					if (GetConVarInt(stats_points_headshot) > 0)
					{
						dod_stats_score[attacker]         += GetConVarInt(stats_points_headshot);
						dod_stats_session_score[attacker] += GetConVarInt(stats_points_headshot);

						if (dod_stats_client_notify[attacker])
						{
							CPrintToChat(attacker, "%t", "Headshot points", GetConVarInt(stats_points_headshot));
						}
					}
				}
			}
		}
	}
}

/* Event_Point_Captured()
 *
 * When a client(s) captured point.
 * --------------------------------------------------------------------- */
public Event_Point_Captured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		new client;

		// Because there may be more than 1 capper
		decl String:cappers[256];
		GetEventString(event, "cappers", cappers, sizeof(cappers));

		for (new i = 0 ; i < strlen(cappers); i++)
		{
			// Track captures for all invaders!
			client = cappers[i];

			dod_stats_captures[client]++;

			if (GetConVarInt(stats_points_capture) > 0)
			{
				// And add points.
				dod_stats_score[client]         += GetConVarInt(stats_points_capture);
				dod_stats_session_score[client] += GetConVarInt(stats_points_capture);

				if (dod_stats_client_notify[client])
				{
					CPrintToChat(client, "%t", "Capture points", GetConVarInt(stats_points_capture));
				}
			}
		}
	}
}

/* Event_Capture_Blocked()
 *
 * When a player blocked capture.
 * --------------------------------------------------------------------- */
public Event_Capture_Blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		// Because blocker is only one.
		new client = GetEventInt(event, "blocker");

		dod_stats_capblocks[client]++;

		if (GetConVarInt(stats_points_block) > 0)
		{
			dod_stats_score[client]         += GetConVarInt(stats_points_block);
			dod_stats_session_score[client] += GetConVarInt(stats_points_block);

			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Block points", GetConVarInt(stats_points_block));
			}
		}
	}
}

/* Event_Bomb_Exploded()
 *
 * When a TNT on objective is exploded.
 * --------------------------------------------------------------------- */
public Event_Bomb_Exploded(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Event_Point_Captured() is also called with this event, so we'll just add points, not captures.
	if (rankactive && GetConVarInt(stats_points_bomb_explode) > 0)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		dod_stats_score[client]         += GetConVarInt(stats_points_bomb_explode);
		dod_stats_session_score[client] += GetConVarInt(stats_points_bomb_explode);

		if (dod_stats_client_notify[client])
		{
			CPrintToChat(client, "%t", "Explode points", GetConVarInt(stats_points_bomb_explode));
		}
	}
}

/* Event_Bomb_Blocked()
 *
 * Called when a player killed defuser or planter.
 * --------------------------------------------------------------------- */
public Event_Bomb_Blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Event_Capture_Blocked() is also called with this event, so we'll just add points, not captures.
	if (rankactive && GetConVarInt(stats_points_block) > 0)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		dod_stats_score[client]         += GetConVarInt(stats_points_block);

		// Also add for session.
		dod_stats_session_score[client] += GetConVarInt(stats_points_block);

		if (dod_stats_client_notify[client])
		{
			CPrintToChat(client, "%t", "Protect points", GetConVarInt(stats_points_block));
		}
	}
}

/* Event_Bomb_Planted()
 *
 * When a player planted bomb.
 * --------------------------------------------------------------------- */
public Event_Bomb_Planted(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		// Player is planted a bomb - track it into database.
		dod_stats_planted[client]++;

		if (GetConVarInt(stats_points_bomb_planted) > 0)
		{
			dod_stats_score[client]         += GetConVarInt(stats_points_bomb_planted);
			dod_stats_session_score[client] += GetConVarInt(stats_points_bomb_planted);

			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Plant points", GetConVarInt(stats_points_bomb_planted));
			}
		}
	}
}

/* Event_Bomb_Defused()
 *
 * When a player defused bomb.
 * --------------------------------------------------------------------- */
public Event_Bomb_Defused(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		dod_stats_defused[client]++;

		if (GetConVarInt(stats_points_bomb_defused) > 0)
		{
			// Player is defused a bomb - he deserve a ... points!
			dod_stats_score[client]         += GetConVarInt(stats_points_bomb_defused);
			dod_stats_session_score[client] += GetConVarInt(stats_points_bomb_defused);

			if (dod_stats_client_notify[client])
			{
				CPrintToChat(client, "%t", "Defuse points", GetConVarInt(stats_points_bomb_defused));
			}
		}
	}
}