// Written in the D programming language.
/*
NYSL Version 0.9982

A. This software is "Everyone'sWare". It means:
  Anybody who has this software can use it as if he/she is
  the author.

  A-1. Freeware. No fee is required.
  A-2. You can freely redistribute this software.
  A-3. You can freely modify this software. And the source
      may be used in any software with no limitation.
  A-4. When you release a modified version to public, you
      must publish it with your name.

B. The author is not responsible for any kind of damages or loss
  while using or misusing this software, which is distributed
  "AS IS". No warranty of any kind is expressed or implied.
  You use AT YOUR OWN RISK.

C. Copyrighted to Kazuki KOMATSU

D. Above three clauses are applied both to source and binary
  form of this software.
*/

/**
このモジュールは、標準ライブラリstd.mathの拡張です。
*/
module carbon.math;

import std.math;
import std.traits;
import std.array;
import std.range;
import std.typecons;

import core.bitop;


real toDeg(real rad) pure nothrow @safe
{
    return rad / PI * 180;
}


real toRad(real deg) pure nothrow @safe
{
    return deg / 180 * PI;
}


bool isPowOf2(I)(I n)
if(is(typeof(n && (n & (n-1)) == 0 )))
{
    return n && (n & (n-1)) == 0;
}

unittest{
    assert(!0.isPowOf2);
    assert( 1.isPowOf2);
    assert( 2.isPowOf2);
    assert( 4.isPowOf2);
    assert(!6.isPowOf2);
    assert( 8.isPowOf2);
    assert(!9.isPowOf2);
    assert(!10.isPowOf2);
}


/**
nextが1である場合に、next2Pow(num)はnumより大きく、かつ、最小の2の累乗数を返します。

もし、nextが0であれば、next2Powはnumより小さく、かつ、最大の2の累乗数を返します。
nextがm > 1の場合には、next2Pow(num, m)は、next2Pow(num) << (m - 1)を返します。
*/
size_t nextPowOf2(T)(T num, size_t next = 1)
if(isIntegral!T)
in{
    assert(num >= 1);
}
body{
    static size_t castToSize_t(X)(X value)
    {
      static if(is(X : size_t))
        return value;
      else
        return value.to!size_t();
    }

    return (cast(size_t)1) << (bsr(castToSize_t(num)) + next);
}

///
pure nothrow @safe unittest{
    assert(nextPowOf2(10) == 16);           // デフォルトではnext = 1なので、次の2の累乗数を返す
    assert(nextPowOf2(10, 0) == 8);         // next = 0だと、前の2の累乗数を返す
    assert(nextPowOf2(10, 2) == 32);        // next = 2なので、next2Pow(10) << 1を返す。
}


/// ditto
F nextPowOf2(F)(F num, size_t next = 1)
if(isFloatingPoint!F)
in{
    assert(num >= 1);
}
body{
    int n = void;
    frexp(num, n);
    return (cast(F)2.0) ^^ (n + next - 1);
}

///
pure nothrow @safe unittest{
    assert(nextPowOf2(10.0) == 16.0);
    assert(nextPowOf2(10.0, 0) == 8.0);
    assert(nextPowOf2(10.0, 2) == 32.0);
}


/**
numより小さく、かつ最大の2の累乗を返します。

nextPowOf2(num, 0)に等価です
*/
auto previousPowOf2(T)(T num)
{
    return nextPowOf2(num, 0);
}


T sqrtFloor(T, F)(F x)
if(isFloatingPoint!F)
{
    return cast(T)(sqrt(x));
}


T sqrtCeil(T, F)(F x)
if(isFloatingPoint!F)
{
    return cast(T)(sqrt(x).ceil());
}


T lcm(T)(T x, T y)
{
    return x * (y / gcd(x, y));
}


pure bool isPrime(T)(T src)if(__traits(isIntegral,T)){
    if(src <= 1)return false;
    else if(src < 4)return true;
    else if(!(src&1))return false;
    else if(((src+1)%6) && ((src-1)%6))return false;
    
    T root = cast(T)sqrt(cast(real)src) + 1;
    
    for(T i = 5; i < root; i += 6)
        if(!((src%i) && ((src)%(i+2))))
            return false;

    return true;
}


