/*
 *
 * chat and console reporting
 *
 */

void PrintFailStat(int client, char[] szDist, char[] szEdge, char[] szJumpHeight, char[] szSync, char[] szAirtime, char[] szWRelease, char[] szOverlap, char[] szDeadAirtime, char[] szDeviation)
{
	char chatOutput[320];
	FormatEx(chatOutput, sizeof(chatOutput), "%s{grey} %s (Air: %.4f) [%s%s | %s | %s | %s | %s | %s | %s]",
			PREFIX, szDist, g_fFailAirDistance[client] + 32.0, szEdge, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime, szDeviation);
	
	CPrintToChat(client, chatOutput);
	
	char conOutput[320];
	strcopy(conOutput, sizeof(conOutput), chatOutput);
	CRemoveTags(conOutput, sizeof(conOutput));
	PrintToConsole(client, conOutput);
	
	EchoToSpectators(client, conOutput, chatOutput);
	
	if ((g_iSettings[client] & FL_SETTINGS_STRAFESTATS))
	{
		PrintStrafeStats(client,
			g_fFailStatStrafeGain[client],
			g_fFailStatStrafeLoss[client],
			g_fFailStatStrafeMax[client],
			g_fFailStatStrafeSync[client],
			g_fFailStatStrafeAirtime[client],
			g_iFailAirTime[client],
			g_iFailStatStrafeOverlap[client],
			g_iFailStatStrafeDead[client],
			g_iFailStatStrafeCount[client]);
	}
}

void PrintJumpstat(int client, char[] szDist, char[] szEdge, char[] szBlockdist, char[] szJumpHeight, char[] szSync, char[] szAirtime, char[] szWRelease, char[] szOverlap, char[] szDeadAirtime, char[] szDeviation)
{
	char chatOutput[320];
	FormatEx(chatOutput, sizeof(chatOutput), "%s{grey} %s (Air: %.4f) [%s%s%s | %s | %s | %s | %s | %s | %s]",
			PREFIX, szDist, g_fAirDistance[client] + 32.0, szEdge, szBlockdist, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime, szDeviation);
	
	CPrintToChat(client, chatOutput);
	
	char conOutput[320];
	strcopy(conOutput, sizeof(conOutput), chatOutput);
	CRemoveTags(conOutput, sizeof(conOutput));
	PrintToConsole(client, conOutput);
	
	EchoToSpectators(client, conOutput, chatOutput);
	
	if ((g_iSettings[client] & FL_SETTINGS_STRAFESTATS))
	{
		PrintStrafeStats(client,
			g_fStatStrafeGain[client],
			g_fStatStrafeLoss[client],
			g_fStatStrafeMax[client],
			g_fStatStrafeSync[client],
			g_fStatStrafeAirtime[client],
			g_iFramesInAir[client],
			g_iStatStrafeOverlap[client],
			g_iStatStrafeDead[client],
			g_iStatStrafeCount[client]);
	}
}

void PrintStrafeStats(int client, float gain[MAXSTRAFES],
	float loss[MAXSTRAFES], float max[MAXSTRAFES], float strafeSync[MAXSTRAFES],
	float strafeAirtime[MAXSTRAFES], int jumpAirtime, int overlap[MAXSTRAFES],
	int deadAirtime[MAXSTRAFES], int strafeCount)
{
	char strafeStats[2048];
	float sync;
	int airtime;
	float avgGain;
	
	FormatEx(strafeStats, sizeof(strafeStats), "#.    Sync    Gain    Loss      Max  Airtime  OL  DA   Avg Gain\n");
	for (int i = 1; i <= strafeCount && i < MAXSTRAFES; i++)
	{
		char szSync[16];
		char szGain[16];
		char szLoss[16];
		char szMax[16];
		char szAirtime[16];
		char szOverlap[16];
		char szDead[16];
		char szAvgGain[16];
		
		airtime = RoundFloat(strafeAirtime[i]); // / jumpAirtime * 100.0;
		sync = strafeSync[i] / strafeAirtime[i] * 100;
		avgGain = gain[i] / strafeAirtime[i]; //* (strafeAirtime[i] / g_fTickRate);
		
		FormatEx(szSync, sizeof(szSync), "%5.1f", sync);
		FormatEx(szGain, sizeof(szGain), "%6.2f", gain[i]);
		FormatEx(szLoss, sizeof(szLoss), "%6.2f", loss[i]);
		FormatEx(szMax, sizeof(szMax), "%5.1f", max[i]);
		FormatEx(szAirtime, sizeof(szAirtime), "%7i", airtime);
		FormatEx(szOverlap, sizeof(szOverlap), "%3i", overlap[i]);
		FormatEx(szDead, sizeof(szDead), "%3i", deadAirtime[i]);
		FormatEx(szAvgGain, sizeof(szAvgGain), "%3.2f", avgGain);
		
		Format(strafeStats, sizeof(strafeStats), "%s%i.  %s%s  %s  %s    %s  %s %s %s       %s\n",
			strafeStats, i, szSync, PERCENT, szGain, szLoss, szMax, szAirtime, szOverlap, szDead, szAvgGain);
	}
	
	PrintToConsole(client, strafeStats);
	EchoToSpectators(client, strafeStats, NULL_STRING);
}

