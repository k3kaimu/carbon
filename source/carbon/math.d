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



enum real eulersGamma = 0.57721566490153286060651L;


real sinc(real x)
{
    if(abs(x) < 1E-2){
        // From pade approximation of sin(x)
        // See also: https://en.wikipedia.org/wiki/Pad%C3%A9_approximant

        immutable real[3] numCoefs = [
            +1.0L,
            -2363 / 18183.0L,
            +12671 / 4363920.0L,
        ];

        immutable real[4] denCoefs = [
            +1.0L,
            +445 / 12122.0L,
            +601 / 872784.0L,
            +121 / 16662240.0L
        ];

        immutable x2 = x^^2;
        return poly(x2, numCoefs) / poly(x2, denCoefs);
    }

    return sin(x)/x;
}


/**
See also: https://en.wikipedia.org/wiki/Trigonometric_integral
*/
real triIntSi(real x)
{
    if(x < 0){
        return triIntSi(-x)*-1;
    }

    if(x <= 4){
        immutable real[8] numCoefs = [
            +1,
            -4.54393409816329991e-2L,
            +1.15457225751016682e-3L,
            -1.41018536821330254e-5L,
            +9.43280809438713025e-8L,
            -3.53201978997168357e-10L,
            +7.08240282274875911e-13L,
            -6.05338212010422477e-16L
        ];

        immutable real[7] denCoefs = [
            +1,
            +1.01162145739225565e-2L,
            +4.99175116169755106e-5L,
            +1.55654986308745614e-7L,
            +3.28067571055789734e-10L,
            +4.5049097575386581e-13L,
            +3.21107051193712168e-16L,
        ];

        immutable real x2 = x^^2;

        return x * (poly(x2, numCoefs) / poly(x2, denCoefs));
    }else{
        // For x > 4,
        immutable fg = fgForTriIntSiCiLargeX(x);

        return PI_2 - fg[0] * cos(x) - fg[1] * sin(x);
    }
}


///
real triIntCi(real x)
{
    if(x < 0){
        return triIntCi(-x);
    }


    if(x <= 4){
        immutable real[7] numCoefs = [
            -0.25L,
            +7.51851524438898291e-3L,
            -1.27528342240267686e-4L,
            +1.05297363846239184e-6L,
            -4.68889508144848019e-9L,
            +1.06480802891189243e-11L,
            -9.93728488857585407e-15L,
        ];

        immutable real[8] denCoefs = [
            +1,
            +1.1592605689110735e-2L,
            +6.72126800814254432e-5L,
            +2.55533277086129636e-7L,
            +6.97071295760958946e-10L,
            +1.38536352772778619e-12L,
            +1.89106054713059759e-15L,
            +1.39759616731376855e-18L,
        ];

        immutable real x2 = x^^2;

        return eulersGamma + log(x) + x2 * (poly(x2, numCoefs) / poly(x2, denCoefs));
    }else{
        // For x > 4:

        immutable fg = fgForTriIntSiCiLargeX(x);
        return fg[0] * sin(x) - fg[1] * cos(x);
    }
}


private
real[2] fgForTriIntSiCiLargeX(real x)
{
    immutable real xm1 = 1/x;
    immutable real xm2 = xm1^^2;

    immutable real[11] numFCoefs = [
        +1,
        +7.44437068161936700618e2L,
        +1.96396372895146869801e5L,
        +2.37750310125431834034e7L,
        +1.43073403821274636888e9L,
        +4.33736238870432522765e10L,
        +6.40533830574022022911e11L,
        +4.20968180571076940208e12L,
        +1.00795182980368574617e13L,
        +4.94816688199951963482e12L,
        -4.94701168645415959931e11L,
    ];

    immutable real[10] denFCoefs = [
        +1,
        +7.46437068161927678031e2L,
        +1.97865247031583951450e5L,
        +2.41535670165126845144e7L,
        +1.47478952192985464958e9L,
        +4.58595115847765779830e10L,
        +7.08501308149515401563e11L,
        +5.06084464593475076774e12L,
        +1.43468549171581016479e13L,
        +1.11535493509914254097e13L
    ];

    immutable real[11] numGCoefs = [
        +1,
        +8.1359520115168615e2L,
        +2.35239181626478200e5L,
        +3.12557570795778731e7L,
        +2.06297595146763354e9L,
        +6.83052205423625007e10L,
        +1.09049528450362786e12L,
        +7.57664583257834349e12L,
        +1.81004487464664575e13L,
        +6.43291613143049485e12L,
        -1.36517137670871689e12L,
    ];

    immutable real[10] denGCoefs = [
        +1,
        +8.19595201151451564e2L,
        +2.40036752835578777e5L,
        +3.26026661647090822e7L,
        +2.23355543278099360e9L,
        +7.87465017341829930e10L,
        +1.39866710696414565e12L,
        +1.17164723371736605e13L,
        +4.01839087307656620e13L,
        +3.99653257887490811e13L,
    ];

    return [
        xm1 * poly(xm2, numFCoefs) / poly(xm2, denFCoefs),
        xm2 * poly(xm2, numGCoefs) / poly(xm2, denGCoefs)
    ];
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