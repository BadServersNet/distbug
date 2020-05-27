
#if defined _gamechaos_stocks_strings_included
	#endinput
#endif
#define _gamechaos_stocks_strings_included

/**
 * Prints a message to all admins in the chat area.
 *
 * @param format			Formatting rules.
 * @param ...				Variable number of format parameters.
 * @error					If the client is not connected an error will be thrown.
 */
stock void PrintToChatAdmins(const char[] format, any ...)
{
	char buffer[256];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			AdminId id = GetUserAdmin(i);
			if (!GetAdminFlag(id, Admin_Generic))
			{
				continue;
			}
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToChat(i, "%s", buffer);
		}
	}
}

/**
 * Removes trailings zeroes from a string. Also removes the decimal point if it can.
 *
 * @param string			
 * @param strsize			
 * @param separator			
 * @param array				
 * @param arraysize			
 * @error					If the client is not connected an error will be thrown.
 */
stock bool RemoveTrailing0s(char[] buffer)
{
	bool removed;
	int maxlen = strlen(buffer);
	
	if (maxlen == 0)
	{
		return removed;
	}
	
	for (int i = maxlen - 1; i > 0 && (buffer[i] == '0' || buffer[i] == '.' || buffer[i] == 0); i--)
	{
		if (buffer[i] == 0)
		{
			continue;
		}
		if (buffer[i] == '.')
		{
			buffer[i] = 0;
			removed = true;
			break;
		}
		buffer[i] = 0;
		removed = true;
	}
	return removed;
}

/**
 * Formats time by HHMMSS. Uses ticks for the time.
 *
 * @param timeInTicks		Time in ticks.
 * @param tickRate			Tickrate.
 * @param formattedTime		String to use for formatting.
 * @param size				String size.
 */
stock void FormatTickTimeHHMMSS(int timeInTicks, float tickRate, char[] formattedTime, int size)
{
	if (timeInTicks <= 0)
	{
		FormatEx(formattedTime, size, "-00:00:00");
		return;
	}
	
	int time = RoundFloat(float(timeInTicks) / tickRate * 100.0); // centiseconds
	int iHours = time / 360000;
	int iMinutes = time / 6000 - iHours * 6000;
	int iSeconds = (time - iHours * 360000 - iMinutes * 6000) / 100;
	int iCentiSeconds = time % 100;
	
	if (iHours != 0)
	{
		FormatEx(formattedTime, size, "%02i:", iHours);
	}
	if (iMinutes != 0)
	{
		Format(formattedTime, size, "%s%02i:", formattedTime, iMinutes);
	}
	
	Format(formattedTime, size, "%s%02i.%02i", formattedTime, iSeconds, iCentiSeconds);
}

/**
 * Formats time by HHMMSS. Uses seconds.
 *
 * @param seconds			Time in seconds.
 * @param formattedTime		String to use for formatting.
 * @param size				String size.
 * @param decimals			Amount of decimals to use for the fractional part.
 */
stock void FormatTimeHHMMSS(float seconds, char[] formattedTime, int size, int decimals)
{
	int iFlooredTime = RoundToFloor(seconds);
	int iHours = iFlooredTime / 3600;
	int iMinutes = iFlooredTime / 60 - iHours * 60;
	int iSeconds = iFlooredTime - iHours * 3600 - iMinutes * 60;
	int iFraction = RoundToFloor(FloatFraction(seconds) * Pow(10.0, float(decimals)));
	
	if (iHours != 0)
	{
		FormatEx(formattedTime, size, "%02i:", iHours);
	}
	if (iMinutes != 0)
	{
		Format(formattedTime, size, "%s%02i:", formattedTime, iMinutes);
	}
	char szFraction[32];
	FormatEx(szFraction, sizeof(szFraction), "%i", iFraction);
	
	int iTest = strlen(szFraction);
	for (int i; i < decimals - iTest; i++)
	{
		Format(szFraction, sizeof(szFraction), "%s%s", "0", szFraction);
	}
	
	Format(formattedTime, size, "%s%02i.%s", formattedTime, iSeconds, szFraction);
}

/**
 * Encodes and appends a number onto the end of a UTF-8 string.
 *
 * @param string			String to append to.
 * @param strsize			String size.
 * @param number			Unicode codepoint to encode.
 */
