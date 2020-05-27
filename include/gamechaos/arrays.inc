
#if defined _gamechaos_stocks_arrays_included
	#endinput
#endif
#define _gamechaos_stocks_arrays_included

/**
 * Puts the values from a string of integers into an array
 *
 * @param string			
 * @param strsize			
 * @param separator			
 * @param array				
 * @param arraysize			
 */
stock void SeparateIntsFromString(const char[] string, const char[] separator, int[] array, int arraysize)
{
	char[][] explodedbuffer = new char[arraysize][32];
	
	ExplodeString(string, separator, explodedbuffer, arraysize, sizeof(explodedbuffer[]));
	
	for (int i; i < arraysize; i++)
	{
		array[i] = StringToInt(explodedbuffer[i]);
	}
}

/**
 * Sets an arraylist's specified cells to an array.
 *
 * @param array			Arraylist Handle.
 * @param index			Index in the arraylist.
 * @param values		Array to copy.
 * @param size			Size of the array to copy.
 * @param offset		Arraylist offset to set.
 * @return				Number of cells copied.
 * @error				Invalid Handle or invalid index.
 */
stock int SetArrayArrayIndex(ArrayList array, int index, const any[] values, int size, int offset)
{
	int cells;
	for (int i; i < size; i++)
	{
		array.Set(index, values[i], offset + i);
		cells++;
	}
	return cells;
}

/**
 * Copies an arraylist's specified cells to an array.
 *
 * @param array			Arraylist Handle.
 * @param index			Index in the arraylist.
 * @param values		Array to set.
 * @param size			Size of the array to set.
 * @param offset		Arraylist offset.
 * @return				Number of cells copied.
 * @error				Invalid Handle or invalid index.
 */
stock int CopyArrayArrayIndex(const ArrayList array, int index, any[] values, int size, int offset)
{
	int cells;
	for (int i; i < size; i++)
	{
		values[i] = array.Get(index, offset + i);
		cells++;
	}
	return cells;
}