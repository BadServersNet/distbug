

static Handle hDistbugCookie;
static int settings[MAXPLAYERS + 1];

void OnPluginStart_Clientprefs()
{
	hDistbugCookie = RegClientCookie("distbugfix_cookie", "cookie for distbugfix", CookieAccess_Private);
	
	if (g_bLateLoad)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			OnClientCookiesCached(client);
		}
	}
}

void OnClientCookiesCached_Clientprefs(int client)
{
	char szBuffer[MAX_COOKIE_SIZE];
	GetClientCookie(client, hDistbugCookie, szBuffer, sizeof(szBuffer));
	
	settings[client] = StringToInt(szBuffer);
}

void SaveClientCookie(int client)
{
	if (!IsValidClientExt(client) || !AreClientCookiesCached(client))
	{
		return;
	}
	
	char szBuffer[MAX_COOKIE_SIZE];
	FormatEx(szBuffer, sizeof(szBuffer), "%i", settings[client]);
	SetClientCookie(client, hDistbugCookie, szBuffer);
}

bool IsSettingEnabled(int client, int setting)
{
	return settings[client] & setting != 0;
}

void ToggleSetting(int client, int setting)
{
	settings[client] ^= setting;
	SaveClientCookie(client);
}