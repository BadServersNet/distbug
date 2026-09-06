
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

enum struct JumpStatLabels
{
	char fwdRelease[32];
	char edge[32];
	char chatEdge[32];
	bool hasEdge;
	char block[32];
	char chatBlock[32];
	bool hasBlock;
	char landEdge[32];
	bool hasLandEdge;
	char fog[32];
	bool hasFOG;
	char stamina[32];
	bool hasStamina;
	char offset[32];
	bool hasOffset;
}

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
	
	if (!GCIsValidClient(client, true))
	{
		return;
	}
	JumpType jumpType = GetGroundJumpType(g_pd[client]);
	OnPlayerJumped(client, g_pd[client], jumpType);
	g_pd[client].lastGroundPos = g_pd[client].lastPosition;
	g_pd[client].lastGroundPosWalkedOff = false;
}

JumpType GetGroundJumpType(PlayerData pd)
{
	if (pd.framesOnGround > MAX_BHOP_FRAMES)
	{
		return JUMPTYPE_LJ;
	}
	float groundOffset = pd.position[2] - pd.lastGroundPos[2];
	if (pd.lastGroundPosWalkedOff && groundOffset < 0.0)
	{
		return JUMPTYPE_WJ;
	}
	if (pd.flags & FL_DUCKING)
	{
		return JUMPTYPE_CBH;
	}
	return JUMPTYPE_BH;
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
	
	UpdateJumpTracking(client);
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
	if (pd.jumpAirtime == 1)
	{
		return false;
	}
	if (pd.jumpDir == JUMPDIR_FORWARDS || pd.jumpDir == JUMPDIR_BACKWARDS)
	{
		return HasMovementReversed(pd.sidemove, pd.lastSidemove);
	}
	return HasMovementReversed(pd.forwardmove, pd.lastForwardmove);
}

bool HasMovementReversed(float current, float previous)
{
	bool startedPositive = current > 0.0 && previous <= 0.0;
	bool startedNegative = current < 0.0 && previous >= 0.0;
	return startedPositive || startedNegative;
}

