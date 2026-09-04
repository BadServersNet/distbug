

static Handle distbugCookie;
static int settings[MAXPLAYERS + 1];

void OnPluginStart_Clientprefs()
{
	distbugCookie = RegClientCookie("distbugfix_cookie_v2", "cookie for distbugfix", CookieAccess_Private);
	if (distbugCookie == INVALID_HANDLE)
	{
		SetFailState("Couldn't create distbug cookie.");
	}
}

void OnClientCookiesCached_Clientprefs(int client)
{
	char buffer[MAX_COOKIE_SIZE];
	GetClientCookie(client, distbugCookie, buffer, sizeof(buffer));
	
	settings[client] = StringToInt(buffer);
}

void SaveClientCookies(int client)
{
	if (!GCIsValidClient(client) || !AreClientCookiesCached(client))
	{
		return;
	}
	
	char buffer[MAX_COOKIE_SIZE];
	IntToString(settings[client], buffer, sizeof(buffer));
	SetClientCookie(client, distbugCookie, buffer);
}

bool IsSettingEnabled(int client, int setting)
{
	if (GCIsValidClient(client))
	{
		return !!(settings[client] & setting);
	}
	return false;
}

void ToggleSetting(int client, int setting)
{
	if (GCIsValidClient(client))
	{
		settings[client] ^= setting;
		SaveClientCookies(client);
	}
}