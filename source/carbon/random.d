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
このモジュールは、標準ライブラリのstd.randomを強化します。
*/

module carbon.random;


import std.random;


// http://www.iro.umontreal.ca/~lecuyer/myftp/papers/lfsr04.pdf
// http://www.iro.umontreal.ca/~lecuyer/myftp/papers/wellrng-errata.txt
private struct WELLConstants_t(UInt)
{
    alias UIntType = UInt;

    uint wordSize, regSize, rotN;

    uint[3] m;

    string[8] ts;

    bool doTempering = false;
    UIntType[2] temperingBC;

    enum UIntType[8] a = 
        [0,
        0xda442d24,
        0xd3e43ffd,
        0x8bdcb91e,
        0x86a9d87e,
        0xa8c296d1,
        0x5d6b45cc,
        0xb729fcec];

    UIntType M(uint n : 0)(UIntType x) const { return 0; }
    UIntType M(uint n : 1)(UIntType x) const { return x; }
    UIntType M(uint n : 2, int t)(UIntType x) const 
    {
      static if(t >= 0)
        return x >> t;
      else
        return x << (-t);
    }

    UIntType M(uint n : 3, int t)(UIntType x) const { return x ^ M!(2, t)(x); }
    UIntType M(uint n : 4, uint a)(UIntType x) const { return (x & 1u) ? ((v >> 1) ^ a) : (v >> 1); }
    UIntType M(uint n : 5, int t, uint b)(UIntType x) const 
    {
        return x ^ (M!(2, t)(x) & b);
    }

    UIntType M(uint n : 6, uint r, uint s, uint t, uint a)(UIntType x) const
    {
        immutable ds = ~(1 << (wordSize - 1 - s)),
                  dt =  (1 << (wordSize - 1 - t)),
                  rot = (x << r) ^ (x >> (wordSize - r));

        if(x & dt)
            return (rot & ds) ^ a;
        else
            return rot & ds;
    }


    static UIntType T(alias thisValue, uint n)(UIntType x)
    if(is(typeof(thisValue) == typeof(this)))
    {
        with(thisValue)
        {
            return mixin("thisValue." ~ thisValue.ts[n] ~ "(x)");
        }
    }
}


private auto _makeStructConstant(S, string expr)()
{
    mixin(`S ret = {` ~ expr ~ `};`);

    return ret;
}


