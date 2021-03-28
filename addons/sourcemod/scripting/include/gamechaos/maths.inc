
#if defined _gamechaos_stocks_maths_included
	#endinput
#endif
#define _gamechaos_stocks_maths_included

#include <gamechaos/vectors>

/**
 * Credit: https://stackoverflow.com/questions/5666222/3d-line-plane-intersection
 * Determines the point of intersection between a plane defined by a point and a normal vector and a line defined by a point and a direction vector.
 *
 * @param planePoint    A point on the plane.
 * @param planeNormal   Normal vector of the plane.
 * @param linePoint     A point on the line.
 * @param lineDirection Direction vector of the line.
 * @param result		Resultant vector.
 */
stock void LineIntersection(const float planePoint[3], const float planeNormal[3], const float linePoint[3], const float lineDirection[3], float result[3])
{
	if (GetVectorDotProduct(planeNormal, lineDirection) == 0)
	{
		return;
	}
	
	float t = (GetVectorDotProduct(planeNormal, planePoint)
			 - GetVectorDotProduct(planeNormal, linePoint))
			 / GetVectorDotProduct(planeNormal, lineDirection);
	
	float lineDir[3];
	CopyVector(lineDirection, lineDir);
	NormalizeVector(lineDir, lineDir);
	
	ScaleVector(lineDir, t);
	
	AddVectors(linePoint, lineDir, result);
}

/**
 * Calculates a point according to angles supplied that is a certain distance away.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 * @param distance			Maximum distance to trace.
 * @return 					True on success, false otherwise.
 */
stock void CalcPointAngleDistance(const float start[3], const float angle[3], float distance, float result[3])
{
	float zsine = Sine(DegToRad(-angle[0]));
	float zcos = Cosine(DegToRad(-angle[0]));
	
	result[0] = Cosine(DegToRad(angle[1])) * zcos;
	result[1] = Sine(DegToRad(angle[1])) * zcos;
	result[2] = zsine;
	
	ScaleVector(result, distance);
	AddVectors(start, result, result);
}

/**
 * Compares how close 2 floats are.
 *
 * @param z1				Float 1
 * @param z2				Float 2
 * @param tolerance			How close the floats have to be to return true.
 * @return 					True on success, false otherwise.
 */
stock bool IsRoughlyEqual(float z1, float z2, float tolerance)
{
	return IsFloatInRange(z1 - z2, -tolerance, tolerance);
}

/**
 * Checks if a float is within a range
 *
 * @param number			Float to check.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					True on success, false otherwise.
 */
stock bool IsFloatInRange(float number, float min, float max)
{
	return number >= min && number <= max;
}

/**
 * Checks if a float is within a lower bound.
 *
 * @param z1				Float 1.
 * @param z2				Float 2.
 * @param tolerance			Size of lower bound.
 * @return 					True if success, false otherwise.
 */
stock bool IsFailstat(float z1, float z2, float tolerance)
{
	return z1 < z2 && z1 > z2 - tolerance;
}

/**
 * Keeps the yaw angle within the range of -180 to 180.
 *
 * @param angle				Angle.
 * @return 					Normalised angle.
 */
public float NormaliseAngle(float angle)
{
	while (angle <= -180.0)
	{
		angle += 360.0;
	}
	
	while (angle > 180.0)
	{
		angle -= 360.0;
	}
	
	return angle;
}

/**
 * Linearly interpolates between 2 values.
 *
 * @param f1				Float 1.
 * @param f2				Float 2.
 * @param fraction			Amount to interpolate.
 * @return 					Interpolated value.
 */
stock float InterpLinear(float f1, float f2, float fraction)
{
	float diff = f1 - f2;
	
	return diff * fraction + f2;
}

/**
 * Calculates the linear fraction from a value that was interpolated and 2 values it was interpolated from.
 *
 * @param f1				Float 1.
 * @param f2				Float 2.
 * @param fraction			Interpolated value.
 * @return 					Fraction.
 */
stock float CalcLerpFraction(float f1, float f2, float lerped)
{
	float diff = f1 - f2;
	
	float fraction = lerped - f2 / diff;
}

/**
 * Calculate absolute value of an integer.
 *
 * @param x					Integer.
 * @return 					Absolute value of integer.
 */
stock int Abs(x)
{
   return x >= 0 ? x : -x;
}

/**
 * Checks if an integer is within a range
 *
 * @param number			Integer to check.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					True on success, false otherwise.
 */
stock bool IsIntInRange(int number, int min, int max)
{
	return number >= min && number <= max;
}

/**
 * Calculates a float percentage from a common fraction.
 *
 * @param numerator			Numerator.
 * @param denominator		Denominator.
 * @return 					Float percentage. -1.0 on failure.
 */
stock float CalcIntPercentage(int numerator, int denominator)
{
	if (denominator == 0)
	{
		return -1.0;
	}
	
	return float(numerator) / float(denominator) * 100.0;
}

/**
 * Integer power.
 * Returns the base raised to the power of the exponent.
 * Returns 0 if exponent is negative.
 *
 * @param base			Base to be raised.
 * @param exponent		Value to raise the base.
 * @return				Value to the power of exponent.
 */
stock int IntPow(int base, int exponent)
{
	if (exponent < 0)
	{
		return 0;
	}
	
	int result = 1;
	while (true)
	{
		if (exponent & 1)
		{
			result *= base
		}
		
		exponent >>= 1;
		
		if (!exponent)
		{
			break;
		}
		
		base *= base;
	}
	return result;
}

/**
 * Swaps the bits of 2 cells.
 *
 * @param cell1				Cell 1.
 * @param cell2				Cell 2.
 */
stock void SwapCells(any &cell1, any &cell2)
{
	any temp = cell1;
	cell1 = cell2;
	cell2 = temp;
}

/**
 * Returns the biggest of 2 values.
 *
 * @param num1				Number 1.
 * @param num2				Number 2.
 * @return 					Biggest number.
 */
stock float FloatMax(float num1, float num2)
{
	if (num1 > num2)
	{
		return num1;
	}
	return num2;
}

/**
 * Returns the smallest of 2 values.
 *
 * @param num1				Number 1.
 * @param num2				Number 2.
 * @return 					Smallest number.
 */
stock float FloatMin(float num1, float num2)
{
	if (num1 < num2)
	{
		return num1;
	}
	return num2;
}