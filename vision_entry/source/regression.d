module regression;

import std.datetime;
import std.file;
import std.path;

import ae.utils.graphics.image;

import image.io;
import image.filter;

// String identifier of function and args
string identifier(alias f, bool isGrey, T...)(T args)
{
	import std.conv;
	import std.traits;

	auto argStr = "";
	foreach(a; args)
		argStr ~= "_" ~ a.to!string;

	auto format = isGrey ? "grey" : "colour";

	return fullyQualifiedName!f ~ "_" ~ format ~ argStr;
}

version (unittest)
{
	int foo(float y){ return 1; }
}

unittest
{
	auto x = identifier!(foo, false)(1.7f, "aha", 1);
	assert(x == "regression.foo_colour_1.7_aha_1");
}

struct Output
{
	string id;
	string path;
	long milliseconds;
}

struct Tester
{
	this(string truthDir, string outDir, string filename)
	{
		_truthDir = truthDir;
		_outDir = outDir;
		_filename = filename;

		if (!exists(outDir))
			mkdir(outDir);
	}

	/// Applies function to image, saves results, returns
	/// time taken and save path
	Output run(alias f, bool isGrey, T...)(T args)
	{
		auto inPath = buildPath(_truthDir, _filename);

		static if (isGrey)
		{
			auto img = readPNG(inPath).toGreyscale;
		}
		else
		{
			auto img = readPNG(inPath);
		}

		StopWatch stopwatch;
		stopwatch.start();
		auto mod = f(img, args);
		stopwatch.stop();

		auto outName = identifier!(f, isGrey)(args);
		auto outPath = buildPath(_outDir, outName);

		mod.writePNG(outPath);

		return Output(outName, outPath, stopwatch.peek.msecs);
	}

private:

	string _truthDir;
	string _outDir;
	string _filename;
}

static string truthDir = "/Users/philip/dev/data/Test/Truth";
static string outDir = "/Users/philip/dev/data/Test/LastRun";
static string testImage = "House.png";

void runTests()
{
	Output[] outputs;
	auto tester  = Tester(truthDir, outDir, testImage);

	// empty contents of last run dir
	foreach(file; dirEntries(outDir))
		remove(file);

	// PHIL: find the attributes

	outputs ~= tester.run!(hSobel, true)();
	outputs ~= tester.run!(vSobel, true)();
	outputs ~= tester.run!(hSobelAbs, true)();
	outputs ~= tester.run!(vSobelAbs, true)();
	//outputs ~= tester.run!(sobel, true)();

	auto summary = "";
	foreach(o; outputs)
		summary ~= format("%s: %s ms\n", o.id, o.milliseconds);

	import std.stdio;

	write(summary);
	std.file.write(buildPath(outDir, "Summary.txt"), summary);
}

unittest
{
	runTests();
}