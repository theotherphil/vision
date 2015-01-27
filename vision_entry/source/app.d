
import std.csv;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;

import ae.utils.graphics.color;
import ae.utils.graphics.image;
import ae.utils.graphics.draw;

import imageformats;

import image.contrast;
import image.filter;
import image.io;
import image.viewrange;

import ml.math;
import ml.forest;

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
	//glyph(75, 5, true, 4).toPNG.toFile(outDir ~ "glyphSigned.png");
	//glyph(75, 5, false, 4).toPNG.toFile(outDir ~ "glyphUnsigned.png");
}

// profile classifier generator usage with arrays as outputs
// vs range as ouputs and reusing a single stump allocation
