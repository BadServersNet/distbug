
#if defined _gamechaos_stocks_client_included
	#endinput
#endif
#define _gamechaos_stocks_client_included

/**
 * Credit: Don't remember.
 * Removes a player's weapon from the specified slot.
 *
 * @param client			Client index.
 * @param slot				Weapon slot.
 * @return 					True if removed, false otherwise.
 */
stock bool RemoveWeaponBySlot(client, slot)
{
	new iEntity = GetPlayerWeaponSlot(client, slot);
	if(IsValidEdict(iEntity))
	{
		RemovePlayerItem(client, iEntity);
		AcceptEntityInput(iEntity, "Kill");
		return true;
	}
	return false;
}

/**
 * Checks if a client is valid and not the server and optionally, whether he's alive.
 *
 * @param client			Client index.
 * @param alive				Whether to check alive.
 * @return 					True if valid, false otherwise.
 */
stock bool IsValidClientExt(int client, bool alive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!alive || IsPlayerAlive(client)));
}



/**
 * Copies the client's forwardmove and sidemove to a vector.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 */
stock void GetClientVel(int client, float result[3])
{
	result[0] = GetEntPropFloat(client, Prop_Data, "m_flForwardMove");
	result[1] = GetEntPropFloat(client, Prop_Data, "m_flSideMove");
}

/**
 * Copies the client's velocity to a vector.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 */
stock void GetClientVelocity(int client, float result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", result);
}

/**
 * Copies the client's basevelocity to a vector.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 */
stock void GetClientBaseVelocity(int client, float result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", result);
}


/**
 * Gets the client's "m_flDuckSpeed" value.
 *
 * @param client			Client index.
 * @return					"m_flDuckSpeed".
 */
stock float GetClientDuckSpeed(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flDuckSpeed");
}

/**
 * Gets the client's "m_flDuckAmount" value.
 *
 * @param client			Client index.
 * @return					"m_flDuckAmount".
 */
stock float GetClientDuckAmount(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flDuckAmount");
}

/**
 * Gets the client's "m_bDucking" value.
 *
 * @param client			Client index.
 * @return					"m_bDucking".
 */
stock int GetClientDucking(int client)
{
	return GetEntProp(client, Prop_Data, "m_bDucking");
}

/**
 * Gets the client's "m_flMaxspeed" value.
 *
 * @param client			Client index.
 * @return					"m_flMaxspeed".
 */
stock float GetClientMaxspeed(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
}

/**
 * Gets the client's "m_afButtonPressed" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonPressed".
 */
stock int GetClientButtonPressed(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonPressed");
}

/**
 * Gets the client's "m_afButtonReleased" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonReleased".
 */
stock int GetClientButtonReleased(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonReleased");
}

/**
 * Gets the client's "m_afButtonLast" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonLast".
 */
stock int GetClientButtonLast(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonLast");
}

/**
 * Gets the client's "m_afButtonForced" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonForced".
 */
stock int GetClientForcedButtons(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonForced");
}

/**
 * Gets the client's "m_flStamina" value.
 *
 * @param client			Client index.
 * @return					"m_flStamina".
 */
stock float GetClientStamina(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flStamina")
}



/**
 * Sets the client's origin.
 *
 * @param client			Client index.
 * @param origin			New origin.
 */
stock void SetClientAbsOrigin(int client, const float origin[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
}

/**
 * Sets the client's velocity.
 *
 * @param client			Client index.
 * @param velocity			New velocity.
 */
stock void SetClientVelocity(int client, const float velocity[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
}

/**
 * Sets the client's "m_vecAbsVelocity".
 *
 * @param client			Client index.
 * @param velocity			New "m_vecAbsVelocity".
 */
stock void SetClientAbsVelocity(int client, const float velocity[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
}

/**
 * Sets the client's eye angles.
 * Ang has to be a 2 member array or more
 *
 * @param client			Client index.
 * @param ang				New eyeangles.
 */
stock void SetClientEyeAngles(int client, const float[] ang)
{
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[0]", ang[0]);
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[1]", ang[1]);
}


/**
 * Sets the client's "m_flDuckSpeed".
 *
 * @param client			Client index.
 * @param value			New "m_flDuckSpeed".
 */
stock void SetClientDuckSpeed(int client, float value)
{
	SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", value);
}

stock void SetClientDuckAmount(int client, float value)
{
	SetEntPropFloat(client, Prop_Send, "m_flDuckAmount", value);
}

stock void SetClientForcedButtons(int client, int buttons)
{
	SetEntProp(client, Prop_Data, "m_afButtonForced", buttons);
}

stock void SetClientStamina(int client, float stamina)
{
	SetEntPropFloat(client, Prop_Send, "m_flStamina", stamina)
}