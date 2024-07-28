module grad;
import std.math;
import std.algorithm;

abstract class Grad
{
  float opIndex(in uint y, in uint h);
}

class GradExp : Grad
{
  this(uint offset = 1, float curvature = .4, float mult = .95)
  {
    low = offset;
    power = curvature;
    k = mult;
  }

  override float opIndex(in uint y, in uint h)
  {
    if (y <= low) return 1;
    float j = (y - low + .01) / (h - low + .01);
    float val = k * max(0, j);
    return 1 - pow(val, power);
  }

private:
  uint low;
  float power, k;
}