void TrackJump(PlayerData pd, PlayerData failstatPD)
{
#if defined(DEBUG)
	SetHudTextParams(-1.0, 0.2, 0.02, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(1, -1, "FOG: %i\njumpAirtime: %i\ntrackingJump: %i", pd.framesOnGround, pd.jumpAirtime, pd.trackingJump);
#endif

	bool groundedJump = ShouldResetGroundedJump(pd);
	if (groundedJump)
	{
		ResetJump(pd);
	}

	if (pd.jumpType == JUMPTYPE_NONE || !g_jumpTypePrintable[pd.jumpType])
	{
		pd.trackingJump = false;
		return;
	}

	if (pd.movetype != MOVETYPE_WALK && pd.movetype != MOVETYPE_LADDER)
	{
		ResetJump(pd);
	}

	float frametime = GetTickInterval();
	bool teleported = HasJumpTeleported(pd, frametime);
	if (teleported)
	{
		ResetJump(pd);
		return;
	}

	int beamIndex = pd.jumpAirtime;
	RecordJumpBeamPosition(pd, beamIndex);
	pd.jumpAirtime++;

	float speed = GCGetVectorLength2D(pd.velocity);
	float lastSpeed = GCGetVectorLength2D(pd.lastVelocity);
	TrackJumpSpeed(pd, beamIndex, speed, lastSpeed);
	TrackJumpInput(pd);
	TrackStrafe(pd, speed, lastSpeed, frametime);
	TrackJumpGraphs(pd);
	SaveJumpFailstats(pd, failstatPD, frametime);
	TrackJumpAirpath(pd);
}

bool ShouldResetGroundedJump(PlayerData pd)
{
	return pd.framesOnGround > MAX_BHOP_FRAMES && pd.jumpAirtime && pd.trackingJump;
}

bool HasJumpTeleported(PlayerData pd, float frametime)
{
	float posDelta[3];
	SubtractVectors(pd.position, pd.lastPosition, posDelta);
	float moveLength = GetVectorLength(posDelta);
	float maximumDistance = g_maxvelocity.FloatValue * 1.73205081 * frametime;
	return moveLength > maximumDistance;
}

void RecordJumpBeamPosition(PlayerData pd, int beamIndex)
{
	if (beamIndex >= MAX_JUMP_FRAMES)
	{
		return;
	}
	pd.jumpBeamX[beamIndex] = pd.position[0];
	pd.jumpBeamY[beamIndex] = pd.position[1];
	pd.jumpBeamColour[beamIndex] = JUMPBEAM_NEUTRAL;
}

void TrackJumpSpeed(PlayerData pd, int beamIndex, float speed, float lastSpeed)
{
	if (speed > pd.jumpMaxspeed)
	{
		pd.jumpMaxspeed = speed;
	}
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
}

void TrackJumpInput(PlayerData pd)
{
	float height = pd.position[2] - pd.jumpPos[2];
	if (height > pd.jumpHeight)
	{
		pd.jumpHeight = height;
	}
	bool overlapping = IsOverlapping(pd.buttons, pd.jumpDir);
	if (overlapping)
	{
		pd.jumpOverlap++;
	}
	bool deadAirtime = IsDeadAirtime(pd.buttons, pd.jumpDir);
	if (deadAirtime)
	{
		pd.jumpDeadair++;
	}
}

void TrackStrafe(PlayerData pd, float speed, float lastSpeed, float frametime)
{
	if (pd.strafeCount + 1 >= MAX_STRAFES)
	{
		return;
	}
	bool newStrafe = IsNewStrafe(pd);
	if (newStrafe)
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
	bool overlapping = IsOverlapping(pd.buttons, pd.jumpDir);
	if (overlapping)
	{
		pd.strafeOverlap[strafe]++;
	}
	bool deadAirtime = IsDeadAirtime(pd.buttons, pd.jumpDir);
	if (deadAirtime)
	{
		pd.strafeDeadair[strafe]++;
	}
	TrackStrafeEfficiency(pd, strafe, lastSpeed, frametime);
}

float GetStrafeBaseSpeed(PlayerData pd)
{
	if (pd.flags & FL_DUCKING)
	{
		return 250.0 * 0.34;
	}
	if (pd.buttons & IN_SPEED)
	{
		return 250.0 * 0.52;
	}
	return 250.0;
}

float GetStrafeStaminaScale(PlayerData pd)
{
	if (!(pd.lastStamina > 0))
	{
		return 1.0;
	}
	float remainingStamina = 1.0 - pd.lastStamina / 100.0;
	float speedScale = GCFloatClamp(remainingStamina, 0.0, 1.0);
	return speedScale * speedScale;
}

float GetStrafeMaxspeed(PlayerData pd, float frametime)
{
	float baseSpeed = GetStrafeBaseSpeed(pd);
	float staminaScale = GetStrafeStaminaScale(pd);
	float maxspeed = baseSpeed * staminaScale;
	float zvel = pd.lastVelocity[2] + (g_gravity.FloatValue * frametime * 0.5 * pd.gravity);
	if (zvel > 0.0 && zvel <= 140.0)
	{
		return maxspeed * 0.25;
	}
	return maxspeed;
}

float GetPerfectStrafeYaw(float lastSpeed, float yawdiff, float maxspeed, float frametime)
{
	if (!(lastSpeed > 0.0))
	{
		return yawdiff;
	}
	float airaccelerate = g_airaccelerate.FloatValue;
	float acceleration = airaccelerate * maxspeed * frametime;
	float accelspeed = acceleration > 30.0 ? 30.0 : acceleration;
	if (lastSpeed < 30.0)
	{
		return 0.0;
	}
	float ratio = accelspeed / lastSpeed;
	float angle = ArcSine(ratio);
	return RadToDeg(angle);
}

float GetStrafeEfficiency(float yawdiff, float perfectYawDiff)
{
	if (perfectYawDiff == 0.0)
	{
		return 100.0;
	}
	return (yawdiff - perfectYawDiff) / perfectYawDiff * 100.0 + 100.0;
}

void TrackStrafeEfficiency(PlayerData pd, int strafe, float lastSpeed, float frametime)
{
	float maxspeed = GetStrafeMaxspeed(pd, frametime);
	float yawChange = pd.angles[1] - pd.lastAngles[1];
	float normalizedYaw = GCNormaliseYaw(yawChange);
	float yawdiff = FloatAbs(normalizedYaw);
	float perfectYawDiff = GetPerfectStrafeYaw(lastSpeed, yawdiff, maxspeed, frametime);
	float efficiency = GetStrafeEfficiency(yawdiff, perfectYawDiff);
	pd.strafeAvgEfficiency[strafe] += efficiency;
	pd.strafeAvgEfficiencyCount[strafe]++;
	if (efficiency > pd.strafeMaxEfficiency[strafe])
	{
		pd.strafeMaxEfficiency[strafe] = efficiency;
	}
#if defined(DEBUG)
	float speed = GCGetVectorLength2D(pd.velocity);
	float yawError = yawdiff - perfectYawDiff;
	DEBUG_CONSOLE(1, "%i\t%f\t%f\t%f\t%f\t%f", strafe, yawError, pd.sidemove, yawdiff, perfectYawDiff, speed)
#endif
}

StrafeType GetOverlapStrafeType(bool velLeft, bool velRight)
{
	if (velLeft)
	{
		return STRAFETYPE_OVERLAP_LEFT;
	}
	if (velRight)
	{
		return STRAFETYPE_OVERLAP_RIGHT;
	}
	return STRAFETYPE_OVERLAP;
}

StrafeType GetIdleStrafeType(bool velLeft, bool velRight)
{
	if (velLeft)
	{
		return STRAFETYPE_NONE_LEFT;
	}
	if (velRight)
	{
		return STRAFETYPE_NONE_RIGHT;
	}
	return STRAFETYPE_NONE;
}

StrafeType GetGraphStrafeType(PlayerData pd)
{
	bool moveLeft = !!(pd.buttons & g_jumpDirLeftButton[pd.jumpDir]);
	bool moveRight = !!(pd.buttons & g_jumpDirRightButton[pd.jumpDir]);
	bool velLeft = IsWishspeedMovingLeft(pd.forwardmove, pd.sidemove, pd.jumpDir);
	bool velRight = IsWishspeedMovingRight(pd.forwardmove, pd.sidemove, pd.jumpDir);
	if (moveLeft)
	{
		if (moveRight)
		{
			return GetOverlapStrafeType(velLeft, velRight);
		}
		return velLeft ? STRAFETYPE_LEFT : STRAFETYPE_NONE;
	}
	if (moveRight)
	{
		return velRight ? STRAFETYPE_RIGHT : STRAFETYPE_NONE;
	}
	return GetIdleStrafeType(velLeft, velRight);
}

void TrackJumpGraphs(PlayerData pd)
{
	int frame = pd.jumpAirtime - 1;
	if (frame >= MAX_JUMP_FRAMES)
	{
		return;
	}
	StrafeType strafeType = GetGraphStrafeType(pd);
	pd.strafeGraph[frame] = strafeType;
	float yawChange = pd.angles[1] - pd.lastAngles[1];
	float yawDiff = GCNormaliseYaw(yawChange);
	int mouseFrame = pd.jumpAirtime - 2;
	int yawIndex = GCIntMax(mouseFrame, 0);
	pd.mouseGraph[yawIndex] = yawDiff;
}

void SaveJumpFailstats(PlayerData pd, PlayerData failstatPD, float frametime)
{
	float nextHeight = pd.jumpPos[2] + (pd.velocity[2] * frametime);
	if (pd.position[2] < pd.jumpPos[2] && pd.position[2] > nextHeight)
	{
		pd.jumpGotFailstats = true;
		failstatPD = pd;
	}
}

void TrackJumpAirpath(PlayerData pd)
{
	if (pd.framesOnGround)
	{
		return;
	}
	float delta[3];
	SubtractVectors(pd.position, pd.lastPosition, delta);
	float distance = GCGetVectorLength2D(delta);
	pd.jumpAirpath += distance;
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
	
	pd.jumpDir = GetJumpDirection(pd);

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
	
	CorrectLandingPosition(pd);

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
	PrintVeerBeam(client, pd);

	PrintJumpBeam(client, pd);

	JumpStatLabels labels;
	BuildJumpStatLabels(pd, labels);
	PrintChatStats(client, pd, labels);
	PrintConsoleStats(client, pd, labels);
	PrintStrafeStats(client, pd);
	PrintJumpGraphs(client, pd);
}

void BuildJumpStatLabels(PlayerData pd, JumpStatLabels labels)
{
	FormatForwardRelease(pd.jumpFwdRelease, labels.fwdRelease, sizeof(labels.fwdRelease));

	if (pd.jumpEdge >= 0.0 && pd.jumpEdge < MAX_EDGE)
	{
		FormatEx(labels.edge, sizeof(labels.edge), "Edge: %.4f", pd.jumpEdge);
		FormatEx(labels.chatEdge, sizeof(labels.chatEdge), "Edge: {l}%.2f{g}", pd.jumpEdge);
		labels.hasEdge = true;
	}
	
	if (GCIsFloatInRange(pd.jumpBlockDist,
		g_jumpRange[pd.jumpType][0].FloatValue,
		g_jumpRange[pd.jumpType][1].FloatValue))
	{
		FormatEx(labels.block, sizeof(labels.block), "Block: %i", RoundFloat(pd.jumpBlockDist));
		FormatEx(labels.chatBlock, sizeof(labels.chatBlock), "({l}%i{g})", RoundFloat(pd.jumpBlockDist));
		labels.hasBlock = true;
	}
	
	if (FloatAbs(pd.jumpLandEdge) < MAX_EDGE)
	{
		FormatEx(labels.landEdge, sizeof(labels.landEdge), "Land Edge: %.4f", pd.jumpLandEdge);
		labels.hasLandEdge = true;
	}
	
	if (pd.prespeedFog <= MAX_BHOP_FRAMES && pd.prespeedFog >= 0)
	{
		FormatEx(labels.fog, sizeof(labels.fog), "FOG: %i", pd.prespeedFog);
		labels.hasFOG = true;
	}
	
	if (pd.prespeedStamina != 0.0)
	{
		FormatEx(labels.stamina, sizeof(labels.stamina), "Stamina: %.1f", pd.prespeedStamina);
		labels.hasStamina = true;
	}
	
	if (pd.jumpGroundZ != pd.jumpPos[2])
	{
		FormatEx(labels.offset, sizeof(labels.offset), "Ground offset: %.4f", pd.jumpPos[2] - pd.jumpGroundZ);
		labels.hasOffset = true;
	}
	
}

void FormatForwardRelease(int release, char[] output, int length)
{
	if (release == 0)
	{
		FormatEx(output, length, "Fwd: {gr}0");
	}
	else if (GCIntAbs(release) > 16)
	{
		FormatEx(output, length, "Fwd: {dr}No");
	}
	else if (release > 0)
	{
		FormatEx(output, length, "Fwd: {dr}+%i", release);
	}
	else
	{
		FormatEx(output, length, "Fwd: {sb}%i", release);
	}

}

void PrintChatStats(int client, PlayerData pd, JumpStatLabels labels)
{
	char chatStats[1024];
	if (!IsSettingEnabled(client, SETTINGS_ADV_CHAT_STATS))
	{
		FormatEx(chatStats, sizeof(chatStats), CHAT_PREFIX..." {g}%s%s: {l}%.3f {d}[{g}%s%sVeer: {l}%.1f"...CHAT_SPACER...\
													"%s"...CHAT_SPACER..."Sync: {l}%.0f"...CHAT_SPACER..."Max: {l}%.0f{d}]",
			pd.failedJump ? "F " : "",
			g_jumpTypes[pd.jumpType],
			pd.jumpDistance,
			
			labels.chatEdge,
			labels.hasEdge ? CHAT_SPACER : "",
			pd.jumpVeer,
			labels.fwdRelease,
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
			
			labels.chatEdge,
			labels.hasBlock ? " " : "",
			labels.chatBlock,
			labels.hasEdge ? CHAT_SPACER : "",
			pd.jumpPrespeed,
			pd.jumpAirpath,
			pd.jumpMaxspeed,
			pd.jumpVeer,
			pd.jumpSync,
			pd.jumpType != JUMPTYPE_LAJ ? "Jump Ang: " : "Air: ",
			pd.jumpType != JUMPTYPE_LAJ ? RoundFloat(pd.jumpJumpoffAngle) : pd.jumpAirtime,
			labels.fwdRelease,
			pd.jumpOverlap,
			pd.jumpDeadair
		);
	}
	
	ClientAndSpecsPrintChat(client, "%s", chatStats);
	
}

void PrintConsoleStats(int client, PlayerData pd, JumpStatLabels labels)
{
	char consoleStats[1024];
	FormatEx(consoleStats, sizeof(consoleStats), "\n"...CONSOLE_PREFIX..." %s%s: %.5f [%s%s%s%sVeer: %.4f | %s | Sync: %.2f | Max: %.3f]\n"...\
												   "[%s%sPre: %.4f | OL/DA: %i/%i | Jumpoff Angle: %.3f | Airpath: %.4f]\n"...\
												   "[Strafes: %i | Airtime: %i | Jump Direction: %s | %s%sHeight: %.4f%s%s%s%s]",
		pd.failedJump ? "FAILED " : "",
		g_jumpTypes[pd.jumpType],
		pd.jumpDistance,
		labels.block,
		labels.hasBlock ? " | " : "",
		labels.edge,
		labels.hasEdge ? " | " : "",
		pd.jumpVeer,
		labels.fwdRelease,
		pd.jumpSync,
		pd.jumpMaxspeed,
		
		labels.landEdge,
		labels.hasLandEdge ? " | " : "",
		pd.jumpPrespeed,
		pd.jumpOverlap,
		pd.jumpDeadair,
		pd.jumpJumpoffAngle,
		pd.jumpAirpath,
		
		pd.strafeCount + 1,
		pd.jumpAirtime,
		g_jumpDirString[pd.jumpDir],
		labels.fog,
		labels.hasFOG ? " | " : "",
		pd.jumpHeight,
		labels.hasOffset ? " | " : "",
		labels.offset,
		labels.hasStamina ? " | " : "",
		labels.stamina
	);
	
	CRemoveTags(consoleStats, sizeof(consoleStats));
	ClientAndSpecsPrintConsole(client, consoleStats);
	
}

void PrintJumpGraphs(int client, PlayerData pd)
{
	char strafeLeft[512];
	char strafeRight[512];
	char mouseLeft[512];
	char mouseRight[512];
	char hudStrafeLeft[4096];
	char hudStrafeRight[4096];
	char hudMouse[4096];
	BuildStrafeGraph(pd, true, strafeLeft, sizeof(strafeLeft), hudStrafeLeft, sizeof(hudStrafeLeft));
	BuildStrafeGraph(pd, false, strafeRight, sizeof(strafeRight), hudStrafeRight, sizeof(hudStrafeRight));
	BuildMouseGraph(pd, mouseLeft, sizeof(mouseLeft), mouseRight, sizeof(mouseRight), hudMouse, sizeof(hudMouse));

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

void PrintVeerBeam(int client, PlayerData pd)
{
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

		GCTE_SetupBeamPoints(.start = jumpPos, .end = beamEnd, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = {255, 0, 255, 95});
		TE_SendToClient(client);
		GCTE_SetupBeamPoints(.start = landPos, .end = beamEnd, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = {0, 255, 0, 95});
		TE_SendToClient(client);
	}
}

void PrintJumpBeam(int client, PlayerData pd)
{
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

			int colour[4];
			GetJumpBeamColour(pd.jumpBeamColour[i], colour);

			GCTE_SetupBeamPoints(.start = lastBeamPos, .end = beamPos, .modelIndex = g_beamSprite,
							 .life = 5.0, .width = 1.0, .endWidth = 1.0, .colour = colour);
			TE_SendToClient(client);
		}
	}
}

