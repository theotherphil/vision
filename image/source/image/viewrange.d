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
	
	ViewColor!V front()
	{
		auto loc = r.front;
		return v[loc[0], loc[1]];
	}
	
	void popFront()
	{
		r.popFront;
	}

	static if (isWritableView!V)
	{
		void put(ViewColor!V pix)
		{
			auto loc = r.front();
			v[loc[0], loc[1]] = pix;
		}
	}

	V v;
	typeof(cartesianProduct(iota(V.init.w), iota(V.init.h))) r;
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