enum WELLConstants_t!UIntType[string]
    WELLConstants(UIntType) =
    ["512a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 16, rotN : 0,
            m : [13, 9, 5],
            ts : [
                "M!(3, -16)", "M!(3, -15)", "M!(3, +11)", "M!(0)",
                "M!(3,  -2)", "M!(3, -18)", "M!(2, -28)", "M!(5, -5, a[1])",
            ]
        }),

    "521a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 17, rotN : 23,
            m : [13, 11, 10],
            ts : [
                "M!(3, -13)", "M!(3, -15)", "M!(1)", "M!(2, -21)",
                "M!(3, -13)", "M!(2, 1)", "M!(0)", "M!(3, 11)"
            ]
        }),

    "521b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 17, rotN : 23,
            m : [11, 10, 7],
            ts : [
                "M!(3, -21)", "M!(3, 6)", "M!(0)", "M!(3, -13)",
                "M!(3, 13)", "M!(2, -10)", "M!(2, -5)", "M!(3, 13)"
            ]
        }),

    "607a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 19, rotN : 1,
            m : [16, 15, 14],
            ts : [
                "M!(3, 19)", "M!(3, 11)", "M!(3, -14)", "M!(1)",
                "M!(3, 18)", "M!(1)", "M!(0)", "M!(3, -15)"
            ]
        }),

    "607b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 25, rotN : 0,
            m : [16, 8, 13],
            ts : [
                "M!(3, -18)", "M!(3, -14)", "M!(0)", "M!(3, 18)",
                "M!(3, -24)", "M!(3, 5)", "M!(3, -1)", "M!(0)"
            ]
        }),

    "800a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 25, rotN : 0,
            m : [14, 18, 17],
            ts : [
                "M!(1)", "M!(3, -15)", "M!(3, 10)", "M!(3, -11)",
                "M!(3, 16)", "M!(2, 20)", "M!(1)", "M!(3, -28)"
            ]
        }),

    "800b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 25, rotN : 0,
            m : [9, 4, 22],
            ts : [
                "M!(3, -29)", "M!(2, -14)", "M!(1)", "M!(2, 19)",
                "M!(1)", "M!(3, 10)", "M!(4, a[2])", "M!(3, -25)"
            ]
        }),

    "1024a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 32, rotN : 0,
            m : [3, 24, 10],
            ts : [
                "M!(1)", "M!(3, 8)", "M!(3, -19)", "M!(3, -14)",
                "M!(3, -11)", "M!(3, -7)", "M!(3, -13)", "M!(0)"
            ]
        }),

    "1024b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 32, rotN : 0,
            m : [22, 25, 26],
            ts : [
                "M!(3, -21)", "M!(3, 17)", "M!(4, a[3])", "M!(3, 15)",
                "M!(3, -14)", "M!(3, -21)", "M!(1)", "M!(0)"
            ]
        }),

    "19937a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 624, rotN : 31,
            m : [70, 179, 449],
            ts : [
                "M!(3, -25)", "M!(3, 27)", "M!(2, 9)", "M!(3, 1)",
                "M!(1)", "M!(3, -9)", "M!(3, -21)", "M!(3, 21)"
            ]
        }),

    "19937b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 624, rotN : 31,
            m : [203, 613, 123],
            ts : [
                "M!(3, 7)", "M!(1)", "M!(3, 12)", "M!(3, -10)",
                "M!(3, -19)", "M!(2, -11)", "M!(3, 4)", "M!(3, 10)"
            ]
        }),

    "19937c" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 624, rotN : 31,
            m : [70, 179, 449],
            ts : [
                "M!(3, -25)", "M!(3, 27)", "M!(2, 9)", "M!(3, 1)",
                "M!(1)", "M!(3, -9)", "M!(3, -21)", "M!(3, 21)"
            ],
            doTempering : true,
            temperingBC : [0xe46e1700U, 0x9b868000U]
        }),

    "21701a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 679, rotN : 27,
            m : [151, 327, 84],
            ts : [
                "M!(1)", "M!(3, -26)", "M!(3, 19)", "M!(0)",
                "M!(3, 27)", "M!(3, -11)", "M!(6, 15, 27, 10, a[4])", "M!(3, -16)"
            ]
        }),

    "23209a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 726, rotN : 23,
            m : [667, 43, 462],
            ts : [
                "M!(3, 28)", "M!(1)", "M!(3, 18)", "M!(3, 3)",
                "M!(3, 21)", "M!(3, -17)", "M!(3, -28)", "M!(3, -1)"
            ]
        }),

    "23209b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 726, rotN : 23,
            m : [610, 175, 662],
            ts : [
                "M!(4, a[5])", "M!(1)", "M!(6, 15, 15, 30, a[6])", "M!(3, -24)",
                "M!(3, -26)", "M!(1)", "M!(0)", "M!(3, 16)"
            ]
        }),

    "44497a" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 1391, rotN : 15,
            m : [23, 481, 229],
            ts : [
                "M!(3, -24)", "M!(3, 30)", "M!(3, -10)", "M!(2, -26)",
                "M!(1)", "M!(3, 20)", "M!(6, 9, 5, 14, a[7])", "M!(1)"
            ]
        }),

    "44497b" : _makeStructConstant!(WELLConstants_t!UIntType, q{
            wordSize : 32, regSize : 1391, rotN : 15,
            m : [23, 481, 229],
            ts : [
                "M!(3, -24)", "M!(3, 30)", "M!(3, -10)", "M!(2, -26)",
                "M!(1)", "M!(3, 20)", "M!(6, 9, 5, 14, a[7])", "M!(1)"
            ],
            doTempering : true,
            temperingBC : [0x93dd1400U, 0xfa118000U]
        })
    ];

/** WELL(512a) Random Number Generator.
    See: http://www.iro.umontreal.ca/~panneton/WELLRNG.html
*/
alias WELLEngine(string name) = WELLEngine!(uint, name);