void PrintStrafeStats(int client, PlayerData pd)
{
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
}

StrafeType GetDirectionalStrafeType(StrafeType type, bool left)
{
	if (left)
	{
		if (type == STRAFETYPE_RIGHT || type == STRAFETYPE_NONE_RIGHT || type == STRAFETYPE_OVERLAP_RIGHT)
		{
			return STRAFETYPE_NONE;
		}
		return type;
	}
	if (type == STRAFETYPE_LEFT || type == STRAFETYPE_NONE_LEFT || type == STRAFETYPE_OVERLAP_LEFT)
	{
		return STRAFETYPE_NONE;
	}
	return type;
}

void BuildStrafeGraph(PlayerData pd, bool left, char[] output, int length, char[] hud, int hudLength)
{
	int index;
	int hudIndex;
	StrafeType lastType = STRAFETYPE_NONE_RIGHT + STRAFETYPE_NONE_RIGHT;
	for (int i = 0; i < pd.jumpAirtime && i < MAX_JUMP_FRAMES; i++)
	{
		StrafeType type = GetDirectionalStrafeType(pd.strafeGraph[i], left);
		index += strcopy(output[index], length - index, g_szStrafeType[type]);
		if (i == 0)
		{
			char prefix[32];
			FormatEx(prefix, sizeof(prefix), "<font color='#FFFFFF'>%s: ", left ? "L" : "R");
			hudIndex += strcopy(hud, hudLength, prefix);
		}
		if (lastType != type)
		{
			hudIndex += strcopy(hud[hudIndex], hudLength - hudIndex, g_szStrafeTypeColour[type]);
		}
		else
		{
			hud[hudIndex++] = '|';
		}
		lastType = type;
	}
	hud[hudIndex] = '\0';
}