stock void EncodeUtf8(char[] string, char strsize, int number)
{
	// UTF-8 octet sequence (only change digits marked with x)
	/*
	 Char. number range |        UTF-8 octet sequence
		(hexadecimal)   |              (binary)
	--------------------+---------------------------------------------
	0000 0000-0000 007F |                            0xxxxxxx
	0000 0080-0000 07FF |                   110xxxxx 10xxxxxx
	0000 0800-0000 FFFF |          1110xxxx 10xxxxxx 10xxxxxx
	0001 0000-0010 FFFF | 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
	//                     byte 4 | byte 3 | byte 2 | byte 1*/
	
	//char encodedChar = 0b_11110000_10000000_10000000_10000000;
	
	int zeropos = strlen(string);
	
	if (zeropos >= strsize - 1) // need one byte for null terminator
	{
		return;
	}
	
	if (number < 0)
	{
		//PrintToServer("ERROR: Encode() - Can't encode negative numbers");
		return;
	}
	
	if (number >= 0x110_000)
	{
		//PrintToServer("ERROR: Encode() - Number is too big to encode");
		return;
	}
	
	// 1 byte
	if (number < 0x80)
	{
		string[zeropos] = number;
		string[zeropos + 1] = '\0';
	}
	// 2 bytes
	else if (number < 0x800)
	{
		// can't encode if we don't have enough room
		if (zeropos + 2 >= strsize)
		{
			return;
		}
		
		string[zeropos]     = 0b_1100_0000 | (number >> 6); // don't need to mask out bits over 0x7FF
		string[zeropos + 1] = 0b_1000_0000 | (number & 0b_0011_1111);
		
		string[zeropos + 2] = '\0';
	}
	// 3 bytes
	else if (number < 0x10_000)
	{
		// can't encode if we don't have enough room
		if (zeropos + 3 >= strsize)
		{
			return;
		}
		
		string[zeropos]     = 0b_1110_0000 | (number >> 12); // don't need to mask out bits over 0xFFFF
		string[zeropos + 1] = 0b_1000_0000 | ((number >> 6) & 0b_0011_1111);
		string[zeropos + 2] = 0b_1000_0000 | (number & 0b_0011_1111);
		
		string[zeropos + 3] = '\0';
	}
	// 4 bytes
	else if (number < 0x110_000);
	{
		// can't encode if we don't have enough room
		if (zeropos + 4 >= strsize)
		{
			return;
		}
		
		string[zeropos]     = 0b_1111_0000 | (number >> 18); // don't need to mask out bits over 0x10FFFF
		string[zeropos + 1] = 0b_1000_0000 | ((number >> 12) & 0b_0011_1111);
		string[zeropos + 2] = 0b_1000_0000 | ((number >> 6) & 0b_0011_1111);
		string[zeropos + 3] = 0b_1000_0000 | (number & 0b_0011_1111);
		
		string[zeropos + 4] = '\0';
	}
}

// decode a UTF-8 string into an array of unicode codepoints
/**
 * Decodes a UTF-8 string into an array of unicode codepoints.
 *
 * @param string			String to decode.
 * @param strsize			String size.
 * @param codepoints		Array to use to store the codepoints.
 * @param cplength			Array length.
 */
stock void DecodeUtf8(char[] string, int strsize, int[] codepoints, int cplength)
{
	int charindex;
	int cpindex;
	
	while (charindex < strsize && cpindex < cplength)
	{
		if (string[charindex] == '\0')
		{
			break;
		}
		
		int bytes = GetCharBytes(string[charindex]);
		
		switch (bytes)
		{
			case 1:
			{
				codepoints[cpindex] = string[charindex];
			}
			case 2:
			{
				codepoints[cpindex] = (string[charindex++] & 0b_0001_1111) << 6; // byte 2
				codepoints[cpindex] |= string[charindex] & 0b_0011_1111; // byte 1
			}
			case 3:
			{
				codepoints[cpindex] = (string[charindex++] & 0b_0000_1111) << 12; // byte 3
				codepoints[cpindex] |= (string[charindex++] & 0b_0011_1111) << 6; // byte 2
				codepoints[cpindex] |= string[charindex] & 0b_0011_1111; // byte 1
			}
			case 4:
			{
				codepoints[cpindex] = (string[charindex++] & 0b_0000_0111) << 18; // byte 4
				codepoints[cpindex] |= (string[charindex++] & 0b_0011_1111) << 12; // byte 3
				codepoints[cpindex] |= (string[charindex++] & 0b_0011_1111) << 6; // byte 2
				codepoints[cpindex] |= string[charindex] & 0b_0011_1111; // byte 1
			}
		}
		
		charindex++;
		cpindex++;
	}
}