void primeFactors(T, R)(T n, ref R or)
if(isOutputRange!(R, Tuple!(T, uint)))
{
    alias E = Tuple!(T, uint);

    if(n < 0){
        primeFactors(-n, or);
        return;
    }

    if(n <= 1){
        return;
    }

    import core.bitop;

  static if(is(T == long) || is(T == ulong))
  {
    {
        uint cnt;
        immutable uint lns = n & uint.max;
        if(auto c = bsf(lns))
            cnt = c;
        else if(lns == 0)
            cnt = bsf(cast(uint)(n >> 32)) + 32;

        if(cnt){
            put(or, E(2, cnt));
            n >>= cnt;
        }
    }
  }
  else
  {
    if(auto cnt = bsf(n)){
        put(or, E(2, cnt));
        n >>= cnt;
    }
  }

    if(isPrime(n)){
        put(or, E(n, 1));
        return;
    }

    // Fermat's method
    {
        T x = cast(T)sqrt(cast(real)n),
          y = 0;

        T diff = x^^2 - n;
        {
            T cnt = 3;
            bool sw;
            while(diff != 0){
                if(n % cnt == 0){
                    // p = n / cnt, q = cnt
                    auto p = n / cnt;
                    x = (p + cnt) / 2;
                    y = (p - cnt) / 2;
                    diff = 0;
                    break;
                }
                cnt += 2;

                if(diff < 0){
                    diff += 2*x + 1;
                    ++x;
                }else if(!sw && diff > 2*y+1){
                    auto m = cast(T)ceil(sqrt((cast(real)y)^^2 + diff) - y);
                    diff -= m * (m + 2 * y);
                    y += m;
                }else{
                    sw = true;
                    diff -= 2*y + 1;
                    ++y;
                }
            }
        }

        T p = x + y,
          q = x - y;

        if(p == q){
            auto dlg = (E e){
                e[1] *= 2;
                put(or, e);
            };

            primeFactors(p, dlg);
            return;
        }

        if(isPrime(q)){
            uint c = 1;
            while(p % q == 0){
                p /= q;
                ++c;
            }

            put(or, E(q, c));
        }else{
            {
                auto dlg = (E e){
                    while(p % e[0] == 0){
                        p /= e[0];
                        ++e[1];
                    }

                    put(or, e);
                };

                primeFactors(q, dlg);
            }
        }

        primeFactors(p, or);
    }
}


Tuple!(T, uint)[] primeFactors(T)(T n)
{
    auto app = appender!(typeof(return))();
    primeFactors(n, app);
    return app.data;
}


unittest
{
    foreach(n; 2 .. 100000){
        ulong m = 1;
        foreach(ps; primeFactors(n))
            m *= ps[0] ^^ ps[1];

        assert(m == n);
    }

    foreach(n; 10_000_000L .. 10_001_000L){
        ulong m = 1;
        foreach(ps; primeFactors(n))
            m *= ps[0] ^^ ps[1];

        assert(m == n);
    }
}


void primeFactorsSimple(T, R)(T n, ref R or)
if(isOutputRange!(R, Tuple!(T, uint)))
{
    alias E = Tuple!(T, uint);
    T m = 2;
    while(n != 1){
        if(isPrime(n)){
            put(or, E(n, 1));
            return;
        }

        uint c;
        while(n % m == 0){
            n /= m;
            ++c;
        }

        if(c) put(or, E(m, c));
        ++m;
    }
}


Tuple!(T, uint)[] primeFactorsSimple(T)(T n)
{
    auto app = appender!(typeof(return))();
    primeFactorsSimple(n, app);
    return app.data;
}


unittest
{
    foreach(n; 2 .. 100000){
        ulong m = 1;
        foreach(ps; primeFactorsSimple(n))
            m *= ps[0] ^^ ps[1];

        assert(m == n);
    }

    foreach(n; 10_000_000L .. 10_001_000L){
        ulong m = 1;
        foreach(ps; primeFactorsSimple(n))
            m *= ps[0] ^^ ps[1];

        assert(m == n);
    }
}


struct Imaginary(T)
{
    E im;

    E re() const @property { return 0; }

    Imaginary!(CommonType!(T, U)) opBinary(string op: "+", U)(Imaginary!U rhs) const { return typeof(return)(im + rhs.im); }
}


C complexZero(C)() @property
{
  static if(is(C == creal) || is(C == cdouble) || is(C == cfloat))
  {
    C zero = 0+0i;
    return zero;
  }
  else
    return C(0, 0);
}


/*
struct Integrator(T)
{
    T value;
    size_t count;


    U average(U = T)() @property
    {
        return cast(U)(value) / count;
    }


    Integrator!(typeof(T.init + U.init)) opBinary(string op: "+", U)(U v)
    {
        return typeof(return)(value + v, count+1);
    }


    Integrator!(typeof(T.init + U.init)) opBinary(string op: "-", U)(U v)
    {
        return typeof(return)(value - v, count-1);
    }


    void opBinaryAssign(string op: "+", U)(U v)
    {
        value += v;
        ++count;
    }


    void opBinaryAssign(string op: "-", U)(U v)
    {
        value -= v;
        --count;
    }
}
*/