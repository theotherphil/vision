module image.hough;

import std.random;
import std.range;

import ae.utils.graphics.image;
import ae.utils.graphics.color;

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
	is (typeof(F.init.channels) : uint) &&
	is (typeof(F.init.length) : uint) &&
	is (typeof(F.init[0, 0]) : double);

/// Feature backed by freshly allocated array
/// Wildly inefficient
struct ArrayFeature
{
	int channels;
	int length;

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

/// Feature that's a view into patches of
/// some underlying images
struct ViewFeature(V...)
{
	@property int channels()
	{
		return _views.length;
	}

	@property int length()
	{
		return patchW * patchH;
	}

	double opIndex(int c, int p)
	{
		// this isn't the feature - this
		// is the thing that generates the features,
		// which are just proxies to the images
		// hold by this struct

		// need to index into relevant patch of
		// underlying images
		return 1.0;
	}

	int patchW;
	int patchH;

	// need to be able to get a view into 
	// a patch of an image

	this(V views, int patchW, int patchH)
	{
		this.patchW = patchW;
		this.patchH = patchH;

		// TODO: 
		//	all views the same size,
		// 	all have elements convertible
		//  to doubles, all views are single
		//  channel. Problem: currently ae 
		//  images can't have floating point
		//	elements

		_views = views;
	}

private:

	V _views;
}

static assert(isFeature!(ViewFeature!(Image!L8)));

// Given view and a pixel, construct channels and check whether point
// p in channel C is >= q in channel D + r

// Feature version 1: intensity, hSobelAbs, vSobelAbs
// Need to be able to take an image and a pixe, and get a
// Feature/Patch/Whatever

struct FeatureClassifier(F)
	if (isFeature!F)
{
	this (int c, int p, int q, double t)
	{
		_c = c;
		_p = p;
		_q = q;
		_t = t;
	}

	bool classify(F feature)
	{
		return feature[_c, _p] > feature[_c, _q] + _t;
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