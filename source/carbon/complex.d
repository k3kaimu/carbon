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
module carbon.complex;

import std.traits;
import std.format;


/**

*/
template std_complex_t(F)
{
  static if(is(F == float))
    alias std_complex_t = cfloat;
  else static if(is(F == double))
    alias std_complex_t = cdouble;
  else static if(is(F == real))
    alias std_complex_t = creal;
}


/**

*/
template complexTypeTemplate(C)
{
  static if(is(C : creal))
    alias complexTypeTemplate = std_complex_t;
  else static if(is(C : CPX!F, alias CPX, F))
    alias complexTypeTemplate = CPX;
  else
    static assert(0);
}

///
unittest
{
    import std.complex;

    static assert(__traits(isSame, complexTypeTemplate!(Complex!float), Complex));
    static assert(__traits(isSame, complexTypeTemplate!cfloat, std_complex_t));
}


/**

*/
enum bool isComplex(T) = !isIntegral!T && !isFloatingPoint!T && is(typeof((T t){
    auto r = t.re;
    typeof(r) i = t.im;
}));


/// ditto
enum bool isComplex(T, F) = isComplex!T && is(typeof(T.init.re) == F) && is(typeof(T.init.im) == F);


///
unittest
{
    import std.complex;
    static assert(isComplex!(Complex!float));
    static assert(isComplex!cfloat);
    static assert(!isComplex!float);

    static assert(isComplex!(Complex!float, float));
    static assert(isComplex!(cfloat, float));
    static assert(!isComplex!(float, float));

    static assert(!isComplex!(Complex!double, float));
    static assert(!isComplex!(cdouble, float));
    static assert(!isComplex!(double, float));
}


complex_t!R cpx(R)(R re)
if(!isComplex!R)
{
    return typeof(return)(re, 0);
}


complex_t!(CommonType!(R, I)) cpx(R, I)(R re, I im)
if(!isComplex!R && !isComplex!I)
{
    return typeof(return)(re, im);
}


complex_t!(typeof(C.init.re)) cpx(C)(C c)
if(isComplex!C)
{
    return typeof(return)(c.re, c.im);
}


align(1)
struct complex_t(T)
{
    T re;
    T im;


