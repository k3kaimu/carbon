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
このモジュールでは、分数型を扱うことが出来ます。
*/
module carbon.rational;

import carbon.traits;

import std.algorithm,
       std.array,
       std.bigint,
       std.format,
       std.functional,
       std.stdio,
       std.traits;

/*
if T is like int, isLikeInt!T is true. Where "like int" type has operators same of int.

Example:
---
static assert(!isLikeInt!(byte));
static assert(!isLikeInt!(short));
static assert(isLikeInt!(int));
static assert(isLikeInt!(long));
static assert(!isLikeInt!(ubyte));
static assert(!isLikeInt!(ushort));
static assert(isLikeInt!(uint));
static assert(isLikeInt!(ulong));

static assert(isLikeInt!(BigInt));
---
*/
private
enum bool isLikeInt(T) = 
is(typeof({
    T a = 1;
    a = 0;
    a = a;

    ++a;
    --a;
    a++;
    a--;
    a = -a;
    a = +a;

    a += a;
    a -= a;
    a *= a;
    a /= a;
    a %= a;
    //a ^^= a;

    a += 1;
    a -= 1;
    a *= 1;
    a /= 1;
    a %= 1;
    a ^^= 1;

    a = a + a;
    a = a - a;
    a = a * a;
    a = a / a;
    a = a % a;
    //a = a ^^ a;

    a = a + 1;
    a = a - 1;
    a = a * 1;
    a = a / 1;
    a = a % 1;
    a = a ^^ 1;

    bool b = a < 0;
    b = a == 0;
}));
unittest{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    static assert(!isLikeInt!(byte));
    static assert(!isLikeInt!(short));
    static assert(isLikeInt!(int));
    static assert(isLikeInt!(long));
    static assert(!isLikeInt!(ubyte));
    static assert(!isLikeInt!(ushort));
    static assert(isLikeInt!(uint));
    static assert(isLikeInt!(ulong));

    static assert(isLikeInt!(BigInt));
}


private
template isLikeBuiltInInt(T)
{
    alias checkCode = 
    unaryFun!((T a){
        T b = 1;
        b = 0;
        b = b;

        ++b;
        --b;
        b++;
        b--;
        b = cast(const)-b;
        b = cast(const)+b;

        b += cast(const)b;
        b -= cast(const)b;
        b *= cast(const)b;
        b /= cast(const)b;
        b %= cast(const)b;
        //b ^^= b;

        b += 1;
        b -= 1;
        b *= 1;
        b /= 1;
        b %= 1;
        b ^^= 1;

        b = cast(const)b + cast(const)b;
        b = cast(const)b - cast(const)b;
        b = cast(const)b * cast(const)b;
        b = cast(const)b / cast(const)b;
        b = cast(const)b % cast(const)b;
        //b = b ^^ b;

        b = cast(const)b + 1;
        b = cast(const)b - 1;
        b = cast(const)b * 1;
        b = cast(const)b / 1;
        b = cast(const)b % 1;
        b = cast(const)b ^^ 1;

        bool c = cast(const)b < 0;
        c = cast(const)b == 0;
    });


    enum isLikeBuiltInInt = FuncAttr.isPure!(() => checkCode(T.init))
                         && FuncAttr.isNothrow!(() => checkCode(T.init))
                         && isSafe!(() => checkCode(T.init));
}
unittest{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    static assert(isLikeBuiltInInt!int);
    static assert(isLikeBuiltInInt!long);
}


private
auto gcd(T, U)(T a, U b)
if(is(typeof(a + b)))
{
    alias C = Unqual!(typeof(a + b));

    C _a = a < 0 ? a * -1 : a,
      _b = b < 0 ? b * -1 : b;

    while(_a != 0 && _b != 0){
        if(_a > _b)
            _a %= _b;
        else
            _b %= _a;
    }

    if(_a == 0)
        return _b;
    else
        return _a;
}


private
auto lcm(T, U)(T a, U b)
{
    return a / gcd(a, b) * b;
}


