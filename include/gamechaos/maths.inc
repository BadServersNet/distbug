
#if defined _gamechaos_stocks_maths_included
	#endinput
#endif
#define _gamechaos_stocks_maths_included

#define GC_MATHS_VERSION 0x02_00_00
#define GC_MATHS_VERSION_STRING "2.0.0"

#include <gamechaos/vectors>

#define GC_PI 3.14159265359

#define GC_DEGREES(%1) ((%1) * 180.0 / GC_PI) // convert radians to degrees
#define GC_RADIANS(%1) ((%1) * GC_PI / 180.0) // convert degrees to radians

#define GC_FLOAT_NAN               view_as<float>(0xffffffff)
#define GC_FLOAT_INFINITY          view_as<float>(0x7f800000)
#define GC_FLOAT_NEGATIVE_INFINITY view_as<float>(0xff800000)

#define GC_FLOAT_LARGEST_POSITIVE view_as<float>(0x7f7fffff)
#define GC_FLOAT_SMALLEST_NEGATIVE view_as<float>(0xff7fffff)

#define GC_FLOAT_SMALLEST_POSITIVE view_as<float>(0x00000001)
#define GC_FLOAT_LARGEST_NEGATIVE view_as<float>(0x80000001)

#define GC_INT_MAX 0x7fffffff
#define GC_INT_MIN 0xffffffff


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
stock void GCLineIntersection(const float planePoint[3], const float planeNormal[3], const float linePoint[3], const float lineDirection[3], float result[3])
{
	if (GetVectorDotProduct(planeNormal, lineDirection) == 0)
	{
		return;
	}
	
	float t = (GetVectorDotProduct(planeNormal, planePoint)
			 - GetVectorDotProduct(planeNormal, linePoint))
			 / GetVectorDotProduct(planeNormal, lineDirection);
	
	float lineDir[3];
	lineDir = lineDirection;
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
stock void GCCalcPointAngleDistance(const float start[3], const float angle[3], float distance, float result[3])
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
stock bool GCIsRoughlyEqual(float z1, float z2, float tolerance)
{
	return FloatAbs(z1 - z2) < tolerance;
}

/**
 * Checks if a float is within a range
 *
 * @param number			Float to check.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					True on success, false otherwise.
 */
stock bool GCIsFloatInRange(float number, float min, float max)
{
	return number >= min && number <= max;
}

/**
 * Keeps the yaw angle within the range of -180 to 180.
 *
 * @param angle				Angle.
 * @return 					Normalised angle.
 */
stock float GCNormaliseYaw(float angle)
{
	if (angle <= -180.0)
	{
		angle += 360.0;
	}
	
	if (angle > 180.0)
	{
		angle -= 360.0;
	}
	
	return angle;
}

/**
 * Keeps the yaw angle within the range of -180 to 180.
 *
 * @param angle				Angle.
 * @return 					Normalised angle.
 */
stock float GCNormaliseYawRad(float angle)
{
	if (angle <= -FLOAT_PI)
	{
		angle += FLOAT_PI * 2;
	}
	
	if (angle > FLOAT_PI)
	{
		angle -= FLOAT_PI * 2;
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
stock float GCInterpLinear(float f1, float f2, float fraction)
{
	float diff = f2 - f1;
	
	return diff * fraction + f1;
}

/**
 * Calculates the linear fraction from a value that was interpolated and 2 values it was interpolated from.
 *
 * @param f1				Float 1.
 * @param f2				Float 2.
 * @param fraction			Interpolated value.
 * @return 					Fraction.
 */
stock float GCCalcLerpFraction(float f1, float f2, float lerped)
{
	float diff = f2 - f1;
	
	float fraction = lerped - f1 / diff;
	return fraction;
}

/**
 * Calculate absolute value of an integer.
 *
 * @param x					Integer.
 * @return 					Absolute value of integer.
 */
stock int GCIntAbs(int x)
{
   return x >= 0 ? x : -x;
}

/**
 * Get the maximum of 2 integers.
 *
 * @param n1				Integer.
 * @param n2				Integer.
 * @return 					The biggest of n1 and n2.
 */
stock int GCIntMax(int n1, int n2)
{
	return n1 > n2 ? n1 : n2;
}

/**
 * Get the minimum of 2 integers.
 *
 * @param n1				Integer.
 * @param n2				Integer.
 * @return 					The smallest of n1 and n2.
 */
stock int GCIntMin(int n1, int n2)
{
	return n1 < n2 ? n1 : n2;
}

/**
 * Checks if an integer is within a range
 *
 * @param number			Integer to check.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					True on success, false otherwise.
 */
stock bool GCIsIntInRange(int number, int min, int max)
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
stock float GCCalcIntPercentage(int numerator, int denominator)
{
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
stock int GCIntPow(int base, int exponent)
{
	if (exponent < 0)
	{
		return 0;
	}
	
	int result = 1;
	for (;;)
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
 * Swaps the values of 2 variables.
 *
 * @param cell1				Cell 1.
 * @param cell2				Cell 2.
 */
stock void GCSwapCells(any &cell1, any &cell2)
{
	any temp = cell1;
	cell1 = cell2;
	cell2 = temp;
}

/**
 * Clamps an int between min and max.
 *
 * @param value				Float to clamp.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					Clamped value.
 */
stock int GCIntClamp(int value, int min, int max)
{
	if (value < min)
	{
		return min;
	}
	if (value > max)
	{
		return max;
	}
	return value;
}

/**
 * Returns the biggest of 2 values.
 *
 * @param num1				Number 1.
 * @param num2				Number 2.
 * @return 					Biggest number.
 */
stock float GCFloatMax(float num1, float num2)
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
stock float GCFloatMin(float num1, float num2)
{
	if (num1 < num2)
	{
		return num1;
	}
	return num2;
}

/**
 * Clamps a float between min and max.
 *
 * @param value				Float to clamp.
 * @param min				Minimum range.
 * @param max				Maximum range.
 * @return 					Clamped value.
 */
stock float GCFloatClamp(float value, float min, float max)
{
	if (value < min)
	{
		return min;
	}
	if (value > max)
	{
		return max;
	}
	return value;
}