void EchoToSpectators(int client, const char[] conOutput, const char[] chatOutput)
{
	if (IsNullString(conOutput) &&
		IsNullString(chatOutput))
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsValidClient(i) || !IsClientObserver(i))
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
		
		if (!IsNullString(conOutput))
		{
			PrintToConsole(i, conOutput);
		}
		
		if (!IsNullString(chatOutput))
		{
			CPrintToChat(i, "%s", chatOutput);
		}
	}
} 


// formatting

void FormatFailDist(char[] buffer, int maxlen, float distance)
{
	FormatEx(buffer, maxlen, "FAILED: {default}%.4f{grey}", distance);
}

void FormatDist(char[] buffer, int maxlen, float distance)
{
	FormatEx(buffer, maxlen, "LJ: {default}%.4f{grey}", distance);
}

void FormatAirtime(char[] buffer, int maxlen, int airTime)
{
	FormatEx(buffer, maxlen, "Air: {lime}%i{grey}", airTime);
}

void FormatSync(char[] buffer, int maxlen, int iSync, int airTime)
{
	float sync = (iSync + 0.0) / (airTime + 0.0) * 100.0;
	FormatEx(buffer, maxlen, "Sync: {lime}%.1f%%%{grey}", sync);
}

void FormatHeight(int client, char[] buffer, int maxlen)
{
	float jumpHeight = g_fMaxHeight[client] - g_fJumpPosition[client][2];
	FormatEx(buffer, maxlen, "Height: {lime}%.2f{grey}", jumpHeight);
}

void FormatWRelease(int client, char[] buffer, int maxlen)
{
	// calculate w release
	int iWRelease = g_iWReleaseFrame[client] - g_iJumpFrame[client];
	
	// format w release
	if (iWRelease == 0)
	{
		FormatEx(buffer, maxlen, "-W: {green}✓{grey}");
	}
	else if (abs(iWRelease) > 16)
	{
		FormatEx(buffer, maxlen, "-W: {grey}No{grey}");
	}
	else if (iWRelease > 0)
	{
		FormatEx(buffer, maxlen, "-W: {darkred}+%i{grey}", iWRelease);
	}
	else
	{
		FormatEx(buffer, maxlen, "-W: {steelblue}%i{grey}", iWRelease);
	}
}

void FormatBlockDistance(char[] buffer, int maxlen, float fBlockDist)
{
	if (IsFloatInRange(fBlockDist, g_fMinJumpDistance, g_fMaxJumpDistance))
	{
		FormatEx(buffer, maxlen, "Block: {default}%i{grey} | ", RoundFloat(fBlockDist));
	}
}

void FormatEdge(int client, char[] buffer, int maxlen)
{
	if (g_fJEdge[client] >= 0.0 && g_fJEdge[client] < MAXEDGE)
	{
		FormatEx(buffer, maxlen, "Edge: {default}%.3f{grey} | ", g_fJEdge[client]);
	}
}

void FormatOverlap(char[] buffer, int maxlen, int overlap)
{
	FormatEx(buffer, maxlen, "OL: {lime}%i{grey}", overlap);
}

void FormatDeadAirtime(char[] buffer, int maxlen, int deadAirtime)
{
	FormatEx(buffer, maxlen, "DA: {lime}%i{grey}", deadAirtime);
}

void FormatDeviation(char[] buffer, int maxlen, const float fJumpGround[3], float fLandGround[3])
{
	float fDeviation;
	float fXDeviation = FloatAbs(fJumpGround[0] - fLandGround[0]);
	float fYDeviation = FloatAbs(fJumpGround[1] - fLandGround[1]);
	
	if (fXDeviation > fYDeviation)
	{
		fDeviation = fYDeviation;
	}
	else
	{
		fDeviation = fXDeviation;
	}
	
	FormatEx(buffer, maxlen, "Deviation: {lime}%.3f{grey}", fDeviation);
}