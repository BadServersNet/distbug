

static PlayerData playerData[MAXPLAYERS + 1];
static PlayerData failstatPlayerData[MAXPLAYERS + 1];

void OnClientConnected_Jumptracking(int client)
{
	playerData[client].Reset();
}

void EventPlayerJump_Jumptracking(int client)
{
	if (!IsSettingEnabled(client, FL_SETTINGS_ENABLED)
		|| playerData[client].framesOnGround <= 1)
	{
		return;
	}
	
	playerData[client].jump.validJump = true;
	GetClientAbsOrigin(client, playerData[client].jumpOrigin);
	playerData[client].jump.jumpTick = GetGameTickCount();
	
	// Start jump tracking
	playerData[client].jump.prestrafe = GetVectorHorLength(playerData[client].velocity);
	playerData[client].jump.jumptype = JUMPTYPE_LJ;
	playerData[client].jump.airpath += GetVectorHorLength(playerData[client].velocity) * GetTickInterval(); // need to double this up.
}

void OnPlayerRunCmdPost_JumpTracking(int client, const float vel[3])
{
	if (!IsSettingEnabled(client, FL_SETTINGS_ENABLED)
		|| !IsValidClientExt(client, true)
		|| GetEntityMoveType(client) != MOVETYPE_WALK)
	{
		return;
	}
	
	//
	// prepare variables
	//
	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		playerData[client].framesOnGround++;
	}
	else
	{
		playerData[client].framesOnGround = 0;
	}
	
	GetClientAbsOrigin(client, playerData[client].origin);
	GetClientVelocity(client, playerData[client].velocity);
	GetClientEyeAngles(client, playerData[client].angles);
	
	playerData[client].buttons = GetClientButtons(client);
	playerData[client].buttonReleased = GetClientButtonReleased(client);
	playerData[client].vel = vel;
	
	if (playerData[client].buttonReleased & IN_FORWARD)
	{
		playerData[client].wReleaseTick = GetGameTickCount();
	}
	
	//
	// do the stuff with the variables
	//
	
	if (playerData[client].framesOnGround == 0)
	{
		TrackJump(playerData[client]);
		// check for failstat
		if (playerData[client].jump.validJump)
		{
			float duckedOrigin[3];
			duckedOrigin = playerData[client].origin;
			
			if (~GetEntityFlags(client) & FL_DUCKING)
			{
				duckedOrigin[2] += 9.0;
			}
			
			// only save failed jump if we're at the fail threshold
			if ((playerData[client].origin[2] > playerData[client].jumpOrigin[2])
				&& (playerData[client].origin[2] + (playerData[client].velocity[2] * GetTickInterval()) < playerData[client].jumpOrigin[2]))
			{
				failstatPlayerData[client] = playerData[client];
			}
			
			if (duckedOrigin[2] <= playerData[client].jumpOrigin[2])
			{
				playerData[client] = failstatPlayerData[client];
				playerData[client].jump.validJump = false;
				playerData[client].jump.failed = true;
				OnPlayerFailStat(client, playerData[client]);
			}
		}
	}
	
	if (playerData[client].framesOnGround == 1)
	{
		if (playerData[client].jump.validJump)
		{
			OnPlayerJumpLand(client, playerData[client]);
		}
		playerData[client].jump.Reset();
	}
	
	//
	// prepare variables for next tick
	//
	
	playerData[client].lastNoduckOrigin = playerData[client].origin;
	playerData[client].lastVelocity = playerData[client].velocity;
	playerData[client].lastVel = playerData[client].vel;
	
	// compensate for duck. we can adjust this for duck/noduck later but we don't want random jolts in origin.
	if (GetEntProp(client, Prop_Send, "m_bDucking"))
	{
		playerData[client].lastNoduckOrigin[2] -= 9.0;
	}
}

