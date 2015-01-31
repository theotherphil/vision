module image.features;

import std.math;
import std.string;
import std.typecons;
import std.typetuple;

import ae.utils.graphics.color;
import ae.utils.graphics.draw;
import ae.utils.graphics.image;

import image.filter;
import image.math;
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

	auto grid = histGrid(view, options);
	auto side = options.blockSide;
	auto step = options.blockStride;
	auto bins = options.orientations;

	auto xBlocks = (grid.w - side) / step;
	auto yBlocks = (grid.h - side) / step;
	auto chunkSize = bins * side ^^ 2;

	double[] descriptor = new double[xBlocks * yBlocks * chunkSize];

	for (auto y = 0; y + side <= grid.h; ++y)
	{
		for (auto x = 0; x + side <= grid.w; ++x)
		{
			auto start = y * xBlocks * chunkSize + x * chunkSize;

			// concatenate all cells in block and normalise
			for (auto yb = 0; yb < side; ++yb)
			{
				for (auto xb = 0; xb < side; ++xb)
				{
					auto s = start + yb * side * bins + xb * bins;
					auto e = s + bins;

					descriptor[s .. e]  = grid.cell(x, y);
					descriptor[s .. e] /= l2Norm(descriptor[s .. e]);
				}
			}		
		}
	}

	return descriptor;
}

/// Returns an array of edge orientation histograms
HistGrid histGrid(V)(V view, HogOptions options)
	if (isView!V && is8BitGreyscale!V)
{
	validate(view, options);
	
	auto orientations = options.orientations;
	auto gridW 		  = view.w / options.cellSide;
	auto gridH 	      = view.h / options.cellSide;
	auto grid  		  = HistGrid(gridW, gridH, orientations);
	auto hSob  		  = horizontalSobel(view);
	auto vSob  		  = verticalSobel(view);

	for (auto y = 0; y < view.h; ++y)
	{
		for (auto x = 0; x < view.w; ++x)
		{
			auto hVal = cast(double)(hSob[x, y].l);
			auto vVal = cast(double)(vSob[x, y].l);
		
			double mag = sqrt(hVal^^2 + vVal^^2);
			double dir = atan2(vVal, hVal);
			
			auto oInter = interpolateGradient(dir, orientations, options.signed);
			auto hInter = interpolate!false(x, options.cellSide);
			auto vInter = interpolate!false(y, options.cellSide);

			foreach (yBin; TypeTuple!(0, 1))
				foreach (xBin; TypeTuple!(0, 1))
					foreach (oBin; TypeTuple!(0, 1))
				{
					auto yc = vInter[yBin];
					auto xc = hInter[xBin];
					auto oc = oInter[oBin];
					
					if (within(view, xc, yc, oc))
					{
						auto w = vInter[yBin + 2] 
						* hInter[xBin + 2] 
						* oInter[oBin + 2];
						
						grid[xc, yc, oc] += w * mag;
					}
				}
		}
	}

	return grid;
}

/// theta is counter-clockwise rotation of line
auto ray(int side, bool half, double theta)
{
	auto pad = cast(int)(0.05 * side);
	auto mid = side / 2;
	auto image = Image!L8(side, side);
	line(image, mid, pad, mid, half ? mid : side - pad, L8(255));
	return image.rotate(theta, L8(0), mid, mid);
}

struct HistGrid
{
	this(int w, int h, int o)
	{
		w = w;
		h = h;
		o = o;
		_data = new double[w * h * o];
		_data[] = 0.0;
	}

	double[] cell(int x, int y)
	{
		auto start = cellStart(x, y);
		return _data[start .. start + o];
	}

	double opIndex(int x, int y, int o)
	{
		return _data[cellStart(x, y) + o];
	}

	private int cellStart(int x, int y)
	{
		return w * o * y + o * x;
	}

	int w;
	int h;
	int o;

	private double[] _data;
}

private bool within(V)(V view, int x, int y)
{
	return x >= 0 && x < view.w && y >= 0 && y < view.h;
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
	auto cellErr = "%s (%s) must be evenly divisible by cellSide (" ~ options.cellSide.to!string ~ ")";

	assert(view.w % options.cellSide == 0, format(cellErr, "w", view.w));
	assert(view.h % options.cellSide == 0, format(cellErr, "h", view.h));

	auto blockSide = options.blockSide;
	auto stride = options.blockStride;
	auto blockErr = 
		"%s (%s) minus blockSide (" ~ options.blockSide.to!string ~ 
		") must be evenly divisible by blockStride (" ~ options.blockStride.to!string ~ ")";

	assert((view.w - blockSide) % stride == 0, format(blockErr, "w", view.w));
	assert((view.w - blockSide) % stride == 0, format(blockErr, "h", view.h));
}