/// ditto
struct WELLEngine(UIntType, string name)
if(    name == "512a"
    || name == "521a" || name == "521b"
    || name == "607a" || name == "607b"
    || name == "800a" || name == "800b"
    || name == "1024a" || name == "1024b"
    || name == "19937a" || name == "19937b" || name == "19937c"
    || name == "21701a"
    || name == "23209a" || name == "23209b"
    || name == "44497a" || name == "44497b")
{
    enum Constant = WELLConstants!UIntType[name];
    enum size_t _stateSize = Constant.regSize;

  static if(Constant.rotN == 0)
    enum uint MASKU = 0;
  else
    enum uint MASKU = (~0U) >> (Constant.wordSize - Constant.rotN);

    enum uint MASKL = ~MASKU;

  public:
    /// Mark as Random Number Generator
    enum isUniformRandom = true;

    /// maximum value
    enum UIntType max = uint.max;

    /// minimum value
    enum UIntType min = 0;

    /**
    */
    this(uint value)
    {
        seed(value);
    }


    /**
    */
    void seed(uint value)
    {
        _state[0] = value;

        // from std.range.XorshiftEngine.
        foreach(uint i; 1 .. cast(uint)_state.length)
            _state[i] = cast(UIntType)(1812433253UL * (_state[i-1] ^ (_state[i-1] >> (Constant.wordSize - 2))) + i + 1);

        popFront();
    }


    /// range primitives
    void popFront()
    {
        auto V0      = &(_state[_stateIdx]),
             VM1     = &(_state[(_stateIdx + Constant.m[0]) % Constant.regSize]),
             VM2     = &(_state[(_stateIdx + Constant.m[1]) % Constant.regSize]),
             VM3     = &(_state[(_stateIdx + Constant.m[2]) % Constant.regSize]),
             VRm1    = &(_state[(_stateIdx + Constant.regSize - 1) % Constant.regSize]),
             VRm2    = &(_state[(_stateIdx + Constant.regSize - 2) % Constant.regSize]),
             newV0   = VRm1,
             newV1   = V0,
             newVRm1 = VRm2;

        immutable z0    = (*VRm1 & MASKL) | (*VRm2 & MASKU),
                  z1    = Constant.T!(Constant, 0)(*V0) ^ Constant.T!(Constant, 1)(*VM1),
                  z2    = Constant.T!(Constant, 2)(*VM2) ^ Constant.T!(Constant, 3)(*VM3),
                  z3    = z1 ^ z2;

        *newV1 = z3;
        *newV0 = Constant.T!(Constant, 4)(z0) ^ Constant.T!(Constant, 5)(z1)
               ^ Constant.T!(Constant, 6)(z2) ^ Constant.T!(Constant, 7)(z3);

        _stateIdx = (_stateIdx + Constant.regSize - 1) % Constant.regSize;
    }


    /// ditto
    @property uint front() pure nothrow @safe
    {
      static if(Constant.doTempering)
      {
        immutable UIntType x = _state[_stateIdx],
                           y = x ^ ((x << 7) & Constant.temperingBC[0]);

        return y ^ ((y << 15) & Constant.temperingBC[1]);
      }
      else
        return _state[_stateIdx];
    }


    /// ditto
    enum bool empty = false;


    /// ditto
    @property typeof(this) save() pure nothrow @safe
    {
        return this;
    }


  private:
    uint[_stateSize] _state;
    size_t _stateIdx;
}

///
unittest
{
    import std.algorithm;
    import std.range;
    import std.stdio;

    WELLEngine!"512a" rng;

    static assert(isUniformRNG!(typeof(rng)));
    static assert(isSeedable!(typeof(rng)));

    rng.seed(100);

    assert(equal(rng.save.take(8),
      [ 2230636158,
        1842930638,
        155680193,
        1855495099,
        2311897807,
        3102313483,
        3970788677,
        3720522367,]));

    // save test
    auto saved1 = rng.save;
    auto saved2 = rng.save;

    rng.popFrontN(100);
    assert(equal(saved1.save.take(64), saved2.save.take(64)));

    saved1.popFrontN(100);
    assert(equal(rng.save.take(64), saved1.save.take(64)));

    assert(rng.front == 1947823519);
    rng.popFront();
    rng.popFrontN(10000);
    assert(rng.front == 2831551372);
}

