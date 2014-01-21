/* Event_Round_Start()
 *
 * Called when a round starts.
 * ----------------------------------------------------------------- */
public Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	new minplayers = GetConVar[MinPlayers][Value];

	roundend = false;

	// Enable ranking now
	if (!rankactive && GetClientCount(true) >= minplayers)
	{
		rankactive = true;
		CPrintToChatAll("%t", "Ranking enabled");
	}

	// If rank is not active and player count not exceeded minimum player count, disable rank active
	if (rankactive && GetClientCount(true) < minplayers)
	{
		rankactive = false;
		CPrintToChatAll("%t", "Not enough players", minplayers);
	}
}

/* Event_Round_End()
 *
 * Called when a round ends.
 * ----------------------------------------------------------------- */
public Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	new roundpoints = GetConVar[Points_RoundWin][Value];
	if (rankactive && roundpoints)
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			// Encourage players from winner's team
			if (IsClientInGame(client) && GetClientTeam(client) == GetEventInt(event, "team"))
			{
				dod_stats_score[client] += roundpoints;

				if (dod_stats_client_notify[client])
				{
					// POINTS!
					decl String:color[10];
					FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
					CPrintToChat(client, "%t", "Victory points", color, roundpoints);
				}
			}
		}
	}

	// If ranking at bonusround should be disabled - turn it off
	if (!GetConVar[BonusRound][Value])
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
		SavePlayer(client);
		dod_stats_online[client] = false;

		if (GetClientCount(true) < GetConVar[MinPlayers][Value])
			rankactive = false;
	}
}

/* Event_SaveAllPlayers()
 *
 * Saves the stats for all players.
 * ----------------------------------------------------------------- */
