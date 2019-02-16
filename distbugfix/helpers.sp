

/*
 *
 * helper functions
 *
 */


void CheckMaxHeight(int client)
{
	float fHeightOrigin[3];
	fHeightOrigin = g_fPosition[client];
	
	if (GetEntityFlags(client) & FL_DUCKING)
	{
		// make height not affected by ducking
		fHeightOrigin[2] -= 9.0
	}
	
	if (fHeightOrigin[2] > g_fMaxHeight[client])
	{
		g_fMaxHeight[client] = fHeightOrigin[2];
	}
}

void IncStrafeCount(int client, float vel[3])
{
	if ((vel[1] > 0.0 && g_fLastVelInAir[client][1] <= 0.0)
	 || (vel[1] < 0.0 && g_fLastVelInAir[client][1] >= 0.0))
	{
		g_iStatStrafeCount[client]++;
	}
}

void CheckStrafeStats(int client, int &buttons, float vel[3], float speed, float lastspeed)
{
	if (g_iStatStrafeCount[client] > MAXSTRAFES)
	{
		return;
	}
	
	IncStrafeCount(client, vel);
	
	int strafe = g_iStatStrafeCount[client];
	
	g_fStatStrafeAirtime[client][strafe] += 1.0;
	
	if (CheckMaxSpeed(speed, lastspeed))
		g_fStatStrafeMax[client][strafe] = speed;
	
	if (IsOverlapping(buttons))
	{
		g_iStatStrafeOverlap[client][strafe]++;
	}
	else if (IsDeadAirtime(buttons))
	{
		g_iStatStrafeDead[client][strafe]++;
	}
	
	if (IsStrafeSynced(speed, lastspeed))
	{
		g_fStatStrafeGain[client][strafe] += speed - lastspeed;
		g_fStatStrafeSync[client][strafe] += 1.0;
	}
	else
	{
		g_fStatStrafeLoss[client][strafe] += lastspeed - speed;
	}
}