unittest
{
    import std.algorithm;
    import std.range;
    import std.stdio;

    WELLEngine!"1024a" rng;
    rng.seed(100);

    static assert(isUniformRNG!(typeof(rng)));
    static assert(isSeedable!(typeof(rng)));

    assert(equal(rng.save.take(8),
      [ 1729689691,
        963076657,
        888412938,
        181100396,
        3310127585,
        3649309487,
        2484075420,
        1423389279,]));

    rng.popFrontN(100);
    assert(rng.front == 725664384);
    rng.popFront();

    rng.popFrontN(10000);
    assert(rng.front == 3953644315);
}

unittest
{
    import std.algorithm;
    import std.range;
    import std.stdio;

    WELLEngine!"19937a" rng;
    rng.seed(100);

    static assert(isUniformRNG!(typeof(rng)));
    static assert(isSeedable!(typeof(rng)));

    assert(equal(rng.save.take(8),
      [ 3859347685,
        3376854944,
        2220854319,
        1533421060,
        3247527917,
        1794400208,
        2014239377,
        1401918048,]));

    rng.popFrontN(100);
    assert(rng.front == 2444980538);
    rng.popFront();

    rng.popFrontN(10000);
    assert(rng.front == 490674394);
}

unittest
{
    import std.algorithm;
    import std.range;
    import std.stdio;

    WELLEngine!"44497a" rng;
    rng.seed(100);

    static assert(isUniformRNG!(typeof(rng)));
    static assert(isSeedable!(typeof(rng)));

    assert(equal(rng.save.take(8),
      [ 1904938054,
        1236099671,
        761528580,
        261553665,
        3145325643,
        603047593,
        3491142409,
        496221207,]));

    rng.popFrontN(100);
    assert(rng.front == 738539296);
    rng.popFront();

    rng.popFrontN(10000);
    assert(rng.front == 2913233053);
}

unittest
{
    import std.algorithm;
    import std.range;
    import std.stdio;

    WELLEngine!"44497b" rng;
    rng.seed(100);

    static assert(isUniformRNG!(typeof(rng)));
    static assert(isSeedable!(typeof(rng)));

    assert(equal(rng.save.take(8),
        [1913523270,
         3946701399,
         3211002116,
         1993047553,
         3283376203,
         3676328617,
         425402121,
         1179532311,]));

    rng.popFrontN(100);
    assert(rng.front == 1015818016);
    rng.popFront();

    rng.popFrontN(10000);
    assert(rng.front == 229698717);
}


auto dist(string name, string boundaries = "[)", T1, T2, Rng)(T1 a, T2 b, ref Rng rng)
if((name == "uni" || name == "uniform") && isUniformRNG!Rng)
{
    return uniform!boundaries(a, b, rng);
}


auto ref dist(string name, R, B, Rng)(R p, auto ref B t, auto ref B f, ref Rng rng)
if((name == "ber" || name == "bernoulli") && is(R : real) && isUniformRNG!Rng)
{
    immutable R r = uniform01!R(rng);
    if(r < p)
        return t;
    else
        return f;
}


R dist(string name, R, Rng)(R lambda, ref Rng rng)
if((name == "exp" || name == "exponential") && is(R : real) && isUniformRNG!Rng)
{
    return -log(uniform01!R(rng)) / lambda;
}


R dist(string name, R, Rng)(ref Rng rng)
if(name == "stdNormal" && is(R : real) && isUniformRNG!Rng)
{
    immutable x = uniform01!R(rng),
              y = uniform01!R(rng);

    return sqrt(-2 * log(x)) * cos(2 * PI * y);
}


R dist(string name, R, Rng)(R mu, R sigma, ref Rng rng)
if(name == "normal" && is(R : real) && isUniformRNG!Rng)
{
    return dist!"stdNormal"(rng) * sigma + mu;
}


//N dist(string name, N, R, Rng)(N n, R p, ref Rng rng)
//if((name == "bin" || name == "binominal") && is(R : real) && is(N : ulong))
//{

