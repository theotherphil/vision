module image.math;

import std.algorithm;
import std.math;
import std.random;
import std.range;
import std.typecons;

///	Cast with clipping instead of overflow
To clipTo(To, From)(From x)
{
	return cast(To)(max(To.min, min(To.max, x)));
}

unittest
{
	assert(clipTo!int(25) == 25, "25 :: int -> 25 :: int");
	assert(clipTo!uint(25) == 25, "25 :: int -> 25 :: uint");
	assert(clipTo!uint(-25) == 0, "-25 :: int -> 0 :: uint");
	assert(clipTo!ubyte(500) == 255, "500 :: int -> 255 :: ubyte");
	assert(clipTo!ubyte(-1.0) == 0, "-1.0 :: double -> 0 :: ubyte");
}

double l2Norm(R)(R r)
	if (isInputRange!R && is (ElementType!R : double))
{
	return sqrt(r.map!(x => cast(double)(x * x)).sum);
}

unittest
{
	assert(l2Norm([1, 1, 3, 5]) == 6.0, "Array of ints");
	assert(l2Norm([1.0, 1.0, 3.0, 5.0]) == 6.0, "Array of doubles");
	assert(l2Norm(new double[0]) == 0.0, "Empty range");
}

/// Naive algorithm - ignores cancellation issues
double variance(R)(R range)
	if (isInputRange!R && is (ElementType!R : double))
{
	auto n = 0;
	auto sx = 0.0;
	auto ssx = 0.0;

	foreach (x; range)
	{
		n++;
		sx += x;
		ssx += x^^2;
	}

	return (ssx - sx^^2/n)/(n - 1);
}

/// ditto
auto stdev(R)(R range)
	if (isInputRange!R && is (ElementType!R : double))
{
	return range.variance.sqrt;
}

///	If u1 and u2 are uniformly distributed in (0, 1] then result is
///	standard normally distributed.
///
///	Hopefully std.random will acquire more distributions soon and this
///	can be removed.	
Tuple!(double, double) boxMullerTransform(double u1, double u2)
{
	double m = sqrt(-2.0 * log(max(u1, double.epsilon)));
	double x = 2.0 * PI * u2;
	return tuple(cast(double)(m*cos(x)), cast(double)(m*sin(x)));
}

///	Generates normally distributed pseudo-random numbers
struct RandomNormal
{
	this(double mean, double stdev, int seed = 1)
	{
		_gen   = Random(seed);
		_mean  = mean;
		_stdev = stdev;
		refresh();
	}

	bool empty()
	{ 
		return false; 
	}

	void popFront()
	{
		_index = 1 - _index;
		if (_index == 0)
		{
			refresh();
		}
	}

	double front()
	{
		return _values[_index];
	}
	
private:
	
	double scale(double x)
	{
		return _stdev * (x + _mean);
	}

	void refresh()
	{
		auto u1 = uniform(0.0, 1.0, _gen);
		auto u2 = uniform(0.0, 1.0, _gen);
		auto x  = boxMullerTransform(u1, u2);

		_values[0] = scale(x[0]);
		_values[1] = scale(x[1]);
	}

	Random _gen;
	double _mean;
	double _stdev;
	int _index;
	double[2] _values;
}

unittest
{
	auto gen = RandomNormal(0, 1.0, 1);
	auto values = gen.take(1000).array;

	auto mean = values.sum/values.length;
	auto stdev = stdev(values);

	assert(abs(mean) < 0.1);
	assert(abs(stdev - 1) < 0.1);
}