import std.stdio;
import std.file;
import image, bayer, grad;

void main(string[] args)
{
	writeln("A tool to reflect doom textures with fade to transparent using dithering");
	writeln("Wall textures will be replaced with its reflections");
	writeln("Sprites reflections will be added to original images\n");

	if (args.length < 2 || args[1] == "--help" || args[1] == "-h")
	{
		writeln("usage: cbl_tex_reflect.exe [folder-with-lumps]\n");
		return;
	}

	const auto lumps_folder = args[1];
	foreach (string name; dirEntries(lumps_folder, "*.lmp", SpanMode.shallow))
	{
		writeln(name);

		auto image = new Image;
		image.read_lump(name);

		if (name == "lumps\\TBLUD0.lmp")
		{
			writeln(image);

			image.reverse();

			Grad grad = new GradExp();
			auto bayer = new Bayer(3);
			image.dither(grad, bayer);

			writeln(image);
		}

		writefln("[%d, %d]", image.width, image.height);
	}
}
