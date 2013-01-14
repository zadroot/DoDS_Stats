/* Event_Round_Start()
 *
 * Called when a round starts.
 * ----------------------------------------------------------------- */
public Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundend = false;

	// Enable ranking now
	if (!rankactive && GetClientCount(true) >= GetConVarInt(dodstats_minplayers))
	{
		rankactive = true;
		CPrintToChatAll("%t", "Ranking enabled");
	}

	// If rank is not active and player count not exceeded minimum player count, disable rank active
	if (rankactive && GetClientCount(true) < GetConVarInt(dodstats_minplayers))
	{
		rankactive = false;
		CPrintToChatAll("%t", "Not enough players", GetConVarInt(dodstats_minplayers));
	}
}

/* Event_Round_End()
 *
 * Called when a round ends.
 * ----------------------------------------------------------------- */
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
					decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");

					dod_stats_score[client] += GetConVarInt(stats_points_victory);

					if (dod_stats_client_notify[client])
					{
						CPrintToChat(client, "%t", "Victory points", color, GetConVarInt(stats_points_victory));
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
 * ----------------------------------------------------------------- */
public Event_Player_Disconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(client))
	{
		// Reset session status when client disconnected.
		dod_stats_online[client] = false;

		if (GetClientCount(true) < GetConVarInt(dodstats_minplayers))
			rankactive = false;
	}
}

/* Event_Player_Death()
 *
 * Called when a player dies.
 * ----------------------------------------------------------------- */
public Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive)
	{
		// Get all the stuff
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new victim   = GetClientOfUserId(GetEventInt(event, "victim"));

		if (attacker > 0 && victim > 0)
		{
			dod_stats_weaponhits[attacker]++;

			// Make sure victim is dead
			if (GetClientHealth(victim) < 1)
			{
				new headshot  = GetEventInt(event, "hitgroup") == 1;
				new minpoints = GetConVarInt(stats_points_min);
				new hspoints  = GetConVarInt(stats_points_headshot);
				new score     = GetConVarInt(stats_points_min) + (dod_stats_score[victim] - dod_stats_score[attacker]) / 100;

				decl String:teamcolor[10], String:enemycolor[10];
				Format(teamcolor,  sizeof(teamcolor),  "%s", GetClientTeam(attacker) == 2 ? "{allies}" : "{axis}");
				Format(enemycolor, sizeof(enemycolor), "%s", GetClientTeam(victim)   == 2 ? "{allies}" : "{axis}");

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

						// Points
						if (minpoints > 0)
						{
							// ELO formula. Divider = 400 by default.
							//new Float:ELO = 1 / (Pow(10.0, float((dod_stats_score[victim] - dod_stats_score[attacker])) / 100) + 1);
							//new score     = RoundToNearest(GetConVarFloat(stats_points_k_value) * (1 - ELO));
							//new score = (GetConVarInt(stats_points_min) + (dod_stats_score[victim] - dod_stats_score[attacker]) / 100);

							// Forcing minimal value on kill.
							if (score < minpoints)
								score = minpoints;

							dod_stats_score[attacker]         += score;
							dod_stats_session_score[attacker] += score;
							dod_stats_score[victim]           -= score;
							dod_stats_session_score[victim]   -= score;

							if (dod_stats_client_notify[attacker])
							{
								CPrintToChat(attacker, "%t", "Kill points", score, enemycolor, victim);
							}
							if (dod_stats_client_notify[victim])
							{
								CPrintToChat(victim, "%t", "Death points", teamcolor, attacker, score);
							}
						}

						if (headshot)
						{
							dod_stats_headshots[attacker]++;
							dod_stats_session_headshots[attacker]++;

							if (hspoints > 0)
							{
								dod_stats_score[attacker]         += hspoints;
								dod_stats_session_score[attacker] += hspoints;

								if (dod_stats_client_notify[attacker])
								{
									CPrintToChat(attacker, "%t", "Headshot points", hspoints);
								}
							}
						}
					}
					// Punish player for teamkill in normal mode.
					else
					{
						// Dont count teamkills if teammates down by TNT
						if (GetEventInt(event, "weapon") > 0)
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
									CPrintToChat(attacker, "%t", "Teamkill penalty", GetConVarInt(stats_points_tk_penalty), teamcolor);
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
					if (minpoints > 0)
					{
						// I use divider = 100 because start points < 1600
						//new Float:ELO = 1 / (Pow(10.0, float((dod_stats_score[victim] - dod_stats_score[attacker])) / 100 ) + 1);
						//new score     = RoundToNearest(GetConVarFloat(stats_points_k_value) * (1 - ELO));
						//new score = (GetConVarInt(stats_points_min) + (dod_stats_score[victim] - dod_stats_score[attacker]) / 100);

						if (score < minpoints)
							score = minpoints;

						dod_stats_score[attacker]         += score;
						dod_stats_session_score[attacker] += score;
						dod_stats_score[victim]           -= score;
						dod_stats_session_score[victim]   -= score;

						if (dod_stats_client_notify[attacker])
						{
							CPrintToChat(attacker, "%t", "Kill points", score, enemycolor, victim);
						}
						if (dod_stats_client_notify[victim])
						{
							CPrintToChat(victim, "%t", "Death points", teamcolor, attacker, score);
						}
					}

					if (headshot)
					{
						// Thats no DM, we wont`t count a headshot for teamkill
						dod_stats_headshots[attacker]++;
						dod_stats_session_headshots[attacker]++;

						if (hspoints > 0)
						{
							dod_stats_score[attacker]         += hspoints;
							dod_stats_session_score[attacker] += hspoints;

							if (dod_stats_client_notify[attacker])
							{
								CPrintToChat(attacker, "%t", "Headshot points", hspoints);
							}
						}
					}
				}
			}
		}
	}
}

