

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
	IncStrafeCount(client, vel);
	
	if (g_iStatStrafeCount[client] >= MAXSTRAFES)
	{
		return;
	}
	
	int iStrafe = g_iStatStrafeCount[client];
	
	g_fStatStrafeAirtime[client][iStrafe] += 1.0;
	
	if (CheckMaxSpeed(speed, lastspeed))
		g_fStatStrafeMax[client][iStrafe] = speed;
	
	if (IsOverlapping(buttons))
	{
		g_iStatStrafeOverlap[client][iStrafe]++;
	}
	else if (IsDeadAirtime(buttons))
	{
		g_iStatStrafeDead[client][iStrafe]++;
	}
	
	if (IsStrafeSynced(speed, lastspeed))
	{
		g_fStatStrafeGain[client][iStrafe] += speed - lastspeed;
		g_fStatStrafeSync[client][iStrafe] += 1.0;
	}
	else
	{
		g_fStatStrafeLoss[client][iStrafe] += lastspeed - speed;
	}
}