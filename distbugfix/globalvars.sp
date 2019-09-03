// ======
// GLOBAL
// ======

// cvars
Handle g_hMinJumpDistance = INVALID_HANDLE;
Handle g_hMaxJumpDistance = INVALID_HANDLE;
float g_fMinJumpDistance;
float g_fMaxJumpDistance;

bool g_bLateLoad;
float g_fTickRate;

float g_fJumpPosition[MAXPLAYERS + 1][3];
float g_fPosition[MAXPLAYERS + 1][3];
float g_fVelocity[MAXPLAYERS + 1][3];

float g_fFailPos[MAXPLAYERS + 1][3];
float g_fFailVelocity[MAXPLAYERS + 1][3];

float g_fJEdge[MAXPLAYERS + 1];

float g_fLastVelInAir[MAXPLAYERS + 1][3];

float g_fLastVelocity[MAXPLAYERS + 1][3];
float g_fLastVelocityInAir[MAXPLAYERS + 1][3];
float g_fLastPosInAir[MAXPLAYERS + 1][3];
float g_fLastLastPosInAir[MAXPLAYERS + 1][3];

int g_iFramesInAir[MAXPLAYERS + 1];
int g_iFramesOnGround[MAXPLAYERS + 1];
int g_iFramesOverlapped[MAXPLAYERS + 1];

int g_iDeadAirtime[MAXPLAYERS + 1];
int g_iWReleaseFrame[MAXPLAYERS + 1];
int g_iJumpFrame[MAXPLAYERS + 1];

int g_iFailAirTime[MAXPLAYERS + 1];
int g_iFailDeadAirTime[MAXPLAYERS + 1];
int g_iFailOverlap[MAXPLAYERS + 1];

int g_iLastButtons[MAXPLAYERS + 1];

bool g_bValidJump[MAXPLAYERS + 1];
bool g_bInAir[MAXPLAYERS + 1];
bool g_bBlock[MAXPLAYERS + 1];

// ===========
// STRAFESTATS
// ===========

float g_fStatStrafeGain[MAXPLAYERS + 1][MAXSTRAFES];
float g_fStatStrafeLoss[MAXPLAYERS + 1][MAXSTRAFES];
float g_fStatStrafeMax[MAXPLAYERS + 1][MAXSTRAFES];
float g_fStatStrafeSync[MAXPLAYERS + 1][MAXSTRAFES];
float g_fStatStrafeAirtime[MAXPLAYERS + 1][MAXSTRAFES];
int g_iStatStrafeOverlap[MAXPLAYERS + 1][MAXSTRAFES];
int g_iStatStrafeDead[MAXPLAYERS + 1][MAXSTRAFES];
int g_iStatStrafeCount[MAXPLAYERS + 1];
int g_iStatSync[MAXPLAYERS + 1];

float g_fMaxHeight[MAXPLAYERS + 1];
float g_fAirDistance[MAXPLAYERS + 1];
float g_fFailAirDistance[MAXPLAYERS + 1];

float g_fFailStatStrafeGain[MAXPLAYERS + 1][MAXSTRAFES];
float g_fFailStatStrafeLoss[MAXPLAYERS + 1][MAXSTRAFES];
float g_fFailStatStrafeMax[MAXPLAYERS + 1][MAXSTRAFES];
float g_fFailStatStrafeSync[MAXPLAYERS + 1][MAXSTRAFES]
float g_fFailStatStrafeAirtime[MAXPLAYERS + 1][MAXSTRAFES];
int g_iFailStatStrafeOverlap[MAXPLAYERS + 1][MAXSTRAFES];
int g_iFailStatStrafeDead[MAXPLAYERS + 1][MAXSTRAFES];
int g_iFailStatStrafeCount[MAXPLAYERS + 1];
int g_iFailStatSync[MAXPLAYERS + 1];

// ===========
// CLIENTPREFS
// ===========

Handle g_hDistbugCookie;
int g_iSettings[MAXPLAYERS + 1];