//}


template dist(string name, Params...)
{
    auto ref dist(T...)(auto ref T args)
    {
        return dist!(name, Params)(forward!args, std.random.rndGen);
    }
}


///**
//一様分布
//*/
//auto distGenerator(string name, string boundaries = "[)", T1, T2)(T1 a, T2 b)
//{
//    static struct Generator()
//    {
//        alias F = typeof(uniform(T1.init, T2.init, std.random.rndGen));

//        F gen(alias bs = boundaries, T1, T2, Rng)(T1 a, T2 b, ref Rng rng)
//        if(isUniformRNG!Rng)
//        {
//            return uniform!bs(a, b, rng);
//        }


//        F gen(alias bs = boundaries, T1, T2)(T1 a, T2 b)
//        if(isUniformRNG!Rng)
//        {
//            return gen!bs(a, b, std.random.rndGen);
//        }


//        F gen(alias bs = boundaries, Rng)(ref Rng rng)
//        if(isUniformRNG!Rng)
//        {
//            return gen!bs(_a, _b, rng);
//        }


//        F gen(alias bs = boundaries)()
//        if(isUniformRNG!Rng)
//        {
//            return gen!bs(std.random.rndGen);
//        }


//        F opCall(Rng)(ref Rng rng)
//        if(isUniformRNG!Rng)
//        {
//            return uniform!boundaries(_a, _b, rng);
//        }


//        F opCall()
//        {
//            return opCall(std.random.rndGen);
//        }


//      private:
//        T1 _a;
//        T2 _b;
//    }


//    return Generator!()(a, b);
//}


///**
//ベルヌーイ分布
//*/
//auto distGenerator(string name, R, B = bool)(R p, B t = true, B f = false)
//if((name == "ber" || name == "bernoulli") && is(R : real))
//{
//    static struct Generator()
//    {
//        auto ref gen(R, B, Rng)(R p, auto ref B t, auto ref B f, ref Rng rng)
//        if(is(R : real) && isUniformRNG!Rng)
//        {
//            auto r = uniform01!R(rng);
//            return r < p ? forward!t : forward!f;
//        }


//        auto ref gen(R, B, Rng)(R p, auto ref B t, auto ref B f)
//        if(is(R : real))
//        {
//            return gen(p, forward!t, forward!f, std.random.rndGen);
//        }


//        auto ref gen(B, Rng)(auto ref B t, auto ref B f, ref Rng rng)
//        {
//            return gen(_p, forward!t, forward!f, std.random.rndGen);
//        }


//        B gen(R, Rng)(R p, ref Rng rng)
//        {
//            return gen(p, _t, _f, rng);
//        }


//        //B gen(R, Rng)
//    }
//}


//template distRange(string name, TemplateParams...)
//{
//    auto distRange(RefRng, Params...)(RefRng rng, auto ref Params params)
//    {
//        alias D = typeof(distGenerator!(name, TemplateParams)(params));
//        alias F = typeof(D.init(rng));


//        static struct DistRange()
//        {
//            F front() @property
//            {
//                if(_cached)
//                    return _cach;
//                else{
//                    _cach = _dGen(_rng);
//                    _cached = true;
//                    return _cach;
//                }
//            }


//            void popFront()
//            {
//                if(_cached) _cached = false;
//                else{
//                    _rng.popFront;
//                }
//            }


//          static if(isInfinite!RefRng)
//            enum bool empty = false;
//          else
//          {
//            bool empty() @property
//            {
//                return _rng.empty;
//            }
//          }


//          private:
//            RefRng _rng;
//            D _dGen;
//            F _cach;
//            bool _cached;
//        }

//        return DistRange!()(rng, distGenerator!(name, Params)(forward!params), F.init, false);
//    }
//}

//unittest
//{
//    import carbon.nonametype;

//    WELLEngine!"512a" rng;
//    rng.seed(100);

//    auto r = rng.scopedRef!"trusted".distRange!("uni", "[)")(0, 10);
//    static assert(isInputRange!(typeof(r)));
//    foreach(e; r.take(1000))
//        assert(e >= 0 && e < 10);
//}
