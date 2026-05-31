
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors>

#pragma newdecls required
#pragma semicolon 1

#if defined DEBUG
#define DEBUG_CHAT(%1) PrintToChat(%1);
#define DEBUG_CHATALL(%1) PrintToChatAll(%1);
#define DEBUG_CONSOLE(%1) PrintToConsole(%1);
#else
#define DEBUG_CHAT(%1)
#define DEBUG_CHATALL(%1)
#define DEBUG_CONSOLE(%1)
#endif

#include <gamechaos>
#include <distbugfix>

char g_jumpTypes[JumpType][] = {
	"NONE",
	"LJ",
	"WJ",
	"LAJ",
	"BH",
	"CBH",
};

stock char g_szStrafeType[StrafeType][] = {
	"$", // STRAFETYPE_OVERLAP
	".", // STRAFETYPE_NONE
	
	"█", // STRAFETYPE_LEFT
	"#", // STRAFETYPE_OVERLAP_LEFT
	"H", // STRAFETYPE_NONE_LEFT
	
	"█", // STRAFETYPE_RIGHT
	"#", // STRAFETYPE_OVERLAP_RIGHT
	"H", // STRAFETYPE_NONE_RIGHT
};

stock char g_szStrafeTypeColour[][] = {
	"<font color='#FF00FF'>|", // overlap
	"<font color='#000000'>|", // none
	"<font color='#FFFFFF'>|", // left
	"<font color='#00BFBF'>|", // overlap_left
	"<font color='#408040'>|", // none_left
	"<font color='#FFFFFF'>|", // right
	"<font color='#00BFBF'>|", // overlap_right
	"<font color='#408040'>|", // none_right
};

stock bool g_jumpTypePrintable[JumpType] = {
	false, // JUMPTYPE_NONE,
	
	true, // longjump
	true, // weirdjump
	true, // ladderjump
	true, // bunnyhop
	true, // ducked bunnyhop
};

stock char g_jumpDirString[JumpDir][] = {
	"Forwards",
	"Backwards",
	"Sideways",
	"Sideways"
};

stock int g_jumpDirForwardButton[JumpDir] = {
	IN_FORWARD,
	IN_BACK,
	IN_MOVELEFT,
	IN_MOVERIGHT,
};

stock int g_jumpDirLeftButton[JumpDir] = {
	IN_MOVELEFT,
	IN_MOVERIGHT,
	IN_BACK,
	IN_FORWARD,
};

stock int g_jumpDirRightButton[JumpDir] = {
	IN_MOVERIGHT,
	IN_MOVELEFT,
	IN_FORWARD,
	IN_BACK,
};

bool g_lateLoad;

PlayerData g_pd[MAXPLAYERS + 1];
PlayerData g_failstatPD[MAXPLAYERS + 1];
int g_beamSprite;

ConVar g_airaccelerate;
ConVar g_gravity;
ConVar g_maxvelocity;

ConVar g_jumpRange[JumpType][2];

#include "distbugfix/clientprefs.sp"

public Plugin myinfo =
{
	name = "Distance Bug Fix",
	author = "GameChaos",
	description = "Fixes longjump distance bug",
	version = DISTBUG_VERSION,
	url = "https://bitbucket.org/GameChaos/distbug/src"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_distbug", Command_Distbug, "Toggle distbug on/off.");
	RegConsoleCmd("sm_distbugversion", Command_Distbugversion, "Print distbug version.");
	
	RegConsoleCmd("sm_distbugbeam", CommandBeam, "Toggle jump beam.");
	RegConsoleCmd("sm_distbugveerbeam", CommandVeerbeam, "Toggle veer beam.");
	RegConsoleCmd("sm_distbughudgraph", CommandHudgraph, "Toggle hud strafe graph.");
	RegConsoleCmd("sm_strafestats", CommandStrafestats, "Toggle distbug strafestats.");
	RegConsoleCmd("sm_distbugstrafegraph", CommandStrafegraph, "Toggle console strafe graph.");
	RegConsoleCmd("sm_distbugadvchat", CommandAdvchat, "Toggle advanced chat stats.");
	RegConsoleCmd("sm_distbughelp", CommandHelp, "Distbug command list.");
	
	g_airaccelerate = FindConVar("sv_airaccelerate");
	g_gravity = FindConVar("sv_gravity");
	g_maxvelocity = FindConVar("sv_maxvelocity");
	
	g_jumpRange[JUMPTYPE_LJ][0] = CreateConVar("distbug_lj_min_dist", "210.0");
	g_jumpRange[JUMPTYPE_LJ][1] = CreateConVar("distbug_lj_max_dist", "310.0");
	
	g_jumpRange[JUMPTYPE_WJ][0] = CreateConVar("distbug_wj_min_dist", "210.0");
	g_jumpRange[JUMPTYPE_WJ][1] = CreateConVar("distbug_wj_max_dist", "390.0");
	
	g_jumpRange[JUMPTYPE_LAJ][0] = CreateConVar("distbug_laj_min_dist", "70.0");
	g_jumpRange[JUMPTYPE_LAJ][1] = CreateConVar("distbug_laj_max_dist", "250.0");
	
	g_jumpRange[JUMPTYPE_BH][0] = CreateConVar("distbug_bh_min_dist", "210.0");
	g_jumpRange[JUMPTYPE_BH][1] = CreateConVar("distbug_bh_max_dist", "390.0");
	
	g_jumpRange[JUMPTYPE_CBH][0] = CreateConVar("distbug_cbh_min_dist", "200.0");
	g_jumpRange[JUMPTYPE_CBH][1] = CreateConVar("distbug_cbh_max_dist", "390.0");
	
	AutoExecConfig(.name = DISTBUG_CONFIG_NAME);
	
	HookEvent("player_jump", Event_PlayerJump);
	
	OnPluginStart_Clientprefs();
	if (g_lateLoad)
	{
		for (int client = 0; client <= MaxClients; client++)
		{
			if (GCIsValidClient(client))
			{
				OnClientPutInServer(client);
				OnClientCookiesCached(client);
			}
		}
	}
}

public void OnMapStart()
{
	g_beamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, PlayerPostThink);
	g_pd[client].tickCount = 0;
}

public void OnClientCookiesCached(int client)
{
	OnClientCookiesCached_Clientprefs(client);
}

public void Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsSettingEnabled(client, SETTINGS_DISTBUG_ENABLED))
	{
		return;
	}
	
	if (GCIsValidClient(client, true))
	{
		bool duckbhop = !!(g_pd[client].flags & FL_DUCKING);
		float groundOffset = g_pd[client].position[2] - g_pd[client].lastGroundPos[2];
		JumpType jumpType = JUMPTYPE_NONE;
		if (g_pd[client].framesOnGround <= MAX_BHOP_FRAMES)
		{
			if (g_pd[client].lastGroundPosWalkedOff && groundOffset < 0.0)
			{
				jumpType = JUMPTYPE_WJ;
			}
			else
			{
				if (duckbhop)
				{
					jumpType = JUMPTYPE_CBH;
				}
				else
				{
					jumpType = JUMPTYPE_BH;
				}
			}
		}
		else
		{
			jumpType = JUMPTYPE_LJ;
		}
		
		if (jumpType != JUMPTYPE_NONE)
		{
			OnPlayerJumped(client, g_pd[client], jumpType);
		}
		
		g_pd[client].lastGroundPos = g_pd[client].lastPosition;
		g_pd[client].lastGroundPosWalkedOff = false;
	}
}

public Action Command_Distbugversion(int client, int args)
{
	ReplyToCommand(client, "Distbugfix version: %s", DISTBUG_VERSION);
	return Plugin_Handled;
}