public Event_SavePlayersStats(Handle:event, const String:name[], bool:dontBroadcast)
{
	static tickpoints_fired;

	// If that event were fired for 10 times, save stats of all players
	if (++tickpoints_fired >= 10)
	{
		// And reset amount of fired events
		tickpoints_fired = 0;

		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && dod_stats_online[client])
			{
				SavePlayer(client);
			}
		}
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
		// In this DoD:S event attacker and a victim is always valid
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new victim   = GetClientOfUserId(GetEventInt(event, "victim"));

		dod_stats_weaponhits[attacker]++;

		// Make sure victim is dead
		if (GetClientHealth(victim) < 1)
		{
			new weapon    = GetEventInt(event, "weapon");
			new bool:hs   = GetEventInt(event, "hitgroup") == 1;
			new minpoints = GetConVar[MinPoints][Value];
			new hspoints  = GetConVar[Points_Headshot][Value];
			new score     = GetConVar[MinPoints][Value] + (dod_stats_score[victim] - dod_stats_score[attacker]) / 100;

			decl String:teamcolor[10], String:enemycolor[10];
			FormatEx(teamcolor,  sizeof(teamcolor),  "%s", GetClientTeam(attacker) == 2 ? "{allies}" : "{axis}");
			FormatEx(enemycolor, sizeof(enemycolor), "%s", GetClientTeam(victim)   == 2 ? "{allies}" : "{axis}");

			// Check for suicide
			if (attacker == victim)
			{
				dod_stats_deaths[victim]++;
				dod_stats_session_deaths[victim]++;

				// If points to take on suicide is specified - continue. Skip otherwise
				new suipoints = GetConVar[Points_Suicide][Value];
				if (suipoints)
				{
					dod_stats_score[victim]         -= suipoints;
					dod_stats_session_score[victim] -= suipoints;

					if (dod_stats_client_notify[victim])
					{
						CPrintToChat(victim, "%t", "Suicide penalty", suipoints);
					}
				}
			}
			// Teamkill
			else if (GetClientTeam(attacker) == GetClientTeam(victim))
			{
				// Give points for teamkill as a usual kill (because its DM)
				if (gameplay == DEATHMATCH)
				{
					dod_stats_kills[attacker]++;
					dod_stats_deaths[victim]++;
					dod_stats_session_kills[attacker]++;
					dod_stats_session_deaths[victim]++;

					// Points
					if (minpoints)
					{
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

					if (hs)
					{
						dod_stats_headshots[attacker]++;
						dod_stats_session_headshots[attacker]++;

						if (hspoints)
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
					if (weapon != WeaponID_None)
					{
						dod_stats_teamkills[attacker]++;
						dod_stats_teamkilled[victim]++;

						// Still not sure about that. Should I decrease kills amount on tk or just take points?
						dod_stats_kills[attacker]--;
						dod_stats_session_kills[attacker]--;

						// If points to take on tk is specified - continue.
						new tkpoints = GetConVar[Points_TK_Penalty][Value];
						if (tkpoints)
						{
							dod_stats_score[attacker]         -= tkpoints;
							dod_stats_session_score[attacker] -= tkpoints;

							// And show message for attacker if notifications is enabled for him.
							if (dod_stats_client_notify[attacker])
							{
								CPrintToChat(attacker, "%t", "Teamkill penalty", tkpoints, teamcolor);
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
				if (minpoints)
				{
					if (score < minpoints)
						score = minpoints;

					// Killed by melee
					if (weapon == WeaponID_AmerKnife
					||  weapon == WeaponID_Spade
					||  weapon == WeaponID_Thompson_Punch
					||  weapon == WeaponID_MP40_Punch)
					{
						score *= GetConVar[MeleeMultipler][Value];
					}

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

				if (hs)
				{
					// Thats no DM, we wont`t count a headshot for teamkill
					dod_stats_headshots[attacker]++;
					dod_stats_session_headshots[attacker]++;

					if (hspoints)
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

/* Event_Weapon_Fire()
 *
 * Called when a player attacks with a weapon.
 * ----------------------------------------------------------------- */
public Event_Weapon_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Expensive event. Ignore only melee weapons
	if (GetEventInt(event, "weapon") > WeaponID_Spade) dod_stats_weaponshots[GetClientOfUserId(GetEventInt(event, "attacker"))]++;
}

/* Event_Point_Captured()
 *
 * When a client(s) captured point.
 * ----------------------------------------------------------------- */
public Event_Point_Captured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (rankactive && !GetEventBool(event, "bomb"))
	{
		new cpoints = GetConVar[Points_Capture][Value];

		// Because there may be more than 1 capper
		decl client, String:cappers[256];
		GetEventString(event, "cappers", cappers, sizeof(cappers));

		for (new i ; i < strlen(cappers); i++)
		{
			// Track captures for all invaders!
			client = cappers[i];

			dod_stats_captures[client]++;

			if (cpoints)
			{
				// And add points.
				dod_stats_score[client]         += cpoints;
				dod_stats_session_score[client] += cpoints;

				if (dod_stats_client_notify[client])
				{
					decl String:color[10];
					FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
					CPrintToChat(client, "%t", "Capture points", cpoints, color);
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
	if (rankactive && !GetEventBool(event, "bomb"))
	{
		// Because blocker is only one.
		new client = GetEventInt(event, "blocker");

		dod_stats_capblocks[client]++;

		new blpoints = GetConVar[Points_Block][Value];
		if (blpoints)
		{
			dod_stats_score[client]         += blpoints;
			dod_stats_session_score[client] += blpoints;

			if (dod_stats_client_notify[client])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Block points", blpoints, color);
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
	new expoints = GetConVar[Points_Explode][Value];

	// Event_Point_Captured() is also called with this event, so we'll just add points, not captures.
	if (rankactive && expoints)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		dod_stats_score[client]         += expoints;
		dod_stats_session_score[client] += expoints;

		if (dod_stats_client_notify[client])
		{
			decl String:color[10];
			FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
			CPrintToChat(client, "%t", "Explode points", expoints, color);
		}
	}
}

/* Event_Bomb_Blocked()
 *
 * Called when a player killed defuser or planter.
 * ----------------------------------------------------------------- */
public Event_Bomb_Blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	new blpoints = GetConVar[Points_Block][Value];

	// Event_Capture_Blocked() is also called with this event, so we'll just add points, not captures.
	if (rankactive && blpoints)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		dod_stats_score[client]         += blpoints;

		// Also add for session.
		dod_stats_session_score[client] += blpoints;

		if (dod_stats_client_notify[client])
		{
			decl String:color[10];
			FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
			CPrintToChat(client, "%t", "Protect points", blpoints, color);
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

		new plpoints = GetConVar[Points_Plant][Value];
		if (plpoints)
		{
			dod_stats_score[client]         += plpoints;
			dod_stats_session_score[client] += plpoints;

			if (dod_stats_client_notify[client])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Plant points", plpoints, color);
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

		new depoints = GetConVar[Points_Defuse][Value];
		if (depoints)
		{
			// Player is defused a bomb - he deserve a ... points!
			dod_stats_score[client]         += depoints;
			dod_stats_session_score[client] += depoints;

			if (dod_stats_client_notify[client])
			{
				decl String:color[10];
				FormatEx(color, sizeof(color), "%s", GetClientTeam(client) == 2 ? "{allies}" : "{axis}");
				CPrintToChat(client, "%t", "Defuse points", depoints, color);
			}
		}
	}
}