  pure nothrow @safe @nogc
  {
    this(R)(R r)
    if(!isComplex!R)
    {
        re = r;
        im = 0;
    }


    this(R, I)(R r, I i)
    {
        re = r;
        im = i;
    }


    this(C)(C c)
    if(isComplex!C)
    {
        this.re = c.re;
        this.im = c.im;
    }


    ref complex_t opAssign(C)(C z)
    if(isComplex!C && isAssignable!(T, typeof(C.init.re)))
    {
        re = z.re;
        im = z.im;
        return this;
    }


    ref complex_t opAssign(R : T)(R r)
    {
        re = r;
        im = 0;
        return this;
    }


    bool opEquals(C)(C z) const
    if(isComplex!C && is(typeof((C z){ assert(complex_t.init.re == z.re); })))
    {
        return re == z.re && im == z.im;
    }


    bool opEquals(R)(R r) const
    if(!isComplex!R && is(typeof((R r){ assert(complex_t.init.re == r); })))
    {
        return re == r && im == 0;
    }


    complex_t opUnary(string op : "+")() const
    {
        return this;
    }


    complex_t opUnary(string op : "-")() const
    {
        return complex_t(-re, -im);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinary(string op, C)(C z) const
    if((op == "+" || op == "-") && isComplex!C)
    {
        return mixin(`typeof(return)(re ` ~ op ~ ` z.re, im ` ~ op ~ ` z.im)`);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinaryRight(string op, C)(C z) const
    if((op == "+" || op == "-") && isComplex!C)
    {
        return mixin(`typeof(return)(z.re ` ~ op ~ ` re, z.im ` ~ op ~ ` im)`);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinary(string op, C)(C z) const
    if((op == "*") && isComplex!C)
    {
        return typeof(return)(re*z.re - im*z.im, im*z.re + re*z.im);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinaryRight(string op, C)(C z) const
    if((op == "*") && isComplex!C)
    {
        return typeof(return)(z.re*re - z.im*im, z.im*re + z.re*im);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinary(string op, C)(C z) const
    if((op == "/") && isComplex!C)
    {
        immutable zr2 = z.re^^2 + z.im^^2;
        immutable newRe = (re * z.re + im * z.im) / zr2;
        immutable newIm = (im * z.re - re * z.im) / zr2;
        return typeof(return)(newRe, newIm);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinaryRight(string op, C)(C z) const
    if((op == "/") && isComplex!C)
    {
        immutable zr2 = re^^2 + im^^2;
        immutable newRe = (z.re * re + z.im * im) / zr2;
        immutable newIm = (z.im * re - z.re * im) / zr2;
        return typeof(return)(newRe, newIm);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinary(string op, C)(C z) const
    if((op == "^^") && isComplex!C)
    {
        alias R = typeof(typeof(return).init.re);

        import std.complex;
        auto res = Complex!R(re, im) ^^ Complex!R(z.re, z.im);
        return typeof(return)(res.re, res.im);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` C.init.re`))) opBinaryRight(string op, C)(C z) const
    if((op == "^^") && isComplex!C)
    {
        alias R = typeof(typeof(return).init.re);

        import std.complex;
        auto res = Complex!R(z.re, z.im) ^^ Complex!R(re, im);
        return typeof(return)(res.re, res.im);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` R.init`))) opBinary(string op, R)(R r) const
    if((op == "+" || op == "-") && !isComplex!R)
    {
        return mixin(`typeof(return)(re ` ~ op ~ ` r, im)`);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` R.init`))) opBinary(string op, R)(R r) const
    if((op == "*" || op == "/") && !isComplex!R)
    {
        return mixin(`typeof(return)(re ` ~ op ~ ` r, im ` ~ op ~ ` r)`);
    }


    complex_t!(typeof(mixin(`R.init ` ~ op ~ ` complex_t.re`))) opBinaryRight(string op, R)(R r) const
    if((op == "+" || op == "-" || op == "*") && !isComplex!R)
    {
      static if(op == "-")
        return typeof(return)(r - re, -im);
      else return mixin(`this ` ~ op ~ ` r`);
    }


    complex_t!(typeof(mixin(`R.init ` ~ op ~ ` complex_t.re`))) opBinaryRight(string op, R)(R r) const
    if((op == "/") && !isComplex!R)
    {
        immutable zr2 = re^^2 + im^^2;
        immutable newRe = r * re / zr2;
        immutable newIm = -r * im / zr2;
        return typeof(return)(newRe, newIm);
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` R.init`))) opBinary(string op, R)(R r) const
    if((op == "^^") && !isComplex!R && isFloatingPoint!R)
    {
        import std.math;
        immutable newR = this.abs() ^^ r;
        immutable newA = this.arg() * r;
        return typeof(return)(newR * cos(newA), newR * sin(newA));
    }


    complex_t!(typeof(mixin(`complex_t.re ` ~ op ~ ` R.init`))) opBinary(string op, R)(R r) const
    if((op == "^^") && !isComplex!R && isIntegral!R)
    {
        switch(r)
        {
          case 0:   // 0
            return complex_t.one;

          case 1:   // 0
            return this;

          case 2:   // 1
            return this * this;

          case 3:   // 2
            return this * this * this;

          case 4:   // 2
            immutable pow2 = this * this;
            return pow2 * pow2;

          case 5:   // 2
            immutable pow2 = this * this;
            return pow2 * pow2 * this;

          case 6:   // 3
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow2 * pow4;

          case 7:   // 4
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow2 * pow4 * this;

          case 8:   // 3
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow4 * pow4;

          case 9:   // 4
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow4 * pow4 * this;

          case 10:   // 4
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow4 * pow4 * pow2;

          case 12:   // 4
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            return pow4 * pow4 * pow4;

          case 16:  // 4
            immutable pow2 = this * this;
            immutable pow4 = pow2 * pow2;
            immutable pow8 = pow4 * pow4;
            return pow8 * pow8;

          default:
            //return this ^^ cast(typeof(typeof(return).init.re))r;
            complex_t cpx = this;
            complex_t ret = 1;
            while(r){
                if(r & 1) ret *= cpx;
                cpx *= cpx;
                r >>= 1;
            }

            return ret;
        }
    }


