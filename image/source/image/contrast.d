module image.contrast;

import std.algorithm;
import std.array;
import std.conv;

import ae.utils.graphics.image;
import ae.utils.graphics.color;

import image.util;
import image.math;
import image.viewrange;

int[256] cumulativeHistogram(V)(V view)
	if (isView!V && is (ViewColor!V == L8))
{
	int[256] hist;
	hist[] = 0;

	foreach (pix; view.source)
		++hist[pix.l];

	for (uint i = 1; i < 256; ++i)
		hist[i] += hist[i - 1];

	return hist;
}

unittest
{
	import image.util;

	auto img = [1, 2, 3, 2, 1].toL8(5, 1);
	auto hist = img.cumulativeHistogram;

	assert(hist[0 .. 4] == [0, 2, 4, 5]);
	assert(hist[4 .. $].all!(x => x == 5));
}

void equaliseHistogramMut(V)(V view)
	if (isWritableView!V && is8BitGreyscale!V)
{
	auto hist    = cumulativeHistogram(view);
	double total = hist[255];

	foreach (ref pix; view.source)
	{
		auto v = min(255.0, 255.0 * hist[pix.l] / total);
		pix = L8(cast(ubyte)v);
	}
}

auto equaliseHistogram(V)(V view)
	if (isView!V && is8BitGreyscale!V)
{
	return copyAndThen!equaliseHistogramMut(view);
}

/// Linearly stretches image contrast between min and max percentiles
/// Inclusive lower bound, exclusive upper
auto stretchContrast(V)(V view, int minPercentile, int maxPercentile)
	if (isView!V && is8BitGreyscale!V)
{
	assert(maxPercentile >= minPercentile, "maxPercentile must be >= minPercentile");

	int[256] hist = cumulativeHistogram(view);

	auto lowValue  = 0;
	auto highValue = 0;

	double count = hist[$ - 1];
	for (int i = 0; i < 256; ++i)
	{
		auto per = 100.0 * hist[i]/count;
		if (per <= minPercentile)
			lowValue = i;
		if (per < maxPercentile)
			highValue = i;
	}

	return view.stretch(lowValue, highValue);
}

private L8 stretch(L8 pix, ubyte low, ubyte high)
{
	return stretch(pix.l, low, high).toL8;
}

private ubyte stretch(ubyte pix, ubyte low, ubyte high)
{
	return clipTo!ubyte((255.0 * (pix - low))/(high - low));
}

unittest
{
	assert(stretch(0, 10, 100) == 0);
	assert(stretch(110, 10, 100) == 255);
	assert(stretch(10, 10, 100) == 0);
	assert(stretch(100, 10, 100) == 255);
	assert(stretch(13, 10, 100) == 8);
	assert(stretch(L8(13), 10, 100) == L8(8));
}

/// Linearly stretch the given range to [0, 255]
auto stretch(V)(V view, int low, int high)
	if (isWritableView!V && is8BitGreyscale!V)
{
	auto lo = cast(ubyte)low;
	auto hi = cast(ubyte)high;

	return view.colorMap!(p => stretch(p, lo, hi));
}

unittest
{
	import image.util;

	auto img = [11, 12, 13, 14].toL8(2, 2);
	auto str = img.stretch(10, 110);

	assert(str.pixelsEqual([2, 5, 7, 10].toL8(2, 2)));
}

// TODO: histogram match, adapative local histogram equalisation