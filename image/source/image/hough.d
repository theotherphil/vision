module image.hough;

import std.random;
import std.range;
import std.typecons;

import ae.utils.graphics.image;
import ae.utils.graphics.color;

// TODO: 
//	Have base image library that doesn't depend on
// 	ml, and a "vision" library that depends on ml and image
import ml.forest;

import image.util;

/// Hough patches as in 
/// http://www.iai.uni-bonn.de/~gall/download/jgall_houghforest_pami11.pdf

/// A feature has multiple channels of the
/// same length and can be indexed by a 
/// (channel, position) pair. Channels are
/// 0-indexed. Note that each channel might
/// be naturally viewed as multi-dimensional
/// (e.g. as a subview of some image), but
/// this is irrelevant for classification
enum isFeature(F) =
	is (typeof(F.init.channels) : size_t) &&
	is (typeof(F.init.length) : size_t) &&
	is (typeof(F.init[0, 0]) : double);

/// Feature backed by freshly allocated array
/// Wildly inefficient
struct ArrayFeature
{
	size_t channels;
	size_t length;

	double opIndex(int c, int p)
	{
		return _data[c * channels + p];
	}

	this(int channels, int length)
	{
		this.channels = channels;
		this.length = length;
		
		_data = new double[channels * length];
	}
	
private:
	double[] _data;
}

static assert(isFeature!ArrayFeature);

struct ViewPatch(V, int patchW = 16, int patchH = 16)
	if (isView!V && is8BitGreyscale!V)
{
	enum length = patchW * patchH;

	@property size_t channels()
	{
		return _patches.length;
	}

	double opIndex(int c, int p)
	{
		return _patches[c].at(p).l;
	}

	this(V[] views, uint x, uint y)
	{
		assert(views.length > 0);

		auto w = views[0].w;
		auto h = views[0].h;

		for (auto i = 1; i < views.length; ++i)
			assert(views[i].w == w && views[i].h == h);

		auto x0 = x - patchW/2;
		auto y0 = y - patchH/2;
		auto x1 = x + patchW/2;
		auto y1 = y + patchH/2;

		assert(x0 >= 0 && x0 < w);
		assert(y0 >= 0 && y0 < h);
		assert(x1 > x0 && x1 <= w);
		assert(y1 > y0 && y1 <= h);

		// TODO: why do I need this cast?
		_patches = cast(Patch[])views.map!(v => v.crop(x0, y0, x1,y1)).array;
	}

private 

	alias Patch = typeof(crop(V.init, 0, 0, 0, 0));
	Patch[] _patches;
}

static assert(isFeature!(ViewPatch!(Image!L8)));

// Treat 2d view as 1d array
private ViewColor!V at(V)(V view, uint p)
	if (isView!V)
{
	auto y = p / view.w;
	auto x = p - y * view.w;
	return view[x, y];
}

unittest
{
	auto img = [0, 2, 4, 6, 8, 10, 12, 14, 16].toL8(3, 3);
	foreach(p; 0 ..9)
		assert(img.at(p).l == 2 * p);
}

struct FeatureClassifier(F)
	if (isFeature!F)
{
	bool classify(F feature)
	{
		return feature[_c, _p] > feature[_c, _q] + _t;
	}

	this (int c, int p, int q, double t)
	{
		_c = c;
		_p = p;
		_q = q;
		_t = t;
	}

private:
	int _c;
	int _p;
	int _q;
	double _t;
}

/// Generates feature classifiers with query channel and both
/// query indices distributed uniforly across channels and 
/// positions. Threshold is generated uniformly in [0, maxThresh)
struct FeatureClassifierRange(F)
	if (isFeature!F)
{
	bool empty()
	{
		return false;
	}

	void popFront()
	{
		_front = generate();
	}

	FeatureClassifier!F front()
	{
		return _front;
	}

	this(int channels, int length, double maxThresh, int seed = 1)
	{
		_gen = Random(seed);
		_channels = channels;
		_length = length;
		_maxThresh = maxThresh;
		_front = generate();
	}

private:

	FeatureClassifier!F generate()
	{
		auto c = uniform(0, _channels - 1, _gen);
		auto p = uniform(0, _length - 1, _gen);
		auto q = uniform(0, _length - 1, _gen);
		auto t = uniform(0, _maxThresh, _gen);

		return FeatureClassifier!F(c, p, q, t);
	}

	Random _gen;
	int _channels;
	int _length;
	double _maxThresh;
	FeatureClassifier!F _front;
}

static assert(isInputRange!(FeatureClassifierRange!ArrayFeature));

struct HoughPatch
{
	/// Image data as feature
	ViewPatch patch;

	/// Class this patch belongs to (or 0 for background)
	uint label;

	/// x displacement from centre of object
	/// (ignored if label = 0)
	double dx;

	/// y displacement from centre of object
	/// (ignored if label = 0)
	double dy;
}

// Need position and category information along with patch.
// features for forests are just arrays of doubles so we need
// to be able to translate between features and double[].
class HoughSelector(F) : ClassifierSelector!(FeatureClassifier!F)
{
	alias C = FeatureClassifier!F;

	Tuple!(C, Split) select(InputRange!C classifier, DataView data)
	{
		// TODO: 
		// alternate between using EntropyMinimiser on the labels,
		// and minimising SSE for the distances

		// TODO:
		// need an adapter to view HoughPatch as double[]. This is
		// horribly inefficient, so think about adding loads more
		// type parameters to the forest stuff
	}
}