/* Event_Weapon_Fire()
 *
 * Called when a player attacks with a weapon.
 * ----------------------------------------------------------------- */
public Event_Weapon_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventInt(event, "weapon") > 2) dod_stats_weaponshots[GetClientOfUserId(GetEventInt(event, "attacker"))]++;
}

/* Event_Point_Captured()
 *
 * When a client(s) captured point.
 * ----------------------------------------------------------------- */
public Event_Point_Captured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive && GetEventBool(event, "bomb") == false)
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
					decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
					CPrintToChat(client, "%t", "Capture points", GetConVarInt(stats_points_capture), color);
				}
			}
		}
	}
}

/* Event_Capture_Blocked()
 *
 * When a player blocked capture.
 * ----------------------------------------------------------------- */
public Event_Capture_Blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive && GetEventBool(event, "bomb") == false)
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
				decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Block points", GetConVarInt(stats_points_block), color);
			}
		}
	}
}

/* Event_Bomb_Exploded()
 *
 * When a TNT on objective is exploded.
 * ----------------------------------------------------------------- */
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
			decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
			CPrintToChat(client, "%t", "Explode points", GetConVarInt(stats_points_bomb_explode), color);
		}
	}
}

/* Event_Bomb_Blocked()
 *
 * Called when a player killed defuser or planter.
 * ----------------------------------------------------------------- */
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
			decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
			CPrintToChat(client, "%t", "Protect points", GetConVarInt(stats_points_block), color);
		}
	}
}

/* Event_Bomb_Planted()
 *
 * When a player planted bomb.
 * ----------------------------------------------------------------- */
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
				decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Plant points", GetConVarInt(stats_points_bomb_planted), color);
			}
		}
	}
}

/* Event_Bomb_Defused()
 *
 * When a player defused bomb.
 * ----------------------------------------------------------------- */
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
				decl String:color[10]; Format(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Defuse points", GetConVarInt(stats_points_bomb_defused), color);
			}
		}
	}
}