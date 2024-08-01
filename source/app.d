import std.algorithm;
import std.stdio;
import std.file;
import std.conv;
import std.path;
import std.range;
import std.array;
import std.format;
import image, bayer, grad;

struct Params
{
  uint bpow = 3, goff = 1;
  float gcurv = .4, gmult = .95;
  string odir = "output";
  int rsp = -1;
}

struct Lump
{
  string name;
  string spnn;
  bool   sprite;
}

void main(string[] args)
{
  writeln("A tool to reflect doom textures with fade to transparent using dithering");
  writeln("Wall textures will be replaced with its reflections");
  writeln("Sprites reflections will be added to original images\n");

  Params params = Params.init;

  if (args.length < 3 || args[1] == "--help" || args[1] == "-h")
  {
    writeln("Usage: cbl_tex_reflect.exe [sprites-folder] [textures-folder] [flags]\n");
    writeln("(for empty folder use symbol \"-\")\n");
    writeln("Flags:");
    writefln("-bpow=[uint]   - bayer matrix power (of two)  [%d]", params.bpow);
    writefln("-goff=[uint]   - gradient offset row          [%d]", params.goff);
    writefln("-gcurv=[float] - gradient curvature           [%f]", params.gcurv);
    writefln("-gmult=[float] - gradient multiplier          [%f]", params.gmult);
    writefln("-o=[string]    - output directory             [%s]", params.odir);
    writefln("-rsp=[int]     - rename sprites to SP(int)    [%s]", params.rsp);
    writeln();
    return;
  }

  foreach (string flag; args[3..$].join.split(" "))
  {
    auto parts = flag.split("=");
    if (parts.length < 2) continue;

    string str = parts[1];

    switch (parts[0])
    {
      case "-bpow"  : try_parse(str, params.bpow); break;
      case "-goff"  : try_parse(str, params.goff); break;
      case "-gcurv" : try_parse(str, params.gcurv); break;
      case "-gmult" : try_parse(str, params.gmult); break;
      case "-o"     : params.odir = str; break;
      case "-rsp"   : try_parse(str, params.rsp); break;
      default: break;
    }
  }

  auto sprites = dirEntries(args[1], "*.lmp", SpanMode.shallow).array;
  auto textures = dirEntries(args[2], "*.lmp", SpanMode.shallow).array;

  auto abcd_arr = sprites.map!(s => s.baseName.take(4).to!string).array;

  auto abcd_set = abcd_arr.sort.uniq.array;
  
  string[string] abcd_encode;
  foreach (i, abcd; abcd_set)
  {
    abcd_encode[abcd] = params.rsp < 0 ? abcd
      : "SP" ~ format("%02d", params.rsp + i);
  }

  auto encode_name = (string name)
  {
    string abcd = name.baseName.take(4).to!string;
    string spnn = abcd in abcd_encode ? abcd_encode[abcd] : abcd;
    return spnn ~ name.baseName.drop(4).to!string;
  };

  if (params.rsp >= 0)
  {
    writeln("This is how sprites encoded:");
    writeln(abcd_encode);
    writeln();
  }

  Lump[] lumps;
  lumps ~= sprites.map!(x => Lump(x, encode_name(cast(string)x), true)).array;
  lumps ~= textures.map!(x => Lump(x, baseName(cast(string)x), false)).array;

  safe_mkdir(params.odir);
  safe_mkdir(params.odir ~ "\\sprites");
  safe_mkdir(params.odir ~ "\\textures");

  foreach (Lump lump; lumps)
  {
    write(lump.name ~ " ... ");

    auto image = new Image;
    image.read_lump(lump.name);

    Image reversed = image.clone;
    reversed.reverse();

    Grad grad = new GradExp(params.goff, params.gcurv, params.gmult);
    auto bayer = new Bayer(params.bpow);
    reversed.dither(grad, bayer);

    string folder = lump.sprite ? "sprites\\" : "textures\\";
    string outpath = params.odir ~ "\\" ~ folder ~ lump.spnn;

    if (lump.sprite)
    {
      Image merged = image.merge(reversed);
      merged.write_lump(outpath);
    }
    else
    {
      reversed.write_lump(outpath);
    }

    writeln("done!");
  }
}

bool try_parse(T)(string s, out T value)
{
  try
  {
    value = s.to!T;
    return true;
  }
  catch (ConvException e)
  {
    return false;
  }
}

void safe_mkdir(string name)
{
  if (!name.exists)
  {
    name.mkdir();
  }
}