public Action Command_Distbug(int client, int args)
{
	ToggleSetting(client, SETTINGS_DISTBUG_ENABLED);
	CPrintToChat(client, "%s Distbug has been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_DISTBUG_ENABLED) ? "enabled." : "disabled.");
	
	return Plugin_Handled;
}

public Action CommandBeam(int client, int args)
{
	ToggleSetting(client, SETTINGS_SHOW_JUMP_BEAM);
	CPrintToChat(client, "%s Jump beam has been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_SHOW_JUMP_BEAM) ? "enabled." : "disabled.");
	
	return Plugin_Handled;
}

public Action CommandVeerbeam(int client, int args)
{
	ToggleSetting(client, SETTINGS_SHOW_VEER_BEAM);
	CPrintToChat(client, "%s Veer beam has been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_SHOW_VEER_BEAM) ? "enabled." : "disabled.");
	
	return Plugin_Handled;
}

public Action CommandHudgraph(int client, int args)
{
	ToggleSetting(client, SETTINGS_SHOW_HUD_GRAPH);
	CPrintToChat(client, "%s Hud stats have been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_SHOW_HUD_GRAPH) ? "enabled." : "disabled.");
	
	return Plugin_Handled;
}

public Action CommandStrafestats(int client, int args)
{
	ToggleSetting(client, SETTINGS_DISABLE_STRAFE_STATS);
	CPrintToChat(client, "%s Strafe stats have been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_DISABLE_STRAFE_STATS) ? "disabled." : "enabled.");
	
	return Plugin_Handled;
}

public Action CommandStrafegraph(int client, int args)
{
	ToggleSetting(client, SETTINGS_DISABLE_STRAFE_GRAPH);
	CPrintToChat(client, "%s Console strafe graph has been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_DISABLE_STRAFE_GRAPH) ? "disabled." : "enabled.");
	
	return Plugin_Handled;
}

public Action CommandAdvchat(int client, int args)
{
	ToggleSetting(client, SETTINGS_ADV_CHAT_STATS);
	CPrintToChat(client, "%s Advanced chat stats have been %s", CHAT_PREFIX,
		IsSettingEnabled(client, SETTINGS_ADV_CHAT_STATS) ? "enabled." : "disabled.");
	
	return Plugin_Handled;
}

public Action CommandHelp(int client, int args)
{
	CPrintToChat(client, "%s Look in the console for a list of distbug commands!", CHAT_PREFIX);
	PrintToConsole(client, "%s", "Distbug command list:\n" ...\
		"sm_distbug            - Toggle distbug on/off.\n" ...\
		"sm_distbugversion     - Print distbug version.\n" ...\
		"sm_distbugbeam        - Toggle jump beam.\n" ...\
		"sm_distbugveerbeam    - Toggle veer beam.\n" ...\
		"sm_distbughudgraph    - Toggle hud strafe graph.\n" ...\
		"sm_strafestats        - Toggle distbug strafestats.\n" ...\
		"sm_distbugstrafegraph - Toggle console strafe graph.\n" ...\
		"sm_distbugadvchat     - Toggle advanced chat stats.\n" ...\
		"sm_distbughelp        - Distbug command list.\n");
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!GCIsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	if (!IsSettingEnabled(client, SETTINGS_DISTBUG_ENABLED))
	{
		return Plugin_Continue;
	}
	
	g_pd[client].lastSidemove    = g_pd[client].sidemove;
	g_pd[client].lastForwardmove = g_pd[client].forwardmove;
	g_pd[client].sidemove    = vel[1];
	g_pd[client].forwardmove = vel[0];
	
	return Plugin_Continue;
}

public void PlayerPostThink(int client)
{
	if (!GCIsValidClient(client, true))
	{
		return;
	}
	
	int flags = GetEntityFlags(client);
	g_pd[client].lastButtons = g_pd[client].buttons;
	g_pd[client].buttons = GetClientButtons(client);
	g_pd[client].lastFlags = g_pd[client].flags;
	g_pd[client].flags = flags;
	g_pd[client].lastPosition = g_pd[client].position;
	g_pd[client].lastAngles   = g_pd[client].angles;
	g_pd[client].lastVelocity = g_pd[client].velocity;
	GetClientAbsOrigin(client, g_pd[client].position);
	GetClientEyeAngles(client, g_pd[client].angles);
	GCGetClientVelocity(client, g_pd[client].velocity);
	GetEntPropVector(client, Prop_Send, "m_vecLadderNormal", g_pd[client].ladderNormal);
	
	if (flags & FL_ONGROUND)
	{
		g_pd[client].framesInAir = 0;
		g_pd[client].framesOnGround++;
	}
	else if (g_pd[client].movetype != MOVETYPE_LADDER)
	{
		g_pd[client].framesInAir++;
		g_pd[client].framesOnGround = 0;
	}
	
	g_pd[client].lastMovetype = g_pd[client].movetype;
	g_pd[client].movetype = GetEntityMoveType(client);
	g_pd[client].stamina = GCGetClientStamina(client);
	g_pd[client].lastStamina = g_pd[client].stamina;
	g_pd[client].gravity = GetEntityGravity(client);
	
	// LJ stuff
	if (IsSettingEnabled(client, SETTINGS_DISTBUG_ENABLED))
	{
		if (g_pd[client].framesInAir == 1)
		{
			if (!GCVectorsEqual(g_pd[client].lastGroundPos, g_pd[client].lastPosition))
			{
				g_pd[client].lastGroundPos = g_pd[client].lastPosition;
				g_pd[client].lastGroundPosWalkedOff = true;
			}
		}
		
		bool forwardReleased = (g_pd[client].lastButtons & g_jumpDirForwardButton[g_pd[client].jumpDir])
			&& !(g_pd[client].buttons & g_jumpDirForwardButton[g_pd[client].jumpDir]);
		if (forwardReleased)
		{
			g_pd[client].fwdReleaseFrame = g_pd[client].tickCount;
		}
		
		if (!g_pd[client].trackingJump
			&& g_pd[client].movetype == MOVETYPE_WALK
			&& g_pd[client].lastMovetype == MOVETYPE_LADDER)
		{
			OnPlayerJumped(client, g_pd[client], JUMPTYPE_LAJ);
		}
		
		if (g_pd[client].framesOnGround == 1)
		{
			TrackJump(g_pd[client], g_failstatPD[client]);
			OnPlayerLanded(client, g_pd[client], g_failstatPD[client]);
		}
		
		if (g_pd[client].trackingJump)
		{
			TrackJump(g_pd[client], g_failstatPD[client]);
		}
	}
	g_pd[client].tickCount++;
	
	
#if defined(DEBUG)
	SetHudTextParams(-1.0, 0.2, 0.02, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, "pos: %f %f %f", g_pd[client].position[0], g_pd[client].position[1], g_pd[client].position[2]);
#endif
}

bool IsSpectating(int spectator, int target)
{
	if (spectator != target && GCIsValidClient(spectator))
	{
		int specMode = GetEntProp(spectator, Prop_Send, "m_iObserverMode");
		if (specMode == 4 || specMode == 5)
		{
			if (GetEntPropEnt(spectator, Prop_Send, "m_hObserverTarget") == target)
			{
				return true;
			}
		}
	}
	return false;
}

void ClientAndSpecsPrintChat(int client, const char[] format, any ...)
{
	static char message[1024];
	VFormat(message, sizeof(message), format, 3);
	CPrintToChat(client, "%s", message);
	
	for (int spec = 1; spec <= MaxClients; spec++)
	{
		if (IsSpectating(spec, client) && IsSettingEnabled(spec, SETTINGS_DISTBUG_ENABLED))
		{
			CPrintToChat(spec, "%s", message);
		}
	}
}

void ClientAndSpecsPrintConsole(int client, const char[] format, any ...)
{
	static char message[1024];
	VFormat(message, sizeof(message), format, 3);
	PrintToConsole(client, "%s", message);
	
	for (int spec = 1; spec < MAXPLAYERS; spec++)
	{
		if (IsSpectating(spec, client) && IsSettingEnabled(spec, SETTINGS_DISTBUG_ENABLED))
		{
			PrintToConsole(spec, "%s", message);
		}
	}
}

void ResetJump(PlayerData pd)
{
	// NOTE: only resets things that need to be reset
	for (int i = 0; i < 3; i++)
	{
		pd.jumpPos[i] = 0.0;
		pd.landPos[i] = 0.0;
	}
	pd.trackingJump = false;
	pd.failedJump = false;
	pd.jumpGotFailstats = false;
	
	// Jump data
	// pd.jumpType = JUMPTYPE_NONE;
	// NOTE: don't reset jumpType or lastJumpType
	pd.jumpMaxspeed = 0.0;
	pd.jumpSync = 0.0;
	pd.jumpEdge = 0.0;
	pd.jumpBlockDist = 0.0;
	pd.jumpHeight = 0.0;
	pd.jumpAirtime = 0;
	pd.jumpOverlap = 0;
	pd.jumpDeadair = 0;
	pd.jumpAirpath = 0.0;
	
	pd.strafeCount = 0;
	for (int i = 0; i < MAX_STRAFES; i++)
	{
		pd.strafeSync[i] = 0.0;
		pd.strafeGain[i] = 0.0;
		pd.strafeLoss[i] = 0.0;
		pd.strafeMax[i] = 0.0;
		pd.strafeAirtime[i] = 0;
		pd.strafeOverlap[i] = 0;
		pd.strafeDeadair[i] = 0;
		pd.strafeAvgGain[i] = 0.0;
		pd.strafeAvgEfficiency[i] = 0.0;
		pd.strafeAvgEfficiencyCount[i] = 0;
		pd.strafeMaxEfficiency[i] = GC_FLOAT_NEGATIVE_INFINITY;
	}
}

bool IsWishspeedMovingLeft(float forwardspeed, float sidespeed, JumpDir jumpDir)
{
	if (jumpDir == JUMPDIR_FORWARDS)
	{
		return sidespeed < 0.0;
	}
	else if (jumpDir == JUMPDIR_BACKWARDS)
	{
		return sidespeed > 0.0;
	}
	else if (jumpDir == JUMPDIR_LEFT)
	{
		return forwardspeed < 0.0;
	}
	// else if (jumpDir == JUMPDIR_RIGHT)
	return forwardspeed > 0.0;
}

bool IsWishspeedMovingRight(float forwardspeed, float sidespeed, JumpDir jumpDir)
{
	if (jumpDir == JUMPDIR_FORWARDS)
	{
		return sidespeed > 0.0;
	}
	else if (jumpDir == JUMPDIR_BACKWARDS)
	{
		return sidespeed < 0.0;
	}
	else if (jumpDir == JUMPDIR_LEFT)
	{
		return forwardspeed > 0.0;
	}
	// else if (jumpDir == JUMPDIR_RIGHT)
	return forwardspeed < 0.0;
}

bool IsNewStrafe(PlayerData pd)
{
	if (pd.jumpDir == JUMPDIR_FORWARDS || pd.jumpDir == JUMPDIR_BACKWARDS)
	{
		return ((pd.sidemove > 0.0 && pd.lastSidemove <= 0.0)
				|| (pd.sidemove < 0.0 && pd.lastSidemove >= 0.0))
				&& pd.jumpAirtime != 1;
	}
	// else if (pd.jumpDir == JUMPDIR_LEFT || pd.jumpDir == JUMPDIR_RIGHT)
	return ((pd.forwardmove > 0.0 && pd.lastForwardmove <= 0.0)
				|| (pd.forwardmove < 0.0 && pd.lastForwardmove >= 0.0))
				&& pd.jumpAirtime != 1;
}

void TrackJump(PlayerData pd, PlayerData failstatPD)
{
#if defined(DEBUG)
	SetHudTextParams(-1.0, 0.2, 0.02, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(1, -1, "FOG: %i\njumpAirtime: %i\ntrackingJump: %i", pd.framesOnGround, pd.jumpAirtime, pd.trackingJump);
#endif
	
	if (pd.framesOnGround > MAX_BHOP_FRAMES
		&& pd.jumpAirtime && pd.trackingJump)
	{
		ResetJump(pd);
	}
	
	if (pd.jumpType == JUMPTYPE_NONE
		|| !g_jumpTypePrintable[pd.jumpType])
	{
		pd.trackingJump = false;
		return;
	}
	
	if (pd.movetype != MOVETYPE_WALK
		&& pd.movetype != MOVETYPE_LADDER)
	{
		ResetJump(pd);
	}
	
	float frametime = GetTickInterval();
	// crusty teleport detection
	{
		float posDelta[3];
		SubtractVectors(pd.position, pd.lastPosition, posDelta);
		
		float moveLength = GetVectorLength(posDelta);
		// NOTE: 1.73205081 * sv_maxvelocity is the max velocity magnitude you can get.
		if (moveLength > g_maxvelocity.FloatValue * 1.73205081 * frametime)
		{
			ResetJump(pd);
			return;
		}
	}
	
	int beamIndex = pd.jumpAirtime;
	if (beamIndex < MAX_JUMP_FRAMES)
	{
		pd.jumpBeamX[beamIndex] = pd.position[0];
		pd.jumpBeamY[beamIndex] = pd.position[1];
		pd.jumpBeamColour[beamIndex] = JUMPBEAM_NEUTRAL;
	}
	pd.jumpAirtime++;
	
	
	float speed = GCGetVectorLength2D(pd.velocity);
	if (speed > pd.jumpMaxspeed)
	{
		pd.jumpMaxspeed = speed;
	}
	
	float lastSpeed = GCGetVectorLength2D(pd.lastVelocity);
	if (speed > lastSpeed)
	{
		pd.jumpSync++;
		if (beamIndex < MAX_JUMP_FRAMES)
		{
			pd.jumpBeamColour[beamIndex] = JUMPBEAM_GAIN;
		}
	}
	else if (speed < lastSpeed && beamIndex < MAX_JUMP_FRAMES)
	{
		pd.jumpBeamColour[beamIndex] = JUMPBEAM_LOSS;
	}
	
	if (pd.flags & FL_DUCKING && beamIndex < MAX_JUMP_FRAMES)
	{
		pd.jumpBeamColour[beamIndex] = JUMPBEAM_DUCK;
	}
	
	float height = pd.position[2] - pd.jumpPos[2];
	if (height > pd.jumpHeight)
	{
		pd.jumpHeight = height;
	}
	
	if (IsOverlapping(pd.buttons, pd.jumpDir))
	{
		pd.jumpOverlap++;
	}
	
	if (IsDeadAirtime(pd.buttons, pd.jumpDir))
	{
		pd.jumpDeadair++;
	}
	
	// strafestats!
	if (pd.strafeCount + 1 < MAX_STRAFES)
	{
		if (IsNewStrafe(pd))
		{
			pd.strafeCount++;
		}
		
		int strafe = pd.strafeCount;
		
		pd.strafeAirtime[strafe]++;
		
		if (speed > lastSpeed)
		{
			pd.strafeSync[strafe] += 1.0;
			pd.strafeGain[strafe] += speed - lastSpeed;
		}
		else if (speed < lastSpeed)
		{
			pd.strafeLoss[strafe] += lastSpeed - speed;
		}
		
		if (speed > pd.strafeMax[strafe])
		{
			pd.strafeMax[strafe] = speed;
		}
		
		if (IsOverlapping(pd.buttons, pd.jumpDir))
		{
			pd.strafeOverlap[strafe]++;
		}
		
		if (IsDeadAirtime(pd.buttons, pd.jumpDir))
		{
			pd.strafeDeadair[strafe]++;
		}
		
		// efficiency!
		{
			float maxWishspeed = 30.0;
			float airaccelerate = g_airaccelerate.FloatValue;
			// NOTE: Assume 250 maxspeed cos this is KZ!
			float maxspeed = 250.0;
			if (pd.flags & FL_DUCKING)
			{
				maxspeed *= 0.34;
			}
			else if (pd.buttons & IN_SPEED)
			{
				maxspeed *= 0.52;
			}
			
			if (pd.lastStamina > 0)
			{
				float speedScale = GCFloatClamp(1.0 - pd.lastStamina / 100.0, 0.0, 1.0);
				speedScale *= speedScale;
				maxspeed *= speedScale;
			}
			
			// calculate zvel 1 tick before pd.lastVelocity and during movement processing
			float zvel = pd.lastVelocity[2] + (g_gravity.FloatValue * frametime * 0.5 * pd.gravity);
			if (zvel > 0.0 && zvel <= 140.0)
			{
				maxspeed *= 0.25;
			}
			
			float yawdiff = FloatAbs(GCNormaliseYaw(pd.angles[1] - pd.lastAngles[1]));
			float perfectYawDiff = yawdiff;
			if (lastSpeed > 0.0)
			{
				float accelspeed = airaccelerate * maxspeed * frametime;
				if (accelspeed > maxWishspeed)
				{
					accelspeed = maxWishspeed;
				}
				if (lastSpeed >= maxWishspeed)
				{
					perfectYawDiff = RadToDeg(ArcSine(accelspeed / lastSpeed));
				}
				else
				{
					perfectYawDiff = 0.0;
				}
			}
			float efficiency = 100.0;
			if (perfectYawDiff != 0.0)
			{
				efficiency = (yawdiff - perfectYawDiff) / perfectYawDiff * 100.0 + 100.0;
			}
			
			pd.strafeAvgEfficiency[strafe] += efficiency;
			pd.strafeAvgEfficiencyCount[strafe]++;
			if (efficiency > pd.strafeMaxEfficiency[strafe])
			{
				pd.strafeMaxEfficiency[strafe] = efficiency;
			}
			
			DEBUG_CONSOLE(1, "%i\t%f\t%f\t%f\t%f\t%f", strafe, (yawdiff - perfectYawDiff), pd.sidemove, yawdiff, perfectYawDiff, speed)
		}
	}
	
	// strafe type and mouse graph
	if (pd.jumpAirtime - 1 < MAX_JUMP_FRAMES)
	{
		StrafeType strafeType = STRAFETYPE_NONE;
		
		bool moveLeft = !!(pd.buttons & g_jumpDirLeftButton[pd.jumpDir]);
		bool moveRight = !!(pd.buttons & g_jumpDirRightButton[pd.jumpDir]);
		
		bool velLeft = IsWishspeedMovingLeft(pd.forwardmove, pd.sidemove, pd.jumpDir);
		bool velRight = IsWishspeedMovingRight(pd.forwardmove, pd.sidemove, pd.jumpDir);
		bool velIsZero = !velLeft && !velRight;
		
		if (moveLeft && !moveRight && velLeft)
		{
			strafeType = STRAFETYPE_LEFT;
		}
		else if (moveRight && !moveLeft && velRight)
		{
			strafeType = STRAFETYPE_RIGHT;
		}
		else if (moveRight && !moveLeft && velRight)
		{
			strafeType = STRAFETYPE_LEFT;
		}
		else if (moveRight && moveLeft && velIsZero)
		{
			strafeType = STRAFETYPE_OVERLAP;
		}
		else if (moveRight && moveLeft && velLeft)
		{
			strafeType = STRAFETYPE_OVERLAP_LEFT;
		}
		else if (moveRight && moveLeft && velRight)
		{
			strafeType = STRAFETYPE_OVERLAP_RIGHT;
		}
		else if (!moveRight && !moveLeft && velIsZero)
		{
			strafeType = STRAFETYPE_NONE;
		}
		else if (!moveRight && !moveLeft && velLeft)
		{
			strafeType = STRAFETYPE_NONE_LEFT;
		}
		else if (!moveRight && !moveLeft && velRight)
		{
			strafeType = STRAFETYPE_NONE_RIGHT;
		}
		
		pd.strafeGraph[pd.jumpAirtime - 1] = strafeType;
		float yawDiff = GCNormaliseYaw(pd.angles[1] - pd.lastAngles[1]);
		// Offset index by 2 to align mouse movement with button presses.
		int yawIndex = GCIntMax(pd.jumpAirtime - 2, 0);
		pd.mouseGraph[yawIndex] = yawDiff;
	}
	// check for failstat after jump tracking is done
	float duckedPos[3];
	duckedPos = pd.position;
	if (!(pd.flags & FL_DUCKING))
	{
		duckedPos[2] += 9.0;
	}
	
	// only save failed jump if we're at the fail threshold
	if ((pd.position[2] < pd.jumpPos[2])
		&& (pd.position[2] > pd.jumpPos[2] + (pd.velocity[2] * frametime)))
	{
		pd.jumpGotFailstats = true;
		failstatPD = pd;
	}
	
	// airpath.
	// NOTE: Track airpath after failstatPD has been saved, so
	// we don't track the last frame of failstats. That should
	// happen inside of FinishTrackingJump, because we need the real landing position.
	if (!pd.framesOnGround)
	{
		// NOTE: there's a special case for landing frame.
		float delta[3];
		SubtractVectors(pd.position, pd.lastPosition, delta);
		pd.jumpAirpath += GCGetVectorLength2D(delta);
	}
}

void OnPlayerFailstat(int client, PlayerData pd)
{
	if (!pd.jumpGotFailstats)
	{
		ResetJump(pd);
		return;
	}
	
	pd.failedJump = true;
	
	// undo half the gravity
	float gravity = g_gravity.FloatValue * pd.gravity;
	float frametime = GetTickInterval();
	float fixedVelocity[3];
	fixedVelocity = pd.velocity;
	fixedVelocity[2] += gravity * 0.5 * frametime;
	
	// fix incorrect distance when ducking / unducking at the right time
	float lastPosition[3];
	lastPosition = pd.lastPosition;
	bool lastDucking = !!(pd.lastFlags & FL_DUCKING);
	bool ducking = !!(pd.flags & FL_DUCKING);
	if (!lastDucking && ducking)
	{
		lastPosition[2] += 9.0;
	}
	else if (lastDucking && !ducking)
	{
		lastPosition[2] -= 9.0;
	}
	
	GetRealLandingOrigin(pd.jumpPos[2], lastPosition, fixedVelocity, pd.landPos);
	pd.jumpDistance = GCGetVectorDistance2D(pd.jumpPos, pd.landPos);
	if (pd.jumpType != JUMPTYPE_LAJ)
	{
		pd.jumpDistance += 32.0;
	}
	
	FinishTrackingJump(client, pd);
	PrintStats(client, pd);
	ResetJump(pd);
}

void OnPlayerJumped(int client, PlayerData pd, JumpType jumpType)
{
	pd.lastJumpType = pd.jumpType;
	ResetJump(pd);
	pd.jumpType = jumpType;
	if (g_jumpTypePrintable[jumpType])
	{
		pd.trackingJump = true;
	}
	
	pd.prespeedFog = pd.framesOnGround;
	pd.prespeedStamina = pd.stamina;
	
	// DEBUG_CHAT(1, "jump type: %s last jump type: %s", g_jumpTypes[jumpType], g_jumpTypes[pd.lastJumpType])
	
	// jump direction
	float speed = GCGetVectorLength2D(pd.velocity);
	pd.jumpDir = JUMPDIR_FORWARDS;
	// NOTE: Ladderjump pres can be super wild and can generate random
	// jump directions, so default to forward for ladderjumps.
	if (speed > 50.0 && pd.jumpType != JUMPTYPE_LAJ)
	{
		float velDir = RadToDeg(ArcTangent2(pd.velocity[1], pd.velocity[0]));
		float dir = GCNormaliseYaw(pd.angles[1] - velDir);
		
		if (GCIsFloatInRange(dir, 45.0, 135.0))
		{
			pd.jumpDir = JUMPDIR_RIGHT;
		}
		if (GCIsFloatInRange(dir, -135.0, -45.0))
		{
			pd.jumpDir = JUMPDIR_LEFT;
		}
		else if (dir > 135.0 || dir < -135.0)
		{
			pd.jumpDir = JUMPDIR_BACKWARDS;
		}
	}
	
	if (jumpType != JUMPTYPE_LAJ)
	{
		pd.jumpFrame = pd.tickCount;
		pd.jumpPos = pd.position;
		pd.jumpAngles = pd.angles;
		
		DEBUG_CHAT(client, "jumppos z: %f", pd.jumpPos[2])
		
		pd.jumpPrespeed = GCGetVectorLength2D(pd.velocity);
		
		pd.jumpGroundZ = pd.jumpPos[2];
		float ground[3];
		if (GCTraceGround(client, pd.jumpPos, ground))
		{
			pd.jumpGroundZ = ground[2];
		}
		else
		{
			DEBUG_CHATALL("AAAAAAAAAAAAA")
		}
	}
	else
	{
		// NOTE: for ladderjump set prespeed and stamina to values that don't get shown
		pd.prespeedFog = -1;
		pd.prespeedStamina = 0.0;
		pd.jumpFrame = pd.tickCount - 1;
		pd.jumpPos = pd.lastPosition;
		pd.jumpAngles = pd.lastAngles;
		
		pd.jumpPrespeed = GCGetVectorLength2D(pd.lastVelocity);
		
		// find ladder top
		
		float traceOrigin[3];
		// 10 units is the furthest away from the ladder surface you can get while still being on the ladder
		traceOrigin[0] = pd.jumpPos[0] - 10.0 * pd.ladderNormal[0];
		traceOrigin[1] = pd.jumpPos[1] - 10.0 * pd.ladderNormal[1];
		traceOrigin[2] = pd.jumpPos[2] + 400.0 * GetTickInterval(); // ~400 ups is the fastest vertical speed on ladders
		
		float traceEnd[3];
		traceEnd = traceOrigin;
		traceEnd[2] = pd.jumpPos[2] - 400.0 * GetTickInterval();
		
		float mins[3];
		GetClientMins(client, mins);
		
		float maxs[3];
		GetClientMaxs(client, maxs);
		
		TR_TraceHullFilter(traceOrigin, traceEnd, mins, maxs, CONTENTS_LADDER, GCTraceEntityFilterPlayer);
		
		pd.jumpGroundZ = pd.jumpPos[2];
		if (TR_DidHit())
		{
			float result[3];
			TR_GetEndPosition(result);
			pd.jumpGroundZ = result[2];
		}
	}
}

void OnPlayerLanded(int client, PlayerData pd, PlayerData failstatPD)
{
	pd.landedDucked = !!(pd.flags & FL_DUCKING);
	
	if (!pd.trackingJump
		|| pd.jumpType == JUMPTYPE_NONE
		|| !g_jumpTypePrintable[pd.jumpType])
	{
		ResetJump(pd);
		return;
	}
	
	if (pd.jumpType != JUMPTYPE_LAJ)
	{
		float roughOffset = pd.position[2] - pd.jumpPos[2];
		if (0.0 < roughOffset > 2.0)
		{
			ResetJump(pd);
			return;
		}
	}
	
	{
		float landGround[3];
		GCTraceGround(client, pd.position, landGround);
		pd.landGroundZ = landGround[2];
	}
	
	float offsetTolerance = 0.0001;
	if (!GCIsRoughlyEqual(pd.jumpGroundZ, pd.landGroundZ, offsetTolerance) && pd.jumpGotFailstats)
	{
		OnPlayerFailstat(client, failstatPD);
		return;
	}
	
	float landOrigin[3];
	float gravity = g_gravity.FloatValue * pd.gravity;
	float frametime = GetTickInterval();
	float fixedVelocity[3];
	float airOrigin[3];
	
	// fix incorrect landing position
	float lastPosition[3];
	lastPosition = pd.lastPosition;
	bool lastDucking = !!(pd.lastFlags & FL_DUCKING);
	bool ducking = !!(pd.flags & FL_DUCKING);
	if (!lastDucking && ducking)
	{
		lastPosition[2] += 9.0;
	}
	else if (lastDucking && !ducking)
	{
		lastPosition[2] -= 9.0;
	}
	
	bool isBugged = pd.lastPosition[2] - pd.landGroundZ < 2.0;
	if (isBugged)
	{
		fixedVelocity = pd.velocity;
		// NOTE: The 0.5 here removes half the gravity in a tick, because
		// in pmove code half the gravity is applied before movement calculation and the other half after it's finished.
		// We're trying to fix a bug that happens in the middle of movement code.
		fixedVelocity[2] = pd.lastVelocity[2] - gravity * 0.5 * frametime;
		airOrigin = lastPosition;
	}
	else
	{
		// NOTE: calculate current frame's z velocity
		float tempVel[3];
		tempVel = pd.velocity;
		tempVel[2] = pd.lastVelocity[2] - gravity * 0.5 * frametime;
		// NOTE: calculate velocity after the current frame.
		fixedVelocity = tempVel;
		fixedVelocity[2] -= gravity * frametime;
		
		airOrigin = pd.position;
	}
	
	GetRealLandingOrigin(pd.landGroundZ, airOrigin, fixedVelocity, landOrigin);
	pd.landPos = landOrigin;
	
	pd.jumpDistance = (GCGetVectorDistance2D(pd.jumpPos, pd.landPos));
	if (pd.jumpType != JUMPTYPE_LAJ)
	{
		pd.jumpDistance += 32.0;
	}
	
	if (GCIsFloatInRange(pd.jumpDistance,
		g_jumpRange[pd.jumpType][0].FloatValue,
		g_jumpRange[pd.jumpType][1].FloatValue))
	{
		FinishTrackingJump(client, pd);
		
		PrintStats(client, pd);
	}
	else
	{
		DEBUG_CHAT(client, "bad jump distance %f", pd.jumpDistance)
	}
	ResetJump(pd);
}

void FinishTrackingJump(int client, PlayerData pd)
{
	// finish up stats:
	float xAxisVeer = FloatAbs(pd.landPos[0] - pd.jumpPos[0]);
	float yAxisVeer = FloatAbs(pd.landPos[1] - pd.jumpPos[1]);
	pd.jumpVeer = GCFloatMin(xAxisVeer, yAxisVeer);
	
	pd.jumpFwdRelease = pd.fwdReleaseFrame - pd.jumpFrame;
	pd.jumpSync = (pd.jumpSync / float(pd.jumpAirtime) * 100.0);
	
	for (int strafe; strafe < pd.strafeCount + 1; strafe++)
	{
		// average gain
		pd.strafeAvgGain[strafe] = (pd.strafeGain[strafe] / pd.strafeAirtime[strafe]);
		
		// efficiency!
		if (pd.strafeAvgEfficiencyCount[strafe])
		{
			pd.strafeAvgEfficiency[strafe] /= float(pd.strafeAvgEfficiencyCount[strafe]);
		}
		else
		{
			pd.strafeAvgEfficiency[strafe] = GC_FLOAT_NAN;
		}
		
		// sync
		
		if (pd.strafeAirtime[strafe] != 0.0)
		{
			pd.strafeSync[strafe] = (pd.strafeSync[strafe] / float(pd.strafeAirtime[strafe]) * 100.0);
		}
		else
		{
			pd.strafeSync[strafe] = 0.0;
		}
	}
	
	// airpath!
	{
		float delta[3];
		SubtractVectors(pd.landPos, pd.lastPosition, delta);
		pd.jumpAirpath += GCGetVectorLength2D(delta);
		if (pd.jumpType != JUMPTYPE_LAJ)
		{
			pd.jumpAirpath = (pd.jumpAirpath / (pd.jumpDistance - 32.0));
		}
		else
		{
			pd.jumpAirpath = (pd.jumpAirpath / (pd.jumpDistance));
		}
	}
	
	pd.jumpBlockDist = -1.0;
	pd.jumpLandEdge = -9999.9;
	pd.jumpEdge = -1.0;
	// Calculate block distance and jumpoff edge
	if (pd.jumpType != JUMPTYPE_LAJ)
	{
		int blockAxis = FloatAbs(pd.landPos[1] - pd.jumpPos[1]) > FloatAbs(pd.landPos[0] - pd.jumpPos[0]);
		int blockDir = FloatSign(pd.jumpPos[blockAxis] - pd.landPos[blockAxis]);
		
		float jumpOrigin[3];
		float landOrigin[3];
		jumpOrigin = pd.jumpPos;
		landOrigin = pd.landPos;
		// move origins 2 units down, so we can touch the side of the lj blocks
		jumpOrigin[2] -= 2.0;
		landOrigin[2] -= 2.0;
		
		// extend land origin, so if we fail within 16 units of the block we can still get the block distance.
		landOrigin[blockAxis] -= float(blockDir) * 16.0;
		
		float tempPos[3];
		tempPos = landOrigin;
		tempPos[blockAxis] += (jumpOrigin[blockAxis] - landOrigin[blockAxis]) / 2.0;
		
		float jumpEdge[3];
		GCTraceBlock(tempPos, jumpOrigin, jumpEdge);
		
		tempPos = jumpOrigin;
		tempPos[blockAxis] += (landOrigin[blockAxis] - jumpOrigin[blockAxis]) / 2.0;
		
		bool block;
		float landEdge[3];
		block = GCTraceBlock(tempPos, landOrigin, landEdge);
		
		if (block)
		{
			pd.jumpBlockDist = (FloatAbs(landEdge[blockAxis] - jumpEdge[blockAxis]) + 32.0);
			pd.jumpLandEdge = ((landEdge[blockAxis] - pd.landPos[blockAxis]) * float(blockDir));
		}
		
		if (jumpEdge[blockAxis] - tempPos[blockAxis] != 0.0)
		{
			pd.jumpEdge = FloatAbs(jumpOrigin[blockAxis] - jumpEdge[blockAxis]);
		}
	}
	else
	{
		int blockAxis = FloatAbs(pd.landPos[1] - pd.jumpPos[1]) > FloatAbs(pd.landPos[0] - pd.jumpPos[0]);
		int blockDir = FloatSign(pd.jumpPos[blockAxis] - pd.landPos[blockAxis]);
		
		// find ladder front
		
		float traceOrigin[3];
		// 10 units is the furthest away from the ladder surface you can get while still being on the ladder
		traceOrigin[0] = pd.jumpPos[0];
		traceOrigin[1] = pd.jumpPos[1];
		traceOrigin[2] = pd.jumpPos[2] - 400.0 * GetTickInterval(); // ~400 ups is the fastest vertical speed on ladders
		
		// leave enough room to trace the front of the ladder
		traceOrigin[blockAxis] += blockDir * 40.0;
		
		float traceEnd[3];
		traceEnd = traceOrigin;
		traceEnd[blockAxis] -= blockDir * 50.0;
		
		float mins[3];
		GetClientMins(client, mins);
		
		float maxs[3];
		GetClientMaxs(client, maxs);
		maxs[2] = mins[2];
		
		TR_TraceHullFilter(traceOrigin, traceEnd, mins, maxs, CONTENTS_LADDER, GCTraceEntityFilterPlayer);
		
		float jumpEdge[3];
		if (TR_DidHit())
		{
			TR_GetEndPosition(jumpEdge);
			DEBUG_CHAT(1, "ladder front: %f %f %f", jumpEdge[0], jumpEdge[1], jumpEdge[2])
			
			float jumpOrigin[3];
			float landOrigin[3];
			jumpOrigin = pd.jumpPos;
			landOrigin = pd.landPos;
			// move origins 2 units down, so we can touch the side of the lj blocks
			jumpOrigin[2] -= 2.0;
			landOrigin[2] -= 2.0;
			
			// extend land origin, so if we fail within 16 units of the block we can still get the block distance.
			landOrigin[blockAxis] -= float(blockDir) * 16.0;
			
			float tempPos[3];
			tempPos = jumpOrigin;
			tempPos[blockAxis] += (landOrigin[blockAxis] - jumpOrigin[blockAxis]) / 2.0;
			
			float landEdge[3];
			bool land = GCTraceBlock(tempPos, landOrigin, landEdge);
			DEBUG_CHAT(1, "tracing from %f %f %f to %f %f %f", tempPos[0], tempPos[1], tempPos[2], landOrigin[0], landOrigin[1], landOrigin[2])
			
			if (land)
			{
				pd.jumpBlockDist = (FloatAbs(landEdge[blockAxis] - jumpEdge[blockAxis]));
				pd.jumpLandEdge = ((landEdge[blockAxis] - pd.landPos[blockAxis]) * float(blockDir));
			}
			
			pd.jumpEdge = FloatAbs(jumpOrigin[blockAxis] - jumpEdge[blockAxis]);
		}
	}
	
	// jumpoff angle!
	{
		float airpathDir[3];
		SubtractVectors(pd.landPos, pd.jumpPos, airpathDir);
		NormalizeVector(airpathDir, airpathDir);
		
		float airpathAngles[3];
		GetVectorAngles(airpathDir, airpathAngles);
		float airpathYaw = GCNormaliseYaw(airpathAngles[1]);
		
		pd.jumpJumpoffAngle = GCNormaliseYaw(airpathYaw - pd.jumpAngles[1]);
	}
}

void PrintStats(int client, PlayerData pd)
{
	// beams!
	if (IsSettingEnabled(client, SETTINGS_SHOW_VEER_BEAM))
	{
		float beamEnd[3];
		beamEnd[0] = pd.landPos[0];
		beamEnd[1] = pd.jumpPos[1];
		beamEnd[2] = pd.landPos[2];
		float jumpPos[3];
		float landPos[3];
		for (int i = 0; i < 3; i++)
		{
			jumpPos[i] = pd.jumpPos[i];
			landPos[i] = pd.landPos[i];
		}
		
		GCTE_SetupBeamPoints(.start = jumpPos, .end = landPos, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = {255, 255, 255, 95});
		TE_SendToClient(client);
		
		// x axis
		GCTE_SetupBeamPoints(.start = jumpPos, .end = beamEnd, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = {255, 0, 255, 95});
		TE_SendToClient(client);
		// y axis
		GCTE_SetupBeamPoints(.start = landPos, .end = beamEnd, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = {0, 255, 0, 95});
		TE_SendToClient(client);
	}
	
	if (IsSettingEnabled(client, SETTINGS_SHOW_JUMP_BEAM))
	{
		float beamPos[3];
		float lastBeamPos[3];
		beamPos[0] = pd.jumpPos[0];
		beamPos[1] = pd.jumpPos[1];
		beamPos[2] = pd.jumpPos[2];
		for (int i = 1; i < pd.jumpAirtime && i < MAX_JUMP_FRAMES; i++)
		{
			lastBeamPos = beamPos;
			beamPos[0] = pd.jumpBeamX[i];
			beamPos[1] = pd.jumpBeamY[i];
			
			int colour[4] = {255, 191, 0, 255};
			if (pd.jumpBeamColour[i] == JUMPBEAM_LOSS)
			{
				colour = {255, 0, 255, 255};
			}
			else if (pd.jumpBeamColour[i] == JUMPBEAM_GAIN)
			{
				colour = {0, 127, 0, 255};
			}
			else if (pd.jumpBeamColour[i] == JUMPBEAM_DUCK)
			{
				colour = {0, 31, 127, 255};
			}
			
			GCTE_SetupBeamPoints(.start = lastBeamPos, .end = beamPos, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = colour);
			TE_SendToClient(client);
		}
	}
	
	char fwdRelease[32] = "";
	if (pd.jumpFwdRelease == 0)
	{
		FormatEx(fwdRelease, sizeof(fwdRelease), "Fwd: {gr}0");
	}
	else if (GCIntAbs(pd.jumpFwdRelease) > 16)
	{
		FormatEx(fwdRelease, sizeof(fwdRelease), "Fwd: {dr}No");
	}
	else if (pd.jumpFwdRelease > 0)
	{
		FormatEx(fwdRelease, sizeof(fwdRelease), "Fwd: {dr}+%i", pd.jumpFwdRelease);
	}
	else
	{
		FormatEx(fwdRelease, sizeof(fwdRelease), "Fwd: {sb}%i", pd.jumpFwdRelease);
	}
	
	char edge[32] = "";
	char chatEdge[32] = "";
	bool hasEdge = false;
	if (pd.jumpEdge >= 0.0 && pd.jumpEdge < MAX_EDGE)
	{
		FormatEx(edge, sizeof(edge), "Edge: %.4f", pd.jumpEdge);
		FormatEx(chatEdge, sizeof(chatEdge), "Edge: {l}%.2f{g}", pd.jumpEdge);
		hasEdge = true;
	}
	
	char block[32] = "";
	char chatBlock[32] = "";
	bool hasBlock = false;
	if (GCIsFloatInRange(pd.jumpBlockDist,
		g_jumpRange[pd.jumpType][0].FloatValue,
		g_jumpRange[pd.jumpType][1].FloatValue))
	{
		FormatEx(block, sizeof(block), "Block: %i", RoundFloat(pd.jumpBlockDist));
		FormatEx(chatBlock, sizeof(chatBlock), "({l}%i{g})", RoundFloat(pd.jumpBlockDist));
		hasBlock = true;
	}
	
	char landEdge[32] = "";
	bool hasLandEdge = false;
	if (FloatAbs(pd.jumpLandEdge) < MAX_EDGE)
	{
		FormatEx(landEdge, sizeof(landEdge), "Land Edge: %.4f", pd.jumpLandEdge);
		hasLandEdge = true;
	}
	
	char fog[32];
	bool hasFOG = false;
	if (pd.prespeedFog <= MAX_BHOP_FRAMES && pd.prespeedFog >= 0)
	{
		FormatEx(fog, sizeof(fog), "FOG: %i", pd.prespeedFog);
		hasFOG = true;
	}
	
	char stamina[32];
	bool hasStamina = false;
	if (pd.prespeedStamina != 0.0)
	{
		FormatEx(stamina, sizeof(stamina), "Stamina: %.1f", pd.prespeedStamina);
		hasStamina = true;
	}
	
	char offset[32];
	bool hasOffset = false;
	if (pd.jumpGroundZ != pd.jumpPos[2])
	{
		FormatEx(offset, sizeof(offset), "Ground offset: %.4f", pd.jumpPos[2] - pd.jumpGroundZ);
		hasOffset = true;
	}
	
	char chatStats[1024];
	if (!IsSettingEnabled(client, SETTINGS_ADV_CHAT_STATS))
	{
		FormatEx(chatStats, sizeof(chatStats), CHAT_PREFIX..." {g}%s%s: {l}%.3f {d}[{g}%s%sVeer: {l}%.1f"...CHAT_SPACER...\
													"%s"...CHAT_SPACER..."Sync: {l}%.0f"...CHAT_SPACER..."Max: {l}%.0f{d}]",
			pd.failedJump ? "F " : "",
			g_jumpTypes[pd.jumpType],
			pd.jumpDistance,
			
			chatEdge,
			hasEdge ? CHAT_SPACER : "",
			pd.jumpVeer,
			fwdRelease,
			pd.jumpSync,
			pd.jumpMaxspeed
		);
	}
	else
	{
		FormatEx(chatStats, sizeof(chatStats), CHAT_PREFIX..." {g}%s%s: {l}%.4f {d}[{g}%s%s%s%sPre: {l}%.2f"...CHAT_SPACER..."Airpath: {l}%.3f"...CHAT_SPACER...\
												"Max: {l}%.1f"...CHAT_SPACER..."Veer: {l}%.1f"...CHAT_SPACER..."Sync: {l}%.0f"...CHAT_SPACER...\
												"%s{l}%i"...CHAT_SPACER..."%s"...CHAT_SPACER..."OL/DA: {l}%i{g}/{l}%i{d}]",
			pd.failedJump ? "F " : "",
			g_jumpTypes[pd.jumpType],
			pd.jumpDistance,
			
			chatEdge,
			hasBlock ? " " : "",
			chatBlock,
			hasEdge ? CHAT_SPACER : "",
			pd.jumpPrespeed,
			pd.jumpAirpath,
			pd.jumpMaxspeed,
			pd.jumpVeer,
			pd.jumpSync,
			pd.jumpType != JUMPTYPE_LAJ ? "Jump Ang: " : "Air: ",
			pd.jumpType != JUMPTYPE_LAJ ? RoundFloat(pd.jumpJumpoffAngle) : pd.jumpAirtime,
			fwdRelease,
			pd.jumpOverlap,
			pd.jumpDeadair
		);
	}
	
	ClientAndSpecsPrintChat(client, "%s", chatStats);
	
	// TODO: remove jump direction from ladderjumps
	char consoleStats[1024];
	FormatEx(consoleStats, sizeof(consoleStats), "\n"...CONSOLE_PREFIX..." %s%s: %.5f [%s%s%s%sVeer: %.4f | %s | Sync: %.2f | Max: %.3f]\n"...\
												   "[%s%sPre: %.4f | OL/DA: %i/%i | Jumpoff Angle: %.3f | Airpath: %.4f]\n"...\
												   "[Strafes: %i | Airtime: %i | Jump Direction: %s | %s%sHeight: %.4f%s%s%s%s]",
		pd.failedJump ? "FAILED " : "",
		g_jumpTypes[pd.jumpType],
		pd.jumpDistance,
		block,
		hasBlock ? " | " : "",
		edge,
		hasEdge ? " | " : "",
		pd.jumpVeer,
		fwdRelease,
		pd.jumpSync,
		pd.jumpMaxspeed,
		
		landEdge,
		hasLandEdge ? " | " : "",
		pd.jumpPrespeed,
		pd.jumpOverlap,
		pd.jumpDeadair,
		pd.jumpJumpoffAngle,
		pd.jumpAirpath,
		
		pd.strafeCount + 1,
		pd.jumpAirtime,
		g_jumpDirString[pd.jumpDir],
		fog,
		hasFOG ? " | " : "",
		pd.jumpHeight,
		hasOffset ? " | " : "",
		offset,
		hasStamina ? " | " : "",
		stamina
	);
	
	CRemoveTags(consoleStats, sizeof(consoleStats));
	ClientAndSpecsPrintConsole(client, consoleStats);
	
	if (!IsSettingEnabled(client, SETTINGS_DISABLE_STRAFE_STATS))
	{
		ClientAndSpecsPrintConsole(client, " #.  Sync    Gain   Loss   Max  Air  OL  DA  AvgGain  Avg efficiency, (max efficiency)");
		for (int strafe; strafe <= pd.strafeCount && strafe < MAX_STRAFES; strafe++)
		{
			ClientAndSpecsPrintConsole(client, "%2i. %5.1f%% %6.2f %6.2f  %5.1f %3i %3i %3i  %3.2f     %3i%% (%3i%%)",
				strafe + 1,
				pd.strafeSync[strafe],
				pd.strafeGain[strafe],
				pd.strafeLoss[strafe],
				pd.strafeMax[strafe],
				pd.strafeAirtime[strafe],
				pd.strafeOverlap[strafe],
				pd.strafeDeadair[strafe],
				pd.strafeAvgGain[strafe],
				RoundFloat(pd.strafeAvgEfficiency[strafe]),
				RoundFloat(pd.strafeMaxEfficiency[strafe])
			);
		}
	}
	
	// hud text
	char strafeLeft[512] = "";
	int slIndex;
	char strafeRight[512] = "";
	int srIndex;
	char mouseLeft[512] = "";
	int mlIndex;
	char mouseRight[512] = "";
	int mrIndex;
	
	char hudStrafeLeft[4096] = "";
	int hslIndex;
	char hudStrafeRight[4096] = "";
	int hsrIndex;
	char hudMouse[4096] = "";
	int hmIndex;
	
	char mouseColours[][] = {
		"<font color='#FFBF00'>|",
		"<font color='#000000'>|",
		"<font color='#003FFF'>|"
	};
	
	// nonsensical default values, so that the first comparison check fails
	StrafeType lastStrafeTypeLeft = STRAFETYPE_NONE_RIGHT + STRAFETYPE_NONE_RIGHT;
	StrafeType lastStrafeTypeRight = STRAFETYPE_NONE_RIGHT + STRAFETYPE_NONE_RIGHT;
	int lastMouseIndex = 9999;
	for (int i = 0; i < pd.jumpAirtime && i < MAX_JUMP_FRAMES; i++)
	{
		StrafeType strafeTypeLeft = pd.strafeGraph[i];
		StrafeType strafeTypeRight = pd.strafeGraph[i];
		
		if (strafeTypeLeft == STRAFETYPE_RIGHT
			|| strafeTypeLeft == STRAFETYPE_NONE_RIGHT
			|| strafeTypeLeft == STRAFETYPE_OVERLAP_RIGHT)
		{
			strafeTypeLeft = STRAFETYPE_NONE;
		}
		
		if (strafeTypeRight == STRAFETYPE_LEFT
			|| strafeTypeRight == STRAFETYPE_NONE_LEFT
			|| strafeTypeRight == STRAFETYPE_OVERLAP_LEFT)
		{
			strafeTypeRight = STRAFETYPE_NONE;
		}
		
		slIndex += strcopy(strafeLeft[slIndex], sizeof(strafeLeft) - slIndex, g_szStrafeType[strafeTypeLeft]);
		srIndex += strcopy(strafeRight[srIndex], sizeof(strafeRight) - srIndex, g_szStrafeType[strafeTypeRight]);
		
		char mouseChar[] = "█";
		if (pd.mouseGraph[i] == 0.0)
		{
			mouseLeft[mlIndex++] = '.';
			mouseRight[mrIndex++] = '.';
		}
		else if (pd.mouseGraph[i] < 0.0)
		{
			mouseLeft[mlIndex++] = '.';
			mrIndex += strcopy(mouseRight[mrIndex], sizeof(mouseRight) - mrIndex, mouseChar);
		}
		else if (pd.mouseGraph[i] > 0.0)
		{
			mlIndex += strcopy(mouseLeft[mlIndex], sizeof(mouseLeft) - mlIndex, mouseChar);
			mouseRight[mrIndex++] = '.';
		}
		
		if (i == 0)
		{
			hslIndex += strcopy(hudStrafeLeft, sizeof(hudStrafeLeft), "<font color='#FFFFFF'>L: ");
			hsrIndex += strcopy(hudStrafeRight, sizeof(hudStrafeRight), "<font color='#FFFFFF'>R: ");
			hmIndex += strcopy(hudMouse, sizeof(hudMouse), "<font color='#FFFFFF'>M: ");
		}
		
		if (lastStrafeTypeLeft != strafeTypeLeft)
		{
			hslIndex += strcopy(hudStrafeLeft[hslIndex], sizeof(hudStrafeLeft) - hslIndex, g_szStrafeTypeColour[strafeTypeLeft]);
		}
		else
		{
			hudStrafeLeft[hslIndex++] = '|';
		}
		
		if (lastStrafeTypeRight != strafeTypeRight)
		{
			hsrIndex += strcopy(hudStrafeRight[hsrIndex], sizeof(hudStrafeRight) - hsrIndex, g_szStrafeTypeColour[strafeTypeRight]);
		}
		else
		{
			hudStrafeRight[hsrIndex++] = '|';
		}
		
		int mouseIndex = FloatSign(pd.mouseGraph[i]) + 1;
		if (mouseIndex != lastMouseIndex)
		{
			hmIndex += strcopy(hudMouse[hmIndex], sizeof(hudMouse) - hmIndex, mouseColours[mouseIndex]);
		}
		else
		{
			hudMouse[hmIndex++] = '|';
		}
		
		lastStrafeTypeLeft = strafeTypeLeft;
		lastStrafeTypeRight = strafeTypeRight;
		lastMouseIndex = mouseIndex;
	}
	
	mouseLeft[mlIndex] = '\0';
	mouseRight[mrIndex] = '\0';
	hudStrafeLeft[hslIndex] = '\0';
	hudStrafeRight[hsrIndex] = '\0';
	hudMouse[hmIndex] = '\0';
	
	bool showHudGraph = IsSettingEnabled(client, SETTINGS_SHOW_HUD_GRAPH);
	if (showHudGraph)
	{
		// worst case scenario is roughly 11000 characters :D
		char strafeGraph[11000];
		FormatEx(strafeGraph, sizeof(strafeGraph), "<u><span class='fontSize-s'>%s<br>%s<br>%s", hudStrafeLeft, hudStrafeRight, hudMouse);
		
		// TODO: sometimes just after a previous panel has faded out a new panel can't be shown, fix!
		ShowPanel(client, 3, strafeGraph);
	}
	if (!IsSettingEnabled(client, SETTINGS_DISABLE_STRAFE_GRAPH))
	{
		ClientAndSpecsPrintConsole(client, "\nStrafe keys:\nL: %s\nR: %s", strafeLeft, strafeRight);
		ClientAndSpecsPrintConsole(client, "Mouse movement:\nL: %s\nR: %s\n\n", mouseLeft, mouseRight);
	}
}
