module image;
import std.file;
import grad, bayer;

enum ImageType { Texture, Sprite }

struct ImageHead
{
  ushort w, h;
  short left, top;
}

class Image
{
  bool read_lump(string file)
  {
    ubyte[] data;
    data = cast(ubyte[]) read(file);
    head = *cast(ImageHead*) data.ptr;

    // getting offsets

    uint[] offsets;
    for (size_t i = 0; i < head.w; i++)
    {
      offsets ~= *cast(uint*)(data.ptr + 8 + 4 * i);
    }

    bool correct = 8 + 4 * head.w == offsets[0];
    if (!correct) return false;

    offsets ~= cast(uint)data.length;

    arr = new int[][](head.w, head.h);
    for (size_t w = 0; w < head.w; w++)
      for (size_t h = 0; h < head.h; h++)
        arr[w][h] = -1;

    // extracting posts

    for (size_t w = 0; w < head.w; w++)
    {
      uint index = offsets[w];
      size_t h = 0;

      while (h < head.h)
      {
        h = data[index++];
        if (h == 255) break;

        ubyte length = data[index++];

        index++; // unused

        for (size_t j = 0; j < length; j++)
        {
          if (h >= head.h) break;
          arr[w][h++] = cast(int)data[index++];
        }

        index++; // unused
      }
    }
    return true;
  }

  void write_lump(string file) const
  {

  }

  override string toString()
  {
    string result;
    for (size_t y = 0; y < head.h; y++)
    {
      for (size_t x = 0; x < head.w; x++)
      {
        int val = arr[x][y];
        result ~= val < 0 ? "  " : "[]";
      }
      result ~= "\n";
    }
    return result ~ "\n";
  }

  void reverse()
  {
    import std.algorithm.mutation: swap;

    for (size_t y = 0; y < head.h / 2; y++)
    {
      for (size_t x = 0; x < head.w; x++)
      {
        swap(arr[x][y], arr[x][head.h - y - 1]);
      }
    }
  }

  void dither(Grad decay, Bayer bayer)
  {
    import std.stdio;
    for (ushort y = 0; y < head.h; y++)
    {
      for (ushort x = 0; x < head.w; x++)
      {
        float opacity = decay[y, head.h];
        float desired = bayer[x, y];

        if (opacity < desired) arr[x][y] = -1;
      }
    }
  }

  uint width()  const { return head.w; }
  uint height() const { return head.h; }

  ImageType type() const
  {
    return head.left || head.top ? ImageType.Sprite : ImageType.Texture;
  }

private:
  ImageHead head;
  int[][] arr;
}
