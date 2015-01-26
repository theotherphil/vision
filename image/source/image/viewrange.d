module image.viewrange;

import std.algorithm;
import std.range;

import ae.utils.graphics.view;

struct ViewSource(V)
	if (isView!V)
{
	this(V view)
	{
		v = view;
		r = cartesianProduct(iota(view.w), iota(view.h));
	}
	
	bool empty()
	{
		return r.empty;
	}

	static if (isWritableView!V)
	{
		ref ViewColor!V front()
		{
			auto loc = r.front;
			return v[loc[0], loc[1]];
		}
	}
	else
	{
		ViewColor!V front()
		{
			auto loc = r.front;
			return v[loc[0], loc[1]];
		}
	}
	
	void popFront()
	{
		r.popFront;
	}

	V v;
	typeof(cartesianProduct(iota(V.init.w), iota(V.init.h))) r;
}

unittest
{
	import ae.utils.graphics.image;

	auto image = Image!ubyte(1, 1);
	image[0, 0] = 7;

	foreach (ref pix; image.source)
		pix = 19;

	assert(image[0, 0] == 19);
}

auto source(V)(V view)
{
	return ViewSource!V(view);
}

struct ViewSink(V)
	if (isWritableView!V)
{
	this(V view)
	{
		v = view;
		r = cartesianProduct(iota(view.w), iota(view.h));
	}

	void put(ViewColor!V pix)
	{
		auto loc = r.front;
		v[loc[0], loc[1]] = pix;
		r.popFront;
	}

	V v;
	typeof(cartesianProduct(iota(V.init.w), iota(V.init.h))) r;
}

auto sink(V)(V view)
{
	return ViewSink!V(view);
}

bool pixelsEqual(V,W)(V v, W w)
	if (isView!V && isView!W && is (ViewColor!V == ViewColor!W))
{
	return v.source.equal(w.source);
}