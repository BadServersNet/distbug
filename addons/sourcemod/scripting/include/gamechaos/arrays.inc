
#if defined _gamechaos_stocks_arrays_included
	#endinput
#endif
#define _gamechaos_stocks_arrays_included

#define GC_ARRAYS_VERSION 0x01_00_00
#define GC_ARRAYS_VERSION_STRING "1.0.0"

/**
 * Copies an array into an arraylist.
 *
 * @param array			Arraylist Handle.
 * @param index			Index in the arraylist.
 * @param values		Array to copy.
 * @param size			Size of the array to copy.
 * @param offset		Arraylist offset to set.
 * @return				Number of cells copied.
 * @error				Invalid Handle or invalid index.
 */
stock int GCSetArrayArrayIndexOffset(ArrayList array, int index, const any[] values, int size, int offset)
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
 * @param result		Array to copy to.
 * @param size			Size of the array to copy to.
 * @param offset		Arraylist offset.
 * @return				Number of cells copied.
 * @error				Invalid Handle or invalid index.
 */
stock int GCCopyArrayArrayIndex(const ArrayList array, int index, any[] result, int size, int offset)
{
	int cells;
	for (int i = offset; i < (size + offset); i++)
	{
		result[i] = array.Get(index, i);
		cells++;
	}
	return cells;
}