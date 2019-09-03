

public void OnPluginStart_Clientprefs()
{
	g_hDistbugCookie = RegClientCookie("distbugfix_cookie", "cookie for distbugfix", CookieAccess_Private);
}

public void OnClientCookiesCached_Clientprefs(int client)
{
	char szBuffer[MAX_COOKIE_SIZE];
	GetClientCookie(client, g_hDistbugCookie, szBuffer, sizeof(szBuffer));
	
	g_iSettings[client] = StringToInt(szBuffer);
}

void SaveClientCookie(int client, int settings)
{
	if (IsFakeClient(client) || !AreClientCookiesCached(client))
	{
		return;
	}
	
	char szBuffer[MAX_COOKIE_SIZE];
	FormatEx(szBuffer, sizeof(szBuffer), "%i", settings);
	SetClientCookie(client, g_hDistbugCookie, szBuffer);
}