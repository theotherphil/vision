
import std.csv;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;
import ae.utils.graphics.draw;
import ae.utils.graphics.color;
import ae.utils.graphics.gamma;
import ae.utils.graphics.image;
import ae.utils.graphics.view;

import imageformats;

import image.contrast;
import image.filter;
import image.io;
import image.viewrange;

import ml.math;
import ml.forest;

struct RoiRecord
{
	string filename;
	int width;
	int height;
	int x1;
	int y1;
	int x2;
	int y2;
	int classId;

	string toString() const pure @safe
	{
		auto app = appender!string();

		app.put("RoiRecord: ");
		app.put(format("filename: %s, ", filename));
		app.put(format("width: %s, ", width));
		app.put(format("height: %s, ", height));
		app.put(format("x1: %s, ", x1));
		app.put(format("y1: %s, ", y1));
		app.put(format("x2: %s, ", x2));
		app.put(format("y2: %s, ", y2));
		app.put(format("classId: %s", classId));

		return app.data;
	}  
}

RoiRecord[string] readRecords(string csvPath)
{
	RoiRecord[string] records;

	auto header = ["Filename", "Width", "Height", "Roi.X1", "Roi.Y1", "Roi.X2", "Roi.Y2", "ClassId"];
	auto text = std.file.readText(csvPath);

	foreach (record; csvReader!RoiRecord(text, header, ';'))
		records[record.filename] = record;

	return records;
}

void processDir(string dir, string outDir, int maxImages)
{
	auto records = readRecords(dir ~ "GT-final_test.csv");	

	auto images = dirEntries(dir, "*.ppm", SpanMode.shallow).take(maxImages);

	foreach (path; images)
	{
		string name = baseName(path);
		RoiRecord record = records[name];
		auto img = readPBM(path);

		img.writePBM(outDir ~ "original_" ~ name);
		img.rect(record.x1, record.y1, record.x2, record.y2, RGB(0, 0, 255));
		img.writePNG(outDir ~ "bounded_" ~ name ~ ".png");
	}
}

string devDir = "/Users/philip/dev/";
string testImageDir = "/Users/philip/dev/data/GTSRB/Final_Test/Images/";
string outDir = "/Users/philip/dev/temp/";

//RGB colour space with no gamma cor- rection ;
//[−1, 0, 1] gradient filter with no smoothing ; 
//linear gradient voting into 9 orientation bins in 0◦–180◦; 
//16×16 pixel blocks of four 8×8 pixel cells; Gaussian spatial window with σ = 8 pixel;
//L2-Hys (Lowe-style clipped L2 norm) block normalization; block spacing stride of 
//	8 pixels (hence 4-fold coverage of each cell) ; 64×128 detection window ; 
//linear SVM classifier.

void main()
{
	//Image!RGB img = readImage(testImageDir ~ "00000.ppm");
	//auto eq = img.toGreyscale.equaliseHistogram;
	//eq.writePNG(devDir ~ "eq2.png");

	//glyph(75, 5, true, 4).toPNG.toFile(outDir ~ "glyphSigned.png");
	//glyph(75, 5, false, 4).toPNG.toFile(outDir ~ "glyphUnsigned.png");
}

// profile classifier generator usage with arrays as outputs
// vs range as ouputs and reusing a single stump allocation