static void OnPlayerJumpLand(int client, PlayerData pd)
{
	if (!pd.jump.validJump)
	{
		return;
	}
	
	pd.jump.validJump = false;
	
	// check offset #1
	if (!IsRoughlyEqual(pd.jumpOrigin[2], pd.origin[2], .tolerance = 4.0))
	{
		return;
	}
	
	TraceGround(client, pd.jumpOrigin, pd.jumpGround);
	TraceGround(client, pd.origin, pd.landGround);
	
	// check offset #2
	if (pd.jumpGround[2] != pd.landGround[2])
	{
		return;
	}
	
	//
	// calculate real landing position
	//
	
	float adjustedOrigin[3];
	adjustedOrigin = pd.origin;
	float tempVelocity[3];
	
	// If jump is bugged i.e./or basically directly on ground (0.00001 units or less away from ground).
	if (IsRoughlyEqual(pd.landGround[2], adjustedOrigin[2], 0.00001))
	{
		// Use previous tick's position and velocity if bugged
		tempVelocity = pd.lastVelocity;
		adjustedOrigin = pd.lastNoduckOrigin;
		
		// Compensate for ducking:
		// If we didn't compensate, then when ducking 1 tick before landing
		// we would get an origin that's ~9 units below landing origin.
		if (GetClientDucking(client))
		{
			adjustedOrigin[2] += 9.0;
		}
		pd.jump.ljBug = true;
	}
	else
	// jump is not bugged, use current tick's values.
	{
		tempVelocity = pd.velocity;
		// fix vertical velocity being 0 on landing tick
		tempVelocity[2] = pd.lastVelocity[2] - g_cvGravity.FloatValue * GetTickInterval();
		pd.jump.ljBug = false;
	}
	
	ScaleVector(tempVelocity, GetTickInterval()); // get distance travelled in 1 tick.
	
	float tracePos[3];
	AddVectors(adjustedOrigin, tempVelocity, tracePos);
	
	float mins[3];
	float maxs[3];
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	
	TR_TraceHullFilter(adjustedOrigin, tracePos, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (TR_DidHit())
	{
		TR_GetEndPosition(pd.jump.realLandOrigin);
	}
	else
	{
		pd.jump.realLandOrigin = adjustedOrigin;
	}
	
	pd.jump.distance = GetVectorHorDistance(pd.jumpOrigin, pd.jump.realLandOrigin) + 32.0;
	
	FinishJumpTracking(pd);
	
	if (IsFloatInRange(pd.jump.distance, g_cvMinJumpDistance.FloatValue, g_cvMaxJumpDistance.FloatValue))
	{
		PrintJumpstat(client, pd);
	}
}

// ========
// Tracking
// ========

static void TrackJump(PlayerData pd)
{
	if (!pd.jump.validJump)
	{
		return;
	}
	
	float speed = GetVectorHorLength(pd.velocity);
	float lastSpeed = GetVectorHorLength(pd.lastVelocity);
	
	if (speed > pd.jump.maxspeed)
	{
		pd.jump.maxspeed = speed;
	}
	
	pd.jump.airpath += GetVectorHorLength(pd.velocity) * GetTickInterval(); // straightness of airpath
	
	float height = pd.origin[2] - pd.jumpOrigin[2];
	if (height > pd.jump.height)
	{
		pd.jump.height = height;
	}
	
	pd.jump.airtime++;
	
	if (speed > lastSpeed)
	{
		pd.jump.sync += 1.0;
	}
	
	if (IsOverlapping(pd.buttons))
	{
		pd.jump.overlap++;
	}
	
	if (IsDeadairtime(pd))
	{
		pd.jump.deadair++;
	}
	
	// track strafestats
	{
		if (pd.jump.strafes >= MAX_STRAFES - 1)
		{
			return;
		}
		
		if (((pd.vel[1] > 0.0 && pd.lastVel[1] <= 0.0)
			|| (pd.vel[1] < 0.0 && pd.lastVel[1] >= 0.0))
			&& pd.jump.airtime != 1)
		{
			pd.jump.strafes++;
		}
		
		int strafe = pd.jump.strafes;
		
		if (speed > lastSpeed)
		{
			pd.jump.strafeSync[strafe] += 1.0;
			pd.jump.strafeGain[strafe] += speed - lastSpeed;
		}
		else if (speed < lastSpeed)
		{
			pd.jump.strafeLoss[strafe] += lastSpeed - speed;
		}
		
		if (lastSpeed > 0.0 && (pd.vel[0] || pd.vel[1]))
		{
			float velocityYaw = RadToDeg(ArcTangent2(pd.lastVelocity[1], pd.lastVelocity[0]));
			float wishSpeedYaw = RadToDeg(ArcTangent2(-pd.vel[1], pd.vel[0])); // have to negate y axis, i don't know why, but it makes hsw work.
			
			float efficiency = FloatAbs(NormaliseAngle((pd.angles[1] + wishSpeedYaw) - velocityYaw)) - 90.0;
			pd.jump.strafeAvgEfficiency[strafe] += efficiency;
			if (FloatAbs(efficiency) < FloatAbs(pd.jump.strafePeakEfficiency[strafe]))
			{
				pd.jump.strafePeakEfficiency[strafe] = efficiency;
			}
			pd.jump.strafeEfficiencyCount[strafe]++;
		}
		
		if (speed > pd.jump.strafeMax[strafe])
		{
			pd.jump.strafeMax[strafe] = speed;
		}
		
		pd.jump.strafeAirtime[strafe]++;
		
		if (IsOverlapping(pd.buttons))
		{
			pd.jump.strafeOverlap[strafe]++;
		}
		
		if (IsDeadairtime(pd))
		{
			pd.jump.strafeDeadair[strafe]++;
		}
	}
}

static void FinishJumpTracking(PlayerData pd)
{
	for (int strafe; strafe < pd.jump.strafes + 1; strafe++)
	{
		// average gain
		pd.jump.strafeAvgGain[strafe] = pd.jump.strafeGain[strafe] / pd.jump.strafeAirtime[strafe];
		
		// efficiency!
		if (pd.jump.strafeEfficiencyCount[strafe])
		{
			pd.jump.strafeAvgEfficiency[strafe] = pd.jump.strafeAvgEfficiency[strafe] / float(pd.jump.strafeEfficiencyCount[strafe]);
		}
		else
		{
			pd.jump.strafeAvgEfficiency[strafe] = FLOAT_NAN;
		}
		
		// sync
		if (pd.jump.strafeAirtime[strafe] != 0.0)
		{
			pd.jump.strafeSync[strafe] = pd.jump.strafeSync[strafe] / float(pd.jump.strafeAirtime[strafe]) * 100.0;
		}
		else
		{
			pd.jump.strafeSync[strafe] = 0.0;
		}
	}
	
	pd.jump.wRelease = pd.wReleaseTick - pd.jump.jumpTick;
	pd.jump.sync = pd.jump.sync / float(pd.jump.airtime) * 100.0;
	
	// Calculate deviation
	float xAxisDeviation = FloatAbs(pd.origin[0] - pd.jumpOrigin[0]);
	float yAxisDeviation = FloatAbs(pd.origin[1] - pd.jumpOrigin[1]);
	pd.jump.deviation = FloatMin(xAxisDeviation, yAxisDeviation);
	
	// Calculate airpath
	{
		float tickdistance = GetVectorHorLength(pd.velocity) * GetTickInterval();
		float realtickDistance;
		if (pd.jump.ljBug)
		{
			realtickDistance = GetVectorHorDistance(pd.lastNoduckOrigin, pd.jump.realLandOrigin);
		}
		else
		{
			realtickDistance = GetVectorHorDistance(pd.origin, pd.jump.realLandOrigin);
		}
		
		if (realtickDistance > tickdistance || tickdistance == 0.0)
		{
			pd.jump.airpath = (pd.jump.airpath + 32.0) / pd.jump.distance;
		}
		else
		{
			
			float fraction = realtickDistance / tickdistance;
			
			float newAirpath;
			if (pd.jump.ljBug)
			{
				newAirpath = (pd.jump.airpath - tickdistance + tickdistance * fraction + 32.0) / pd.jump.distance;
			}
			else
			{
				newAirpath = (pd.jump.airpath + tickdistance * fraction + 32.0) / pd.jump.distance;
			}
			
			pd.jump.airpath = FloatMax(1.0, newAirpath);
		}
	}
	
	// Calculate block distance and jumpoff edge
	{
		int blockAxis = FloatAbs(pd.landGround[1] - pd.jumpGround[1]) > FloatAbs(pd.landGround[0] - pd.jumpGround[0]);
		
		float tempPos[3];
		
		tempPos = pd.landGround;
		tempPos[2] += 1.0;
		tempPos[blockAxis] += (pd.jumpGround[blockAxis] - pd.landGround[blockAxis]) / 2.0;
		
		float jumpEdge[3];
		TraceBlock(tempPos, pd.jumpGround, jumpEdge);
		
		tempPos = pd.jumpGround;
		tempPos[2] += 1.0;
		tempPos[blockAxis] += (pd.landGround[blockAxis] - pd.jumpGround[blockAxis]) / 2.0;
		
		bool block;
		float landEdge[3];
		block = TraceBlock(tempPos, pd.landGround, landEdge);
		
		if (block)
		{
			pd.jump.block = FloatAbs(landEdge[blockAxis] - jumpEdge[blockAxis]) + 32.0625;
		}
		else
		{
			pd.jump.block = -1.0;
		}
		
		if (jumpEdge[blockAxis] - tempPos[blockAxis] != 0.0)
		{
			pd.jump.edge = FloatAbs(pd.jumpGround[blockAxis] - RoundFloat(jumpEdge[blockAxis]));
		}
		else
		{
			pd.jump.edge = -1.0;
		}
	}
}


// ========
// Failstat
// ========

void OnPlayerFailStat(int client, PlayerData pd)
{
	TraceGround(client, pd.jumpOrigin, pd.jumpGround);
	pd.landGround = pd.origin;
	pd.landGround[2] = pd.jumpOrigin[2];
	
	if ((pd.origin[2] - pd.jumpOrigin[2]) == 0.0)
	{
		pd.jump.realLandOrigin = pd.origin;
		return;
	}
	
	float verticalDistance = pd.origin[2] - (pd.origin[2] + pd.velocity[2] * GetTickInterval());
	float fraction = (pd.origin[2] - pd.jumpOrigin[2]) / verticalDistance;
	
	float addDistance[3];
	addDistance = pd.velocity;
	ScaleVector(addDistance, GetTickInterval() * fraction);
	
	AddVectors(pd.origin, addDistance, pd.jump.realLandOrigin);
	
	pd.jump.distance = GetVectorHorDistance(pd.jumpOrigin, pd.jump.realLandOrigin) + 32.0;
	
	FinishJumpTracking(pd);
	PrintJumpstat(client, pd);
	pd.jump.Reset();
}

// ================
// Helper Functions
// ================

static bool IsDeadairtime(PlayerData pd)
{
	return !(pd.buttons & IN_MOVERIGHT) && !(pd.buttons & IN_MOVELEFT);
}

// ========
// Printing
// ========

void PrintJumpstat(int client, PlayerData pd)
{
	char jumptype[32];
	FormatEx(jumptype, sizeof jumptype, "{g}%s%s", pd.jump.failed ? "FAILED " : "", g_szJumptypes[pd.jump.jumptype]);
	
	char distance[32];
	FormatEx(distance, sizeof distance, "{d}%.4f", pd.jump.distance);
	
	char edge[40];
	if (pd.jump.edge >= 0.0 && pd.jump.edge < MAX_EDGE)
	{
		FormatEx(edge, sizeof edge, "Edge: {d}%.3f{g} %s ", pd.jump.edge, CHAT_SEPARATOR);
	}
	
	char block[40];
	if (IsFloatInRange(pd.jump.block, g_cvMinJumpDistance.FloatValue, g_cvMaxJumpDistance.FloatValue))
	{
		FormatEx(block, sizeof block, "Block: {d}%i{g} %s ", RoundFloat(pd.jump.block), CHAT_SEPARATOR);
	}
	
	char prestrafe[32];
	FormatEx(prestrafe, sizeof prestrafe, "{g}Pre: {d}%.2f", pd.jump.prestrafe);
	
	char maxspeed[32];
	FormatEx(maxspeed, sizeof maxspeed, "Max: {d}%.1f", pd.jump.maxspeed);
	
	char airpath[32];
	FormatEx(airpath, sizeof airpath, "Airpath: {d}%.4f", pd.jump.airpath);
	
	char deviation[32];
	FormatEx(deviation, sizeof deviation, "Deviation: {d}%.3f", pd.jump.deviation);
	
	char height[32];
	FormatEx(height, sizeof height, "Height: {l}%.2f", pd.jump.height);
	
	char sync[32];
	FormatEx(sync, sizeof sync, "Sync: {l}%.1f", pd.jump.sync);
	
	char airtime[32];
	FormatEx(airtime, sizeof airtime, "Air: {l}%i", pd.jump.airtime);
	
	char wRelease[32];
	if (pd.jump.wRelease == 0)
	{
		FormatEx(wRelease, sizeof wRelease, "-W: {gr}✓");
	}
	else if (Abs(pd.jump.wRelease) > 16)
	{
		FormatEx(wRelease, sizeof wRelease, "-W: {g}No");
	}
	else if (pd.jump.wRelease > 0)
	{
		FormatEx(wRelease, sizeof wRelease, "-W: {dr}+%i", pd.jump.wRelease);
	}
	else
	{
		FormatEx(wRelease, sizeof wRelease, "-W: {sb}%i", pd.jump.wRelease);
	}
	
	char overlap[32];
	FormatEx(overlap, sizeof overlap, "OL: {l}%i", pd.jump.overlap);
	
	char deadair[32];
	FormatEx(deadair, sizeof deadair, "DA: {l}%i", pd.jump.deadair);
	
	char chatStats[768];
	FormatEx(chatStats, sizeof chatStats,
		"%s %s: %s {g}[%s%s%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s{g}]",
		CHAT_PREFIX,
		jumptype,
		distance,
		edge,
		block,
		prestrafe,
		CHAT_SEPARATOR,
		maxspeed,
		CHAT_SEPARATOR,
		airpath,
		CHAT_SEPARATOR,
		deviation,
		CHAT_SEPARATOR,
		height,
		CHAT_SEPARATOR,
		sync,
		CHAT_SEPARATOR,
		airtime,
		CHAT_SEPARATOR,
		wRelease,
		CHAT_SEPARATOR,
		overlap,
		CHAT_SEPARATOR,
		deadair);
	
	CPrintToChat(client, chatStats);
	
	char consoleStats[768];
	strcopy(consoleStats, sizeof consoleStats, chatStats);
	CRemoveTags(consoleStats, sizeof consoleStats);
	PrintToConsole(client, consoleStats);
	
	char strafestats[2048];
	if (IsSettingEnabled(client, FL_SETTINGS_STRAFESTATS))
	{
		FormatEx(strafestats, sizeof strafestats, " #.  Sync   Gain   Loss  Max   Air  OL  DA  AvgGain  Efficiency (avg & peak)\n");
		
		for (int strafe; strafe <= pd.jump.strafes && strafe < MAX_STRAFES; strafe++)
		{
			Format(strafestats, sizeof strafestats, "%s%2i. %5.1f%% %6.2f %6.2f  %5.1f %3i %3i %3i  %3.2f     %5.2f (%5.2f)\n",
				strafestats,
				strafe + 1,
				pd.jump.strafeSync[strafe],
				pd.jump.strafeGain[strafe],
				pd.jump.strafeLoss[strafe],
				pd.jump.strafeMax[strafe],
				pd.jump.strafeAirtime[strafe],
				pd.jump.strafeOverlap[strafe],
				pd.jump.strafeDeadair[strafe],
				pd.jump.strafeAvgGain[strafe],
				pd.jump.strafeAvgEfficiency[strafe],
				pd.jump.strafePeakEfficiency[strafe]);
		}
		
		PrintToConsole(client, strafestats);
	}
	
	// echo to spectators
	if (IsNullString(chatStats) &&
		IsNullString(strafestats))
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsValidClientExt(i) || !IsClientObserver(i))
		{
			continue;
		}
		
		// Check if spectating client
		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != client)
		{
			continue;
		}
		
		int specMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		// 4 = 1st person, 5 = 3rd person
		if (specMode != 4 && specMode != 5)
		{
			continue;
		}
		
		if (!IsSettingEnabled(client, FL_SETTINGS_ENABLED))
		{
			continue;
		}
		
		if (!IsNullString(chatStats))
		{
			CPrintToChat(i, "%s", chatStats);
		}
		
		if (!IsNullString(consoleStats))
		{
			PrintToConsole(i, "%s", consoleStats);
		}
		
		if (!IsNullString(strafestats))
		{
			PrintToConsole(i, strafestats);
		}
	}
}