/**
This is the type that you can calculate fraction.
$(B Rational!T) has two integral $(B T) values.

Example:
---
auto r = rational(10, 2);       // If you called rational(n, d), value is reduced.
assert(r.num == 5);             // 10 / 2 => 5 / 1
assert(r.den == 1);

assert(r == rational(5));       // rational(5) == rational(5, 1)

assert(r == 5.over(1));          // UFCS : n.over(d) == n.rational(d) == rational(n, d)

r *= -1.over(5);
assert(r.num == -1);            // If rational value is negative, numerator is always negative.
assert(r.den == 1);             // But denominator is always positive.
assert(r == rational(1, 1));    // (5 / 1) * (1 / 5) == (1 / 1)
assert(r == 1);                 // Can check equality to T by "==" operator.
assert(r > 2);                  // Also comparison operator.

r1 = 2.over(5) + 3;              // You can use Rational!T like T.

import std.bigint;
Rational!BigInt rb = 10.over(33);// You can use BigInt as T.
rb ^^= -10;
assert(rb == Rational!BigInt(BigInt(33)^^10, BigInt(10)^^10));
---

If $(B T) can be operated in $(B pure nothrow @safe function),
$(B Rational!T) can be too.

Example:
-------------------------------------------------------
void foo() pure nothrow @safe
{
    auto r = rational(1, 3);    //int is pure nothrow @safe type
    r += 3.over(4);
    ...
}
-------------------------------------------------------

You can use $(B "%(...%)") format when formatted write.
Where inner format $(B "...") can be $(B T)'s format, first one is numerator's format, second is denominator's format.

Example:
---
import std.format;

void main(){
    auto writer = appender!string;

    formattedWrite(writer, "%(%04d / %04d%)", rational(10, 33));
    assert(writer.data == "0010 / 0033");

    writer = appender!string;
    formattedWrite(writer, "%(den : %2$s , num : %1$s%)", rational(10, 33));
    assert(writer.data == "den : 33 , num : 10");

    writer = appender!string;
    formattedWrite(writer, "%04d", rational(10, 30));
    assert(writer.data == "0010/0030");
}
---
*/
struct Rational(T)
if(isLikeInt!T && !isFloatingPoint!T)
{
  private:
    T _num = 0;         //分子
    T _den = 1;         //分母


    debug(rational)
    {
        const invariant()
        {
            assert(_den != 0);
        }
    }


    void reduce()
    {
        if(_num == 0){
            if(_den < 0)
                _den = -1;
            else
                _den = 1;
        }else{
            auto _gcd = gcd(_num, _den);
            _num /= _gcd;
            _den /= _gcd;
        }

        if(_den < 0){
            _num = -_num;
            _den = -_den;
        }
    }

    
  public:
  version(none)
  {
    static typeof(this) init() @property
    {
        static if(is(typeof({typeof(this) r = typeof(this)(0, 1);})))
            typeof(this) r = typeof(this)(0, 1);
        else{
            typeof(this) r;
            ++r._den;
        }
        return r;
    }
  }


    ///ditto
    this(U)(in U n)
    {
        _num = n;
        _den = 1;
    }


    ///ditto
    this(U, V)(in U n, in V d, bool nonReduce = false)
    if(isAssignable!(T, const(U)) && isAssignable!(T, const(V)))
    {
        _num = n;
        _den = d;

        if(!nonReduce) reduce();
    }


    /// numerator
    @property
    inout(T) num() inout
    {
        return _num;
    }


    /// ditto
    @property
    void num(U)(in U u)
    if(isAssignable!(T, const(U)))
    {
        _num =  u;
        reduce();
    }


    /// denominator
    @property
    inout(T) den() inout
    {
        return _den;
    }


    /// ditto
    @property
    void den(U)(in U u)
    if(isAssignable!(T, const(U)))
    in{
        assert(u != 0);
    }
    do{
        _den = u;
        reduce();
    }


    /// return reciprocal number
    @property
    typeof(this) reciprocal() const
    {
        return _num < 0 ? typeof(this)(-_den, -_num, false) : typeof(this)(_den , _num, false);
    }


    /// operator
    void opAssign(U)(in U v)
    if(!isRationalType!U && isAssignable!(T, U))
    {
        _den = 1;
        _num = v;
    }


    /// ditto
    void opAssign(U)(in Rational!U r)
    if(isAssignable!(T, U))
    {
        _den = r._den;
        _num = r._num;
    }


    /// ditto
    typeof(this) opUnary(string op)() const
    if(!find(["-", "+"], op).empty)
    {
        static if(op == "-")
            return rational(-_num, _den);
        else static if(op == "+")
            return rational(_num, _den);
    }


    /// ditto
    typeof(this) opUnary(string op)()
    if(!find(["++", "--"], op).empty)
    {
        static if(op == "++")
            _num += _den;
        else static if(op == "--")
            _num -= _den;

        return this;
    }


    ///ditto
    bool opCast(U : bool)() const
    {
        return _num != 0;
    }


    ///ditto
    U opCast(U : T)() const
    {
        return _num / _den;
    }


    /// ditto
    U opCast(U)() const
    if(isRationalType!U && is(typeof({auto e = U(_num, _den, true);})))
    {
        return U(_num, _den, true);
    }


    /// ditto
    U opCast(U)() const
    if(isRationalType!U && !is(typeof({auto e = U(_num, _den);})) && is(typeof({auto e = cast(typeof(U.init._num))_num;})))
    {
        alias E = typeof(U.init._num);
        return U(cast(E)_num, cast(E)_den, true);
    }


    /// ditto
    auto opBinary(string op, U)(in Rational!U r) const
    if(!find(["+", "-", "*", "/", "%"], op).empty)
    {
       static if(op == "+"){
            auto gcd1 = gcd(_den, r._den);
            return rational(_num * (r._den / gcd1) + r._num * (_den / gcd1), _den / gcd1 * r._den);
        }
        else static if(op == "-"){
            auto gcd1 = gcd(_den, r._den);
            return rational(_num * (r._den / gcd1) - r._num * (_den / gcd1), _den / gcd1 * r._den);
        }
        else static if(op == "*"){
            auto gcd1 = gcd(_num, r._den);
            auto gcd2 = gcd(r._num, _den);
            return rational((_num/gcd1) * (r._num / gcd2), (_den/gcd2) * (r._den / gcd1), true);
        }
        else static if(op == "/"){
            auto gcd1 = gcd(_num, r._num);
            auto gcd2 = gcd(r._den, _den);
            if(r._num < 0)
                gcd1 = -gcd1;
            return rational((_num/gcd1) * (r._den / gcd2), (_den/gcd2) * (r._num / gcd1), true);
        }
        else static if(op == "%"){
            auto gcd1 = gcd(_den, r._den);
            return rational((_num * (r._den / gcd1)) % (r._num * (_den / gcd1)), _den / gcd1 * r._den);
        }
    }


    /// ditto
    auto opBinary(string op, U)(in U v) const
    if(!isRationalType!U && isLikeInt!U && !find(["+", "-", "*", "/", "%", "^^"], op).empty)
    {
        static if(op == "+")
            return rational(_num + _den * v, _den);
        else static if(op == "-")
            return rational(_num - _den * v, _den);
        else static if(op == "*")
            return rational(_num * v, _den);
        else static if(op == "/")
            return rational(_num, _den * v);
        else static if(op == "%")
            return rational(_num % (v * _den), _den);
        else static if(op == "^^"){
            if(v >= 0)
                return rational(_num ^^ v, _den ^^ v);
            else{
                if(_num >= 0)
                    return rational(_den ^^ (-v), _num ^^ (-v));
                else
                    return rational((-_den) ^^ (-v), (-_num) ^^ (-v));
            }
        }else
            static assert(0);
    }


    /// ditto
    auto opBinaryRight(string op, U)(in U v) const
    if(!isRationalType!U && isLikeInt!U && !find(["+", "-", "*", "/", "%"], op).empty)
    {
        static if(op == "+")
            return rational(_num + _den * v, _den);
        else static if(op == "-")
            return rational(_den * v - num, _den);
        else static if(op == "*")
            return rational(_num * v, _den);
        else static if(op == "/")
            return rational(v * _den, _num);
        else static if(op == "%")
            return rational((v * _den) % _num, _den);
    }


    /// ditto
    void opOpAssign(string op, U)(in Rational!U r)
    if(!find(["+", "-", "*", "/", "%"], op).empty)
    in{
        static if(op == "/")
            assert(r._num != 0);
    }
    do{
        static if(op == "+"){
            auto gcd1 = gcd(_den, r._den);
            _num = _num * (r._den / gcd1) + r._num * (_den / gcd1);
            _den = _den / gcd1 * r._den;
            reduce();
        }
        else static if(op == "-"){
            auto gcd1 = gcd(_den, r._den);
            _num = _num * (r._den / gcd1) - r._num * (_den / gcd1);
            _den = _den / gcd1 * r._den;
            reduce();
        }
        else static if(op == "*"){
            auto gcd1 = gcd(_num, r._den);
            auto gcd2 = gcd(r._num, _den);
            _num = (_num / gcd1) * (r._num / gcd2);
            _den = (_den / gcd2) * (r._den / gcd1);
        }
        else static if(op == "/"){
            auto gcd1 = gcd(_num, r._num);
            auto gcd2 = gcd(r._den, _den);

            if(r._num >= 0){
                _num = (_num / gcd1) * (r._den / gcd2);
                _den = (_den / gcd2) * (r._num / gcd1);
            }else{
                _num = -(_num / gcd1) * (r._den / gcd2);
                _den = -(_den / gcd2) * (r._num / gcd1);
            }
        }
        else static if(op == "%"){
            auto gcd1 = gcd(_den, r._den);
            _num = (_num * (r._den / gcd1)) % (r._num * (_den / gcd1));
            _den = _den / gcd1 * r._den;
            reduce();
        }
    }


    /// ditto
    void opOpAssign(string op, U)(const U v)
    if(!isRationalType!U && isLikeInt!U && !find(["+", "-", "*", "/", "%", "^^"], op).empty)
    in{
        static if(op == "^^")
            assert(!(v < 0 && _num == 0));
    }
    do{
        static if(op == "+"){
            _num += _den * v;
        }else static if(op == "-"){
            _num -= _den * v;
        }else static if(op == "*"){
            _num *= v;
            reduce();
        }else static if(op == "/"){
            _den *= v;
            reduce();
        }else static if(op == "%"){
            _num %= _den * v;
            reduce();
        }else static if(op == "^^"){
            if(v >= 0){
                _num ^^= v;
                _den ^^= v;
            }else{
                if(_num >= 0){
                    auto tmp = _num;
                    _num = _den ^^ (-v);
                    _den = tmp ^^ (-v);
                }else{
                    auto tmp = -_num;
                    _num = (-_den) ^^ (-v);
                    _den = (tmp) ^^ (-v);
                }
            }
        }
    }


    /// ditto
    auto opCmp(U)(auto ref const U r) const
    if(!isRationalType!U)
    {
        return _num - r * _den;
    }


    /// ditto
    auto opCmp(U)(auto ref const Rational!U r) const
    {
        auto _gcd = gcd(_den, r._den);
        return (_num * (r._den / _gcd)) - (r._num * (_den / _gcd));
    }


    /// ditto
    bool opEquals(U)(auto ref const U v) const
    if(!isRationalType!U)
    {
        return _den == 1 && _num == v;
    }


    /// ditto
    bool opEquals(U)(auto ref const Rational!U r) const
    {
        return (_num == r._num) && (_den == r._den);
    }


    /// ditto
    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
        if(fmt.nested.length != 0){
            formattedWrite(sink, fmt.nested, _num, _den);
        }else{
            formatValue(sink, _num, fmt);
            sink("/");
            formatValue(sink, _den, fmt);
        }
    }
}


