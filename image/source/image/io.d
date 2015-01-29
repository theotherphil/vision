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
	if (!path.endsWith(".ppm"))
	{
		path ~= ".ppm";
	}
	view.toPBM.toFile(path);
}

void writePNG(V)(V view, string path)
{
	if (!path.endsWith(".png"))
	{
		path ~= ".png";
	}
	view.toPNG.toFile(path);
}

void toFile(ubyte[] data, string fileName)
{
	std.file.write(fileName, data);
}