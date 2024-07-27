module bayer;

final class Bayer
{
  this(uint power)
  {
    n = power;
    arr = new uint[][](size, size);

    for (uint x = 0; x < size; x++)
    {
      for (uint y = 0; y < size; y++)
      {
        arr[x][y] = reverse(interleave(x ^ y, y));
      }
    }
  }

  override string toString()
  {
    import std.format;

    string result;

    for (size_t y = 0; y < size; y++)
    {
      for (size_t x = 0; x < size; x++)
      {
        result ~= format("%4d", arr[x][y]) ~ " ";
      }
      result ~= "\n";
    }
    return result ~ "\n";
  } 

  uint size() const { return 1u << n; }

private:
  uint n;
  uint[][] arr;

  // https://stackoverflow.com/questions/39490345/interleave-bits-efficiently

  uint interleave(uint x, uint y)
  {
    static const uint[] B = [0x55555555, 0x33333333, 0x0F0F0F0F, 0x00FF00FF];
    static const uint[] S = [1, 2, 4, 8];

    x = (x | (x << S[3])) & B[3];
    x = (x | (x << S[2])) & B[2];
    x = (x | (x << S[1])) & B[1];
    x = (x | (x << S[0])) & B[0];

    y = (y | (y << S[3])) & B[3];
    y = (y | (y << S[2])) & B[2];
    y = (y | (y << S[1])) & B[1];
    y = (y | (y << S[0])) & B[0];

    return x | (y << 1);
  }

  uint reverse(uint x)
  {
    uint y = 0u;
    for (uint i = 0; i < 2 * n; i++)
    {
      uint bit = (x >> i) & 1u;
      y <<= 1;
      y |= bit;
    }
    return y;
  }
}