void AppendMouseGraph(float movement, char[] left, int leftLength, int &leftIndex, char[] right, int rightLength, int &rightIndex)
{
	if (movement == 0.0)
	{
		left[leftIndex++] = '.';
		right[rightIndex++] = '.';
		return;
	}
	if (movement < 0.0)
	{
		left[leftIndex++] = '.';
		rightIndex += strcopy(right[rightIndex], rightLength - rightIndex, "█");
		return;
	}
	if (movement > 0.0)
	{
		leftIndex += strcopy(left[leftIndex], leftLength - leftIndex, "█");
		right[rightIndex++] = '.';
	}
}

void BuildMouseGraph(PlayerData pd, char[] left, int leftLength, char[] right, int rightLength, char[] hud, int hudLength)
{
	char colours[][] = {
		"<font color='#FFBF00'>|",
		"<font color='#000000'>|",
		"<font color='#003FFF'>|"
	};
	int leftIndex;
	int rightIndex;
	int hudIndex;
	int lastMouseIndex = 9999;
	for (int i = 0; i < pd.jumpAirtime && i < MAX_JUMP_FRAMES; i++)
	{
		float movement = pd.mouseGraph[i];
		AppendMouseGraph(movement, left, leftLength, leftIndex, right, rightLength, rightIndex);
		if (i == 0)
		{
			hudIndex += strcopy(hud, hudLength, "<font color='#FFFFFF'>M: ");
		}
		int mouseIndex = FloatSign(movement) + 1;
		if (mouseIndex != lastMouseIndex)
		{
			hudIndex += strcopy(hud[hudIndex], hudLength - hudIndex, colours[mouseIndex]);
		}
		else
		{
			hud[hudIndex++] = '|';
		}
		lastMouseIndex = mouseIndex;
	}
	left[leftIndex] = '\0';
	right[rightIndex] = '\0';
	hud[hudIndex] = '\0';
}