///ditto
Rational!(Unqual!(CommonType!(T, U))) rational(T, U)(T num, U den) pure nothrow @safe if(isLikeBuiltInInt!(Unqual!(CommonType!(T, U))))
{
    return Rational!(Unqual!(CommonType!(T, U)))(num, den, false);
}


///ditto
Rational!(Unqual!(CommonType!(T, U))) rational(T, U)(T num, U den) if(!isLikeBuiltInInt!(Unqual!(CommonType!(T, U))))
{
    return Rational!(Unqual!(CommonType!(T, U)))(num, den, false);
}


///ditto
Rational!(Unqual!T) rational(T)(T num) pure nothrow @safe if(isLikeBuiltInInt!(Unqual!T))
{
    return Rational!(Unqual!T)(num, 1);
}


///ditto
Rational!(Unqual!T) rational(T)(T num) if(!isLikeBuiltInInt!(Unqual!T))
{
    return Rational!(Unqual!T)(num, 1);
}


private
Rational!(Unqual!(CommonType!(T, U))) rational(T, U)(T num, U den, bool nonReduce) pure nothrow @safe if(isLikeBuiltInInt!(Unqual!(CommonType!(T, U))))
{
    return Rational!(Unqual!(CommonType!(T, U)))(num, den, nonReduce);
}


