module image.noise;

import std.random;

import ae.utils.graphics.image;
import ae.utils.graphics.view;

import image.affine;
import image.math;
import image.util;
import image.viewrange;

/// Add independent additive Gaussian noise to each pixel with given mean and stdev
ViewImage!V gaussianNoise(V)(V view, double mean = 0, double stdev = 10, int seed = 1)
	if (isView!V)
{
	return copyAndThen!gaussianNoiseMut(view, mean, stdev, seed);
}

/// ditto
void gaussianNoiseMut(V)(V view, double mean = 0, double stdev = 10, int seed = 1)
	if (isDirectView!V)
{
	auto normal = RandomNormal(mean, stdev, seed);

	foreach (ref pix; view.source)
	{
		foreach(ref c; pix.tupleof)
		{
			c = clipTo!(typeof(c))(c + normal.front);
			normal.popFront;
		}
	}
}

/// Convert pixels to black or white at given rate.
/// Black and white occur with equal probability.
ViewImage!V saltAndPepper(V)(V view, double rate = 0.1, int seed = 1)
{
	return copyAndThen!saltAndPepperMut(view, rate, seed);
}

/// ditto
void saltAndPepperMut(V)(V view, double rate = 0.1, int seed = 1)
{
	alias C = ViewColor!V;
	auto gen = Random(seed);

	// TODO: 
	// 	Deal with colour spaces where this doesn't
	// 	produce black and white pixels
	foreach (ref pix; view.source)
	{
		if (uniform(0.0, 1.0, gen) > rate)
			continue;

		auto isWhite = uniform(0.0, 1.0, gen) >= 0.5;

		foreach(ref c; pix.tupleof)
			c = isWhite ? typeof(c).max : typeof(c).min;
	}
}
// TODO: shot noise
// TODO: non-local means to remove Gaussian noise