void GetJumpBeamColour(JumpBeamColour type, int colour[4])
{
	if (type == JUMPBEAM_LOSS)
	{
		colour = {255, 0, 255, 255};
		return;
	}
	if (type == JUMPBEAM_GAIN)
	{
		colour = {0, 127, 0, 255};
		return;
	}
	if (type == JUMPBEAM_DUCK)
	{
		colour = {0, 31, 127, 255};
		return;
	}
	colour = {255, 191, 0, 255};
}

void UpdateJumpTracking(int client)
{
	if (!IsSettingEnabled(client, SETTINGS_DISTBUG_ENABLED))
	{
		return;
	}

	UpdateWalkedOffPosition(g_pd[client]);

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

void UpdateWalkedOffPosition(PlayerData pd)
{
	if (pd.framesInAir == 1)
	{
		if (!GCVectorsEqual(pd.lastGroundPos, pd.lastPosition))
		{
			pd.lastGroundPos = pd.lastPosition;
			pd.lastGroundPosWalkedOff = true;
		}
	}

}

JumpDir GetJumpDirection(PlayerData pd)
{
	float speed = GCGetVectorLength2D(pd.velocity);
	if (!(speed > 50.0) || pd.jumpType == JUMPTYPE_LAJ)
	{
		return JUMPDIR_FORWARDS;
	}
	float velocityYaw = RadToDeg(ArcTangent2(pd.velocity[1], pd.velocity[0]));
	float direction = GCNormaliseYaw(pd.angles[1] - velocityYaw);
	if (GCIsFloatInRange(direction, 45.0, 135.0))
	{
		return JUMPDIR_RIGHT;
	}
	if (GCIsFloatInRange(direction, -135.0, -45.0))
	{
		return JUMPDIR_LEFT;
	}
	if (direction > 135.0 || direction < -135.0)
	{
		return JUMPDIR_BACKWARDS;
	}
	return JUMPDIR_FORWARDS;
}

void CorrectLandingPosition(PlayerData pd)
{
	float landOrigin[3];
	float gravity = g_gravity.FloatValue * pd.gravity;
	float frametime = GetTickInterval();
	float fixedVelocity[3];
	float airOrigin[3];

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
		fixedVelocity[2] = pd.lastVelocity[2] - gravity * 0.5 * frametime;
		airOrigin = lastPosition;
	}
	else
	{
		float tempVel[3];
		tempVel = pd.velocity;
		tempVel[2] = pd.lastVelocity[2] - gravity * 0.5 * frametime;
		fixedVelocity = tempVel;
		fixedVelocity[2] -= gravity * frametime;

		airOrigin = pd.position;
	}

	GetRealLandingOrigin(pd.landGroundZ, airOrigin, fixedVelocity, landOrigin);
	pd.landPos = landOrigin;

}
