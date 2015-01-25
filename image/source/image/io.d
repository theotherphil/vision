module image.io;

import std.file;
import std.path;
import std.string;

import ae.utils.graphics.color;
import ae.utils.graphics.image;
import ae.utils.graphics.view;

import imageformats;

Image!RGB readImage(string path)
{
	switch (extension(path).toLower)
	{
		case ".ppm":
			return readPBM(path);
		case ".png":
			return readPNG(path);
		default:
			throw new FileException("Unsupported image format");
	}
}

// .ppm <- rgb
// .pgm <- mono
// .bmp <- L8 or BGR
// .png <- mystery, but library I'm using means Y or RGB

Image!L8 greyscale(V)(V image)
	if (isView!V)
{
	alias C = ViewColor!V;

	static if (is (C == L8))
	{
		return image;
	}
	else if (is (C == RGB) || is (C == BGR))
	{
		return toGreyscale(image);
	}
	else assert(false, "Unsupported color format " ~ C.stringof);
}

Image!L8 toGreyscale(C)(Image!C image)
	if (is(C == RGB) || is (C == BGR))
{
	auto grey = Image!L8(image.w, image.h);
	return image.colorMap!mono.copy(grey);
}

L8 mono(C)(C color)
	if (is (C == RGB) || is (C == BGR))
{
	return L8(cast(ubyte)((0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b)));
}

//void main() {
//	// optional last argument defines conversion
//	IFImage im = read_image("peruna.png");
//	IFImage im2 = read_image("peruna.png", ColFmt.YA);
//	IFImage im3 = read_image("peruna.png", ColFmt.RGB);
//	
//	write_image("peruna.tga", im.w, im.h, im.pixels);
//	write_image("peruna.tga", im.w, im.h, im.pixels, ColFmt.RGBA);
//	
//	// get basic info without decoding
//	long w, h, chans;
//	read_image_info("peruna.png", w, h, chans);
//	
//	// there are also format specific functions
//	PNG_Header hdr = read_png_header("peruna.png"); // get detailed info
//	IFImage im4 = read_jpeg("porkkana.jpg");
//	write_tga("porkkana.tga", im4.w, im4.h, im4.pixels);
//}


Image!RGB readPBM(string path)
{
	ubyte[] bytes = cast(ubyte[])read(path);
	return bytes.parsePBM!RGB;
}

Image!BGR readBMP(string path)
{
	ubyte[] bytes = cast(ubyte[])read(path);
	return bytes.parseBMP!BGR;
}

Image!RGB readPNG(string path)
{
	IFImage im = read_image(path, ColFmt.RGB);
	auto image = Image!RGB(cast(int)im.w, cast(int)im.h);
	for (int y = 0; y < im.h; ++y)
	{
		for (int x = 0; x < im.w; ++x)
		{
			image[x, y] = pix(im, x, y);
		}
	}
	return image;
}

RGB pix(IFImage img, long x, long y)
{
	return RGB(img.at(x, y, 0), img.at(x, y, 1), img.at(x, y, 2));
}

ubyte at(IFImage img, long x, long y, int c)
{
	assert(img.c == ColFmt.RGB);
	return img.pixels[y * 3 * img.w + 3 * x + c];
}

void writePBM(V)(V view, string path)
	if (isView!V)
{
	view.toPBM.toFile(path);
}

void writePNG(V)(V view, string path)
{
	view.toPNG.toFile(path);
}

void toFile(ubyte[] data, string fileName)
{
	std.file.write(fileName, data);
}