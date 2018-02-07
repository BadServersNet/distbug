#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

float g_fJumpPosition[MAXPLAYERS + 1][3];
float g_fLastPosInAir[MAXPLAYERS + 1][3];
float g_fLastSpeedInAir[MAXPLAYERS + 1][3];
float g_fTickRate;
int g_iFramesOnGround[MAXPLAYERS + 1];
bool g_bLastJump[MAXPLAYERS + 1];
bool g_bJumpEnd[MAXPLAYERS + 1] = false;

public Plugin myinfo = 
{
	name = "Distance Bug Fix", 
	author = "GameChaos", 
	description = "Fixes longjump distance bug", 
	version = "0.1"
}

public void OnPluginStart()
{
	g_fTickRate = 1 / GetTickInterval();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client))
	{
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			g_iFramesOnGround[client]++;
			
			if (g_iFramesOnGround[client] > 1)
			{
				if (buttons & IN_JUMP && !g_bLastJump[client])
				{
					GetClientAbsOrigin(client, g_fJumpPosition[client]);
					g_bJumpEnd[client] = false;
				}
			}
			else
			{
				if (!g_bJumpEnd[client])
				{
					JumpLand(client);
				}
			}
		}
		else if (GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			g_iFramesOnGround[client] = 0;
			
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fLastSpeedInAir[client]);
			GetClientAbsOrigin(client, g_fLastPosInAir[client]);
		}
		g_bLastJump[client] = !!(buttons & IN_JUMP);
	}
	return Plugin_Changed;
}

stock bool IsValidClient(client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client));
}

public JumpLand(int client)
{
	float speed[3];
	float position[3];
	float distance;
	
	GetClientAbsOrigin(client, position)
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", speed);
	
	speed[2] = g_fLastSpeedInAir[client][2] - 301.993377 / g_fTickRate;
	
	distance = CalcJumpDistance(client, g_fLastSpeedInAir[client], g_fTickRate, g_fLastPosInAir[client], g_fJumpPosition[client], speed, position);
	
	PrintToChat(client, "%f", distance);
	PrintToConsole(client, "%f", distance)
	
	g_bJumpEnd[client] = true;
}

stock float CalcJumpDistance(int client, float LastSpeedInAir[3], float TickRate, float LastPosInAir[3], float JumpPosition[3], float speed[3], float position[3])
{
	float pos[2];
	float px;
	float py;
	
	pos = ExtendVector(position, LastSpeedInAir, TickRate, LastPosInAir, speed, JumpPosition);
	px = FloatAbs(JumpPosition[0] - pos[0]);
	py = FloatAbs(JumpPosition[1] - pos[1]);
	return (CalcDistance(px, py) + 32.0);
}

stock float CalcDistance(float x, float y)
{
	return SquareRoot(x * x + y * y);
}

stock float ExtendVector(float position[3], float LastSpeedInAir[3], float TickRate, float LastPosInAir[3], float speed[3], float LJPos[3])
{
	float distMultiplier;
	float distMultiplierNB;
	float pos[2];
	
	distMultiplier = FloatAbs((LastPosInAir[2] - LJPos[2]) / (LastSpeedInAir[2] / TickRate));
	distMultiplierNB = FloatAbs((position[2] - LJPos[2]) / (speed[2] / TickRate));
	
	if (position[2] == LJPos[2])
	{
		pos[0] = LastPosInAir[0] + (LastSpeedInAir[0] / TickRate * distMultiplier);
		pos[1] = LastPosInAir[1] + (LastSpeedInAir[1] / TickRate * distMultiplier);
	}
	else
	{
		pos[0] = position[0] + (speed[0] / TickRate * distMultiplierNB);
		pos[1] = position[1] + (speed[1] / TickRate * distMultiplierNB);
	}
	return pos;
}