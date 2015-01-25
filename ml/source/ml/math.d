module ml.math;

import std.algorithm;
import std.math;
import std.range;

public import ml.dataset;

double entropy(T)(T labels, uint numClasses)
	if (isLabelSet!T)
{
	auto counts = new int[numClasses];
	
	foreach (l; labels)
		++counts[l];
	
	double entropy = 0.0;
	double total = labels.length;
	
	foreach (c; counts)
	{
		if (c == 0)
			continue;
		
		auto prob = c / total;
		entropy -= prob * log2(prob);
	}
	
	return entropy;
}

version(unittest)
{
	bool equalWithin(double x, double y, double eps)
	{
		return abs(x - y) < eps;
	}
}

unittest
{
	assert(entropy([1, 1], 2u) == 0.0);
	assert(entropy([0u], 1u) == 0.0);
	assert(entropy([0u, 1u], 2u) == 1.0);
	assert(entropy([0, 1, 2, 3], 4u) == 2.0);
}

size_t argMax(double[] xs)
{
	auto max = -double.infinity;
	size_t idx = 0;

	foreach (i, e; xs)
	{
		if (e > max)
		{
			max = e;
			idx = i;
		}
	}

	return idx;
}

size_t argMin(double[] xs)
{
	auto max = double.infinity;
	size_t idx = 0;
	
	foreach (i, e; xs)
	{
		if (e < max)
		{
			max = e;
			idx = i;
		}
	}
	
	return idx;
}

unittest
{
	assert(argMax([0, 2, 4, 1]) == 2);
	assert(argMin([1, 0, 2, 8]) == 1);
}