    complex_t!(typeof(mixin(`R.init ` ~ op ~ ` complex_t.re`))) opBinaryRight(string op, R)(R r) const
    if((op == "^^") && !isComplex!R)
    {
        alias Re = typeof(typeof(return).init.re);

        import std.complex;
        auto res = (r ^^ Complex!Re(re, im));
        return typeof(return)(res.re, res.im);
    }


    ref complex_t opOpAssign(string op, X)(X x)
    {
        this = mixin(`this ` ~ op ~ ` x`);
        return this;
    }


    T abs() const @property
    {
        import std.math : hypot;
        return hypot(re, im);
    }


    T sqAbs() const @property
    {
        return re*re + im*im;
    }


    T arg() const @property
    {
        import std.math : atan2;
        return atan2(im, re);
    }


    complex_t conj() const @property
    {
        return complex_t(re, -im);
    }


    complex_t sqrt() const @property
    {
        auto ret = this ^^ 0.5;
        return typeof(return)(ret.re, ret.im);
    }


    static
    complex_t fromPhase(T y)
    {
        import std.math : cos, sin;
        return complex_t(cos(y), sin(y));
    }
  } // pure nothrow @safe @nogc


    void toString(Writer, Char)(scope Writer w, FormatSpec!Char formatSpec) const
    {
        import std.complex;
        Complex!T(re, im).toString(w, formatSpec);
    }


    string toString() const @property
    {
        import std.complex;
        return Complex!T(re, im).toString();
    }


    static immutable complex_t zero = complex_t(0, 0);
    static immutable complex_t one = complex_t(1, 0);
}


// from std.complex.d
@safe pure nothrow unittest
{
    static import std.math;
    assert (cpx(1.0).abs == 1.0);
    assert (cpx(0.0, 1.0).abs == 1.0);
    assert (cpx(1.0L, -2.0L).abs == std.math.sqrt(5.0L));
}


// from std.complex.d
@safe pure nothrow unittest
{
    import std.math;
    assert (cpx(0.0).sqAbs == 0.0);
    assert (cpx(1.0).sqAbs == 1.0);
    assert (cpx(0.0, 1.0).sqAbs == 1.0);
    assert (approxEqual(cpx(1.0L, -2.0L).sqAbs, 5.0L));
    assert (approxEqual(cpx(-3.0L, 1.0L).sqAbs, 10.0L));
    assert (approxEqual(cpx(1.0f,-1.0f).sqAbs, 2.0f));
}


// from std.complex.d
@safe pure nothrow unittest
{
    import std.math;
    assert (cpx(1.0).arg == 0.0);
    assert (cpx(0.0L, 1.0L).arg == PI_2);
    assert (cpx(1.0L, 1.0L).arg == PI_4);
}


// from std.complex.d
@safe pure nothrow unittest
{
    assert (cpx(1.0).conj == cpx(1.0));
    assert (cpx(1.0, 2.0).conj == cpx(1.0, -2.0));
}


@safe pure nothrow unittest
{
    complex_t!float c1;
    c1 = 1;
    assert(c1 == 1);
    c1 = 1i;
    assert(c1 == 1i);
    c1 = 1+1i;
    assert(c1 == 1+1i);
    c1 = 10+10i;
    assert(c1.re == 10);
    assert(c1.im == 10);
}


