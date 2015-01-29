module image.features;

import std.math;
import std.string;
import std.typecons;

import ae.utils.graphics.color;
import ae.utils.graphics.image;

import image.filter;
import image.util;

/// 
struct HogOptions
{
	/// Number of gradient orientation bins
	uint orientations;

	/// Whether gradients in opposite directions
	/// are treated as equal
	bool signed;

	/// Width and height of cell in pixels
	uint cellSide;

	/// Width and height of block in cells
	uint blockSide;

	/// Offset of one block from the next in cells
	uint blockStride;

	// normalisation - just use unit L2 norm for now
}

/// TODO: allow colour images - take the channel with maximum gradient
/// TODO: at each pixel
double[] hog(V)(V view, HogOptions options)
	if (isView!V && is8BitGreyscale!V)
{
	validate(view, options);

	auto orientations = options.orientations;
	auto gridW 		  = view.w / options.cellSide;
	auto gridH 	      = view.h / options.cellSide;
	auto grid  		  = HistGrid(gridW, gridH, orientations);
	auto hSob  		  = horizontalSobel(view);
	auto vSob  		  = verticalSobel(view);

	// Compute cell histograms
	for (auto y = 0; y < view.h; ++y)
	{
		for (auto x = 0; x < view.w; ++x)
		{
			auto hVal = hSob[x, y];
			auto vVal = vSob[x, y];

			double mag = sqrt(hVal^^2 + vVal ^^2);
			double dir = atan2(vVal, xVal);

			auto oInter = interpolateGradient(dir, orientations, options.signed);
			auto hInter = interpolate!false(x, options.cellSide);
			auto vInter = interpolate!false(y, options.cellSide);

			foreach (yBin; 0 .. 2)
				foreach (xBin; 0 .. 2)
					foreach (oBin; 0 .. 2)
					{
						auto yc = yInter[yBin];
						auto xc = xInter[xBin];
						auto oc = oInter[oBin];

						if (within(view, xc, yc, oc))
						{
							auto w = yInter[yBin + 2] 
								   * hInter[xBin + 2] 
								   * oInter[oBin + 2];

							grid[xc, yc, oc] += w * mag;
						}
					}
		}
	}

	// Accumulate into blocks
	// TODO
}

private bool within(V)(V view, int x, int y)
{
	return x >= 0 && x < view.w && y >= 0 && y < view.h;
}

private struct HistGrid
{
	this(int w, int h, int o)
	{
		_w = w;
		_h = h;
		_o = o;
		_data = new double[w * h * o];
		_data[] = 0.0;
	}
	
	double opIndex(int x, int y, int o)
	{
		return _data[_w * _o * y + _o * x + o];
	}
	
	private int _w;
	private int _h;
	private int _o;
	private double[] _data;
}

// Left index, right index, left weight
private alias Interpolation = Tuple!(int, int, double, double);

private Interpolation interpolate(bool wrap = true)(double value, double binWidth, int numBins = -1)
{
	auto n = value / binWidth + 0.5;
	auto r = cast(int)n;
	auto l = r - 1;
	auto w = 1.0 - n + floor(n);

	if (wrap)
	{
		l = mod(l, numBins);
		r = mod(r, numBins);
	}

	return tuple(l, r, w, 1.0 - w);
}

private T mod(T)(T v, T q)
{
	return (v + q) % q;
}

private enum double pi = PI;

// Bins indices are either continuous or (maxBin, 0)
private Interpolation interpolateGradient(double dir, int orientations, bool signed)
{
	auto range = signed ? 2.0 * pi : pi;
	return interpolate!true(dir % range, range / orientations, orientations);
}

unittest
{
	import image.util;

	bool equalWithin(Interpolation x, Interpolation y, double eps)
	{
		return x[0] == y[0] && x[1] == y[1] && image.util.equalWithin(x[2], y[2], eps);
	}

	double eps = 1e-12;

	// Signed
	assert(equalWithin(interpolateGradient(0.0, 4, true), tuple(3, 0, 0.5, 0.5), eps));
	assert(equalWithin(interpolateGradient(pi/4.0, 4, true), tuple(0, 1, 1.0, 0.0), eps));
	assert(equalWithin(interpolateGradient(pi/2.0, 4, true), tuple(0, 1, 0.5, 0.5), eps));

	// Unsigned
	assert(equalWithin(interpolateGradient(9.0*pi/8.0, 4, false), tuple(0, 1, 1.0, 0.0), eps));
	assert(equalWithin(interpolateGradient(15.5*pi/8.0, 4, false), tuple(3, 0, 0.75, 0.25), eps));
}

private void validate(V)(V view, HogOptions options)
	if (isView!V)
{
	auto cellErr = "%s (%s) must be evenly divisible by cellSide (" ~ options.cellSide ~ ")";

	assert(view.w % cellSide == 0, format(cellErr, "w", view.w));
	assert(view.h % cellSide == 0, format(cellErr, "h", view.h));

	auto blockSide = options.blockSide;
	auto stride = options.blockStride;
	auto blockErr = 
		"%s (%s) minus blockSide (" ~ options.blockSide ~ 
		") must be evenly divisible by blockStride (" ~ options.blockStride ~ ")";

	assert((view.w - blockSide) % stride == 0, format(blockErr, "w", view.w));
	assert((view.w - blockSide) % stride == 0, format(blockErr, "h", view.h));
}