private
Rational!(Unqual!(CommonType!(T, U))) rational(T, U)(T num, U den, bool nonReduce) if(!isLikeBuiltInInt!(Unqual!(CommonType!(T, U))))
{
    return Rational!(Unqual!(CommonType!(T, U)))(num, den, nonReduce);
}


///ditto
alias over = rational;


///
unittest{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    import std.stdio;

    static void foo(T)()
    {
        alias Rational!T R;
        alias R r;

        assert(R.init == r(0, 1));
        assert(R.init.den != 0);

        assert(r(0, -3) == r(0, 1));

      static if(isIntegral!T)   // int, long
        static assert(r(2, 15) == r(4, 5) % r(1, 6));   //CTFEable

        assert(3.over(2) == r(3, 2));    //num.over(den)

        //opUnary and cast test
        assert(-r(5) == r(-5, 1));
        assert(+r(5) == r(5));
        assert(++r(5, 13) == r(18, 13));
        assert(--r(5, 13) == r(-8, 13));
        assert(!r(0));
        assert(r(1));
        assert(cast(T)r(10, 3) == r(10, 3).num / r(10, 3).den);

        //opBinary test
        assert(r(5, 6) + r(3, 8) == r(29, 24));
        assert(r(-1, 3) + r(3, 2) == r(7, 6));
        assert(r(1, 3) - r(4, 5) == r(-7, 15));
        assert(r(-1, 3) - r(-4, 5) == r(7, 15));
        assert(r(5, 6) * r(3, 8) == r(5, 16));
        assert(r(-1, 3) * r(3, 2) == r(-1, 2));
        assert(r(1, 3) / r(4, 5) == r(5, 12));
        assert(r(-1, 3) / r(-4, 5) == r(5, 12));
        assert(r(1, 3) % r(4, 5) == r(5, 15));
        assert(r(-1, 3) % r(-4, 5) == r(-5, 15));

        assert(r(5, 6) + 3 == r(23, 6));
        assert(r(-1, 3) + 3 == r(8, 3));
        assert(r(1, 3) - 3 == r(-8, 3));
        assert(r(-1, 3) - 3 == r(-10, 3));
        assert(r(5, 6) * 3 == r(5, 2));
        assert(r(-1, 3) * 3 == r(-1, 1));
        assert(r(1, 3) / 3 == r(1, 9));
        assert(r(-1, 3) / 3 == r(-1, 9));
        assert(r(1, 3) % 3 == r(1, 3));
        assert(r(-1, 3) % 3 == r(-1, 3));
        assert(r(2, 3) ^^ 3 == r(8, 27));
        assert(r(2, 3) ^^ 4 == r(16, 81));
        assert(r(-2, 3) ^^ 3 == -r(8, 27));
        assert(r(-2, 3) ^^ 4 == r(16, 81));
        assert(r(2, 3) ^^ -3 == r(27, 8));
        assert(r(2, 3) ^^ -4 == r(81, 16));
        assert(r(-2, 3) ^^ -3 == -r(27, 8));
        assert(r(-2, 3) ^^ -4 == r(81, 16));
        assert(r(-1, 3) ^^ -3 == r(-27, 1));

        assert(3 + r(5, 6) == r(23, 6));
        assert(3 + r(-1, 3) == r(8, 3));
        assert(3 - r(1, 3) == r(8, 3));
        assert(3 - r(-1, 3) == r(10, 3));
        assert(3 * r(5, 6) == r(5, 2));
        assert(3 * r(-1, 3) == r(-1, 1));
        assert(3 / r(1, 3) == r(9, 1));
        assert(3 / r(-1, 3) == r(-9, 1));
        assert(3 % r(2, 3) == r(1, 3));
        assert(3 % r(-2, 3) == r(1, 3));

        {
            R r1 = 3;
            assert(r1 == r(3, 1));
        }

        auto r1 = r(5, 6);
        r1 += r(3, 8);
        assert(r1 == r(29, 24));
        r1 += r(3, 2);
        assert(r1 == r(65, 24));

        r1 = r(1, 3);
        r1 -= r(4, 5);
        assert(r1 == r(-7, 15));
        r1 -= r(-4, 5);
        assert(r1 == r(1, 3));

        r1 = r(5, 6);
        r1 *= r(3, 8);
        assert(r1 == r(5, 16));
        r1 *= r(3, 2);
        assert(r1 == r(15, 32));

        r1 = r(1, 3);
        r1 /= r(4, 5);
        assert(r1 == r(5, 12));
        r1 /= r(-4, 5);
        assert(r1 == r(-25, 48));

        r1 = r(4, 3);       //r(20, 15)
        r1 %= r(4, 5);      //r(12, 15)
        assert(r1 == r(8, 15));
        r1 %= r(-2, 5);     //r(-6, 15)
        assert(r1 == r(2, 15));

        
        r1 = r(-5, 6);
        r1 += 3;
        assert(r1 == r(13, 6));
        r1 += -3;
        assert(r1 == r(-5, 6));

        r1 = r(-1, 3);
        r1 -= 3;
        assert(r1 == r(-10, 3));
        r1 -= -3;
        assert(r1 == r(-1, 3));

        r1 = r(-5, 6);
        r1 *= 3;
        assert(r1 == r(-5, 2));
        r1 *= -3;
        assert(r1 == r(15, 2));

        r1 = r(-1, 3);
        r1 /= 4;
        assert(r1 == r(-1, 12));
        r1 /= -4;
        assert(r1 == r(1, 48));

        r1 = r(17, 2);      //r(51, 6)
        r1 %= 3;            //r(18, 6)
        assert(r1 == r(5, 2)); //r(25, 10)
        r1 = r(-25, 10);    //r(-25, 10)
        r1 %= r(2, 5);      //r(6, 10)
        assert(r1 == r(-1, 10));

        r1 = r(2, 3);
        r1 ^^= 3;
        assert(r1 == r(8, 27));

        r1 = r(2, 3);
        r1 ^^= 4;
        assert(r1 == r(16, 81));

        r1 = -r(2, 3);
        r1 ^^= 3;
        assert(r1 == -r(8, 27));

        r1 = -r(2, 3);
        r1 ^^= 4;
        assert(r1 == r(16, 81));

        r1 = r(2, 3);
        r1 ^^= -3;
        assert(r1 == r(27, 8));

        r1 = r(2, 3);
        r1 ^^= -4;
        assert(r1 == r(81, 16));

        r1 = -r(2, 3);
        r1 ^^= -3;
        assert(r1 == -r(27, 8));

        r1 = -r(2, 3);
        r1 ^^= -4;
        assert(r1 == r(81, 16));

        r1 = r(-1, 3);
        r1 ^^= 3;
        assert(r1 == r(-1, 27));
        r1 ^^= -2;
        assert(r1 == r(729, 1));

        assert(r1 == 729);
        assert(r1 < 799);
        assert(r1 < r(700*8, 3));
        assert(r1 > r(700*2, 3));
        assert(r1 == r(729, 1));
        assert(r1.reciprocal == r(1, 729));
    }

    foo!int();
    foo!long();
    foo!BigInt();

    // CTFE test
    static assert(is(typeof({
        enum bar = {
            foo!int();
            return true;
        }();
    })));

    static assert(is(typeof({
        enum bar = {
            foo!long();
            return true;
        }();
    })));

    // pure nothrow @safe test
    static assert(FuncAttr.isPure!(foo!int)
               && FuncAttr.isNothrow!(foo!int)
               && std.traits.isSafe!(foo!int));

    static assert(FuncAttr.isPure!(foo!long)
               && FuncAttr.isNothrow!(foo!long)
               && std.traits.isSafe!(foo!long));

    auto r1 = rational(729, 1);

    auto writer = appender!string;
    formattedWrite(writer, "%(%08d / %04d%)", r1);
    assert(writer.data == "00000729 / 0001");

    writer = appender!string;
    formattedWrite(writer, "%(%2$s/%1$s%)", r1);
    assert(writer.data == "1/729");

    writer = appender!string;
    formattedWrite(writer, "%08d", r1);
    assert(writer.data == "00000729/00000001");


    // like literal
    assert(-1.over(5) == rational(-1, 5));
    assert(-1.rational(5) == rational(-1, 5));
}


/**
true if T is rational
*/
template isRationalType(T){
    static if(is(T U == Rational!U))
        enum bool isRationalType = true;
    else
        enum bool isRationalType = false;
}


unittest
{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    static assert(isRationalType!(Rational!int));
    static assert(isRationalType!(Rational!uint));
    static assert(isRationalType!(Rational!long));
    static assert(isRationalType!(Rational!ulong));
    static assert(isRationalType!(Rational!BigInt));
}