// from std.complex.d
@safe pure nothrow
unittest
{
    import std.math;
    import std.complex;

    enum EPS = double.epsilon;
    auto c1 = cpx(1.0 + 1.0i);

    // Check unary operations.
    auto c2 = complex_t!double(0.5, 2.0);

    assert (c2 == +c2);

    assert ((-c2).re == -(c2.re));
    assert ((-c2).im == -(c2.im));
    assert (c2 == -(-c2));

    // Check complex-complex operations.
    auto cpc = c1 + c2;
    assert (cpc.re == c1.re + c2.re);
    assert (cpc.im == c1.im + c2.im);

    auto cmc = c1 - c2;
    assert (cmc.re == c1.re - c2.re);
    assert (cmc.im == c1.im - c2.im);

    auto ctc = c1 * c2;
    assert (approxEqual(ctc.abs, c1.abs*c2.abs, EPS));
    assert (approxEqual(ctc.arg, c1.arg+c2.arg, EPS));

    auto cdc = c1 / c2;
    assert (approxEqual(cdc.abs, c1.abs/c2.abs, EPS));
    assert (approxEqual(cdc.arg, c1.arg-c2.arg, EPS));

    auto cec = c1^^c2;
    assert (approxEqual(cec.re, 0.11524131979943839881, EPS));
    assert (approxEqual(cec.im, 0.21870790452746026696, EPS));

    // Check complex-real operations.
    double a = 123.456;

    auto cpr = c1 + a;
    assert (cpr.re == c1.re + a);
    assert (cpr.im == c1.im);

    auto cmr = c1 - a;
    assert (cmr.re == c1.re - a);
    assert (cmr.im == c1.im);

    auto ctr = c1 * a;
    assert (ctr.re == c1.re*a);
    assert (ctr.im == c1.im*a);

    auto cdr = c1 / a;
    assert (approxEqual(cdr.abs, c1.abs/a, EPS));
    assert (approxEqual(cdr.arg, c1.arg, EPS));

    auto cer = c1^^3.0;
    assert (approxEqual(cer.abs, c1.abs^^3, EPS));
    assert (approxEqual(cer.arg, c1.arg*3, EPS));

    auto rpc = a + c1;
    assert (rpc == cpr);

    auto rmc = a - c1;
    assert (rmc.re == a-c1.re);
    assert (rmc.im == -c1.im);

    auto rtc = a * c1;
    assert (rtc == ctr);

    auto rdc = a / c1;
    assert (approxEqual(rdc.abs, a/c1.abs, EPS));
    assert (approxEqual(rdc.arg, -c1.arg, EPS));

    rdc = a / c2;
    assert (approxEqual(rdc.abs, a/c2.abs, EPS));
    assert (approxEqual(rdc.arg, -c2.arg, EPS));

    auto rec1a = 1.0 ^^ c1;
    assert(rec1a.re == 1.0);
    assert(rec1a.im == 0.0);

    auto rec2a = 1.0 ^^ c2;
    assert(rec2a.re == 1.0);
    assert(rec2a.im == 0.0);

    auto rec1b = (-1.0) ^^ c1;
    assert(approxEqual(rec1b.abs, std.math.exp(-PI * c1.im), EPS));
    auto arg1b = rec1b.arg;
    /* The argument _should_ be PI, but floating-point rounding error
     * means that in fact the imaginary part is very slightly negative.
     */
    assert(approxEqual(arg1b, PI, EPS) || approxEqual(arg1b, -PI, EPS));

    auto rec2b = (-1.0) ^^ c2;
    assert(approxEqual(rec2b.abs, std.math.exp(-2 * PI), EPS));
    assert(approxEqual(rec2b.arg, PI_2, EPS));

    auto rec3a = 0.79 ^^ complex(6.8, 5.7);
    auto rec3b = complex(0.79, 0.0) ^^ complex(6.8, 5.7);
    assert(approxEqual(rec3a.re, rec3b.re, EPS));
    assert(approxEqual(rec3a.im, rec3b.im, EPS));

    auto rec4a = (-0.79) ^^ complex(6.8, 5.7);
    auto rec4b = complex(-0.79, 0.0) ^^ complex(6.8, 5.7);
    assert(approxEqual(rec4a.re, rec4b.re, EPS));
    assert(approxEqual(rec4a.im, rec4b.im, EPS));

    auto rer = a ^^ complex(2.0, 0.0);
    auto rcheck = a ^^ 2.0;
    static assert(is(typeof(rcheck) == double));
    assert(feqrel(rer.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer.re, rcheck));
    assert(rer.im == 0.0);

    auto rer2 = (-a) ^^ complex(2.0, 0.0);
    rcheck = (-a) ^^ 2.0;
    assert(feqrel(rer2.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer2.re, rcheck));
    assert(approxEqual(rer2.im, 0.0, EPS));

    auto rer3 = (-a) ^^ complex(-2.0, 0.0);
    rcheck = (-a) ^^ (-2.0);
    assert(feqrel(rer3.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer3.re, rcheck));
    assert(approxEqual(rer3.im, 0.0, EPS));

    auto rer4 = a ^^ complex(-2.0, 0.0);
    rcheck = a ^^ (-2.0);
    assert(feqrel(rer4.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer4.re, rcheck));
    assert(rer4.im == 0.0);

    // Check Complex-int operations.
    foreach (i; 0..20)
    {
        auto cei = c1^^i;
        assert (approxEqual(cei.abs, c1.abs^^i, EPS));
        // Use cos() here to deal with arguments that go outside
        // the (-pi,pi] interval (only an issue for i>3).
        assert (approxEqual(std.math.cos(cei.arg), std.math.cos(c1.arg*i), EPS));
    }

    // Check operations between different complex types.
    auto cf = complex_t!float(1.0, 1.0);
    auto cr = complex_t!real(1.0, 1.0);
    auto c1pcf = c1 + cf;
    auto c1pcr = c1 + cr;
    static assert (is(typeof(c1pcf) == complex_t!double));
    static assert (is(typeof(c1pcr) == complex_t!real));
    assert (c1pcf.re == c1pcr.re);
    assert (c1pcf.im == c1pcr.im);

    auto c1c = c1;
    auto c2c = c2;

    c1c /= c1;
    assert(approxEqual(c1c.re, 1.0, EPS));
    assert(approxEqual(c1c.im, 0.0, EPS));

    c1c = c1;
    c1c /= c2;
    assert(approxEqual(c1c.re, 0.588235, EPS));
    assert(approxEqual(c1c.im, -0.352941, EPS));

    c2c /= c1;
    assert(approxEqual(c2c.re, 1.25, EPS));
    assert(approxEqual(c2c.im, 0.75, EPS));

    c2c = c2;
    c2c /= c2;
    assert(approxEqual(c2c.re, 1.0, EPS));
    assert(approxEqual(c2c.im, 0.0, EPS));
}

// from std.complex.d
@safe pure nothrow unittest
{
    // Initialization
    complex_t!double a = 1;
    assert (a.re == 1 && a.im == 0);
    complex_t!double b = 1.0;
    assert (b.re == 1.0 && b.im == 0);
    complex_t!double c = complex_t!real(1.0, 2);
    assert (c.re == 1.0 && c.im == 2);
}

// from std.complex.d
@safe pure nothrow unittest
{
    // Assignments and comparisons
    complex_t!double z;

    z = 1;
    assert (z == 1);
    assert (z.re == 1.0  &&  z.im == 0.0);

    z = 2.0;
    assert (z == 2.0);
    assert (z.re == 2.0  &&  z.im == 0.0);

    z = 1.0L;
    assert (z == 1.0L);
    assert (z.re == 1.0  &&  z.im == 0.0);

    auto w = complex_t!real(1.0, 1.0);
    z = w;
    assert (z == w);
    assert (z.re == 1.0  &&  z.im == 1.0);

    auto c = complex_t!float(2.0, 2.0);
    z = c;
    assert (z == c);
    assert (z.re == 2.0  &&  z.im == 2.0);
}
