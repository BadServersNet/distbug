
#if defined _gamechaos_stocks_tracing_included
	#endinput
#endif
#define _gamechaos_stocks_tracing_included

/**
 * Trace ray filter that filters players from being traced.
 *
 * @param entity			Entity.
 * @param data				Data.
 * @return 					True on success, false otherwise.
 */
stock bool TraceEntityFilterPlayer(int entity, any data)
{
	return entity > MAXPLAYERS;
}

/**
 * Traces the player hull beneath the player in the direction of
 * the player's velocity. This should be used on the tick when the player lands
 *
 * @param client			Player's index.
 * @param pos				Player's position vector.
 * @param velocity			Player's velocity vector. This shuold have the current tick's x and y velocities, but the previous tick's z velocity, since when you're on ground, your z velocity is 0.
 * @param result			Trace endpoint on success, player's position on failure.
 * @param bugged			Whether to add gravity to the player's velocity or not.
 * @return 					True on success, false otherwise.
 */
stock bool TraceLandPos(int client, const float pos[3], const float velocity[3], float result[3], float fGravity, bool bugged = false)
{
	float newVel[3];
	CopyVector(velocity, newVel);
	
	if (bugged)
	{
		// add 0.5 gravity
		newVel[2] -= fGravity * GetTickInterval() * 0.5;
	}
	else
	{
		// add 1.5 gravity
		newVel[2] -= fGravity * GetTickInterval() * 1.5;
	}
	
	ScaleVector(newVel, GetTickInterval() * 2.0);
	float pos2[3];
	AddVectors(pos, newVel, pos2);
	
	float mins[3];
	float maxs[3];
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	
	Handle trace = TR_TraceHullFilterEx(pos, pos2, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (!TR_DidHit(trace))
	{
		CopyVector(pos, result);
		CloseHandle(trace);
		return false;
	}
	
	TR_GetEndPosition(result, trace);
	CloseHandle(trace);
	
	return true;
}

/**
 * Traces the player hull straight down beneath the player.
 *
 * @param client			Player's index.
 * @param pos				Player's position vector.
 * @param result			Trace endpoint on success, player's position on failure.
 * @return 					True on success, false otherwise.
 */
stock bool TraceGround(int client, const float pos[3], float result[3])
{
	float mins[3];
	float maxs[3];
	
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	
	float startpos[3];
	float endpos[3];
	
	CopyVector(pos, startpos);
	CopyVector(pos, endpos);
	
	endpos[2] -= 2.0;
	
	TR_TraceHullFilter(startpos, endpos, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (TR_DidHit())
	{
		TR_GetEndPosition(result);
		return true;
	}
	else
	{
		result = endpos;
		return false;
	}
}

/**
 * Traces a hull between 2 positions.
 *
 * @param pos1				Position 1.
 * @param pos2				Position 2
 * @param result			Trace endpoint on success, player's position on failure.
 * @return 					True on success, false otherwise.
 */
stock bool TraceBlock(const float pos1[3], const float pos2[3], float result[3])
{
	float mins[3] =  {-16.0, -16.0, -1.0};
	float maxs[3] =  { 16.0,  16.0,  0.0};
	
	TR_TraceHullFilter(pos1, pos2, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (TR_DidHit())
	{
		TR_GetEndPosition(result);
		return true;
	}
	else
	{
		return false;
	}
}

/**
 * Traces from player eye position in the direction of where the player is looking.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 * @return 					True on success, false otherwise.
 */
stock bool GetEyeRayPosition(int client, float result[3], TraceEntityFilter filter, any data = 0, int flags = MASK_PLAYERSOLID)
{
	float start[3];
	float angle[3];
	
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angle);
	
	TR_TraceRayFilter(start, angle, flags, RayType_Infinite, filter, data);
	
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(result, INVALID_HANDLE);
		return true;
	}
	return false;
}

/**
 * Traces from player eye position in the direction of where the player is looking, up to a certain distance.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 * @param distance			Maximum distance to trace.
 * @return 					True on success, false otherwise.
 */
stock bool TraceEyeRayPositionDistance(int client, float result[3], float distance)
{
	float start[3];
	float angle[3];
	
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angle);
	
	float endpoint[3];
	float zsine = Sine(DegToRad(-angle[0]));
	float zcos = Cosine(DegToRad(-angle[0]));
	
	endpoint[0] = Cosine(DegToRad(angle[1])) * zcos;
	endpoint[1] = Sine(DegToRad(angle[1])) * zcos;
	endpoint[2] = zsine;
	
	ScaleVector(endpoint, distance);
	AddVectors(start, endpoint, endpoint);
	
	TR_TraceRayFilter(start, endpoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceEntityFilterPlayer, client);
	
	if (TR_DidHit())
	{
		TR_GetEndPosition(result);
		return true;
	}
	
	CopyVector(endpoint, result);
	return false;
}

/**
 * Traces a hull in a certain direction and distance.
 *
 * @param origin			Position to trace from.
 * @param direction			Trace direction.
 * @param mins				Minimum size of the hull.
 * @param maxs				Maximum size of the hull.
 * @param result			Resultant vector.
 * @return 					True on success, false otherwise.
 */
stock bool TraceHullDirection(const float origin[3],
	const float direction[3],
	const float mins[3],
	const float maxs[3],
	float result[3],
	float distance,
	TraceEntityFilter filter,
	any data = 0,
	int flags = MASK_PLAYERSOLID)
{
	float pos2[3];
	float zsine = Sine(DegToRad(-direction[0]));
	float zcos = Cosine(DegToRad(-direction[0]));
	
	pos2[0] = Cosine(DegToRad(direction[1])) * zcos;
	pos2[1] = Sine(DegToRad(direction[1])) * zcos;
	pos2[2] = zsine;
	
	ScaleVector(pos2, distance);
	AddVectors(origin, pos2, pos2);
	
	TR_TraceHullFilter(origin, pos2, mins, maxs, flags, filter, data);
	if (TR_DidHit())
	{
		TR_GetEndPosition(result);
		return true;
	}
	result = pos2;
	return false;
}