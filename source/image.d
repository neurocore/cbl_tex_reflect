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
  this() {}

  private this(ushort w, ushort h, short left, short top)
  {
    head.w = w;
    head.h = h;
    head.left = left;
    head.top = top;

    create_arr();
  }

  private void create_arr()
  {
    arr = new int[][](head.w, head.h);
    for (size_t w = 0; w < head.w; w++)
      for (size_t h = 0; h < head.h; h++)
        arr[w][h] = -1;
  }

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

    create_arr();

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

  struct post_t
  {
    ubyte top;
    ubyte len;
    ubyte _unused1;
    ubyte[] data;
    ubyte _unused2;

    ubyte[] to_flat() const
    {
      ubyte[] arr;
      arr ~= top;
      arr ~= len;
      arr ~= 0;
      arr ~= data;
      arr ~= 0;
      return arr;
    }
  }

  struct col_t
  {
    post_t[] posts;

    uint size() const
    {
      uint sz = 0;
      foreach (post; posts)
      {
        sz += 4 + post.len;
      }
      return sz;
    }
  }

  void write_lump(string file) const
  {
    import std.file;
    import std.stdio;

    if (file.exists) remove(file);

    append(file, [head.w, head.h]);
    append(file, [head.top, head.left]); // idk why, but it's working

    // building columns and posts

    col_t[] cols = new col_t[](head.w);

    for (size_t x = 0; x < head.w; x++)
    {
      ubyte topdelta = 0;
      ubyte[] post;

      for (size_t y = 0; y <= head.h; y++)
      {
        int val = y == head.h ? -1 : arr[x][y];

        if (val < 0)
        {
          if (post.length > 0)
          {
            cols[x].posts ~= post_t(topdelta, cast(ubyte)post.length, 0, post, 0);
            post = [];
          }
        }
        else
        {
          if (!post.length)
          {
            topdelta = cast(ubyte)y;
          }
          post ~= cast(ubyte)val;
        }
      }

      cols[x].posts ~= post_t(255, 0, 0, [], 0);
    }

    // calculating offsets

    uint offset = 8 + head.w * 4;
    uint[] offsets = new uint[](head.w);
    for (size_t x = 0; x < head.w; x++)
    {
      offsets[x] = offset;
      offset += cols[x].size;
    }

    // writing all the stuff

    append(file, offsets);

    for (size_t x = 0; x < head.w; x++)
    {
      foreach (post; cols[x].posts)
      {
        append(file, post.to_flat);
      }
    }
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

  Image clone()
  {
    Image image = new Image(head.w, head.h, head.top, head.left);
    for (size_t y = 0; y < head.h; y++)
    {
      for (size_t x = 0; x < head.w; x++)
      {
        image.arr[x][y] = arr[x][y];
      }
    }
    return image;
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

  // top = 0 for sprite means that
  //  all graphics are below baseline

  //      top       | h - top
  // [AAAAAAAAAAAAAA|AAAAAAAAA]      h - original image
  //     upper      | low
  //                |
  //        h - top |   top 
  //      [BBBBBBBBB|BBBBBBBBBBBBBB] h - reversed image
  //            low |     upper
  //                |
  //      top       |   top
  // [AAAAAAAAAAAAAA|AAAAAAAAABBBBB] 2*top - merged image
  //                |
  //                |
  //               baseline

  Image merge(const Image reversed)
  {
    ushort low = cast(ushort)(2 * head.top - head.h);
    Image image = new Image(head.w, cast(ushort)(2 * head.top), head.top, head.left);

    // reversed image on the back

    for (ushort y = 0; y < head.h; y++)
    {
      for (ushort x = 0; x < head.w; x++)
      {
        image.arr[x][y + low] = reversed.arr[x][y];
      }
    }

    // original image on the front

    for (ushort y = 0; y < head.h; y++)
    {
      for (ushort x = 0; x < head.w; x++)
      {
        auto val = this.arr[x][y];
        if (val >= 0) image.arr[x][y] = val;
      }
    }
    return image;
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
