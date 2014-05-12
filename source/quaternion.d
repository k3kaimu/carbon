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
このモジュールでは、四元数を扱います。
*/
module carbon.quaternion;

import carbon.linear;

import std.conv,
       std.format,
       std.functional,
       std.math,
       std.traits;


/**
四元数
*/
Quaternion!(CommonType!(A, B, C, D)) quaternion(A, B, C, D)(A a, B b, C c, D d)
if(is(Quaternion!(CommonType!(A, B, C, D))))
{
    typeof(return) dst;

    dst.a = a;
    dst.b = b;
    dst.c = c;
    dst.d = d;

    return dst;
}


/// ditto
Quaternion!A quaternion(A)(A a)
if(is(Quaternion!A))
{
    typeof(return) dst;

    dst.a = a;
    dst.b = 0;
    dst.c = 0;
    dst.d = 0;

    return dst;
}


/// ditto
Quaternion!(ElementType!V) quaternion(V)(V v)
if(isVector!V)
{
    typeof(return) dst;
    dst._vec4 = v;
    return dst;
}


/// ditto
Quaternion!(CommonType!(R, ElementType!V)) quaternion(R, V)(R r, V v)
if(is(Quaternion!(CommonType!(R, ElementType!V))))
{
    typeof(return) dst;

    dst.s = r;
    dst.v = v;

    return dst;
}


/// ditto
Quaternion!E quaternion(E)(E[] arr)
if(is(Quaternion!E))
in{
    assert(arr.length == 4);
}
body{
    typeof(return) dst;
    dst._vec4.array[] = arr[];

    return dst;
}


/// ditto
struct Quaternion(S)
if(isNotVectorOrMatrix!S)
{
    this(E)(in Quaternion!E q)
    if(is(E : S))
    {
        this = q;
    }


    this()(in SCVector!(int, 4) m)
    {
        this._vec4 = m;
    }


    /// 
    ref inout(S) opIndex(size_t i) pure nothrow @safe inout
    in{
        assert(i < 4);
    }
    body{
        return _vec4[i];
    }


    ref inout(S) s() pure nothrow @safe @property inout { return _vec4[0]; }
    ref inout(S) i() pure nothrow @safe @property inout { return _vec4[1]; }
    ref inout(S) j() pure nothrow @safe @property inout { return _vec4[2]; }
    ref inout(S) k() pure nothrow @safe @property inout { return _vec4[3]; }


    alias a = s;
    alias b = i;
    alias c = j;
    alias d = k;

    alias w = a;
    alias x = b;
    alias y = c;
    alias z = d;


    @property
    auto v() pure nothrow @safe inout
    {
        return _vec4.stackRef.swizzle.bcd;
    }


    @property
    void v(V)(in V v)
    {
        foreach(i; 0 .. 3)
            this._vec4[i + 1] = v[i];
    }


    @property
    V asVec4(V = SCVector!(S, 4))() inout
    {
        V v = this._vec4;
        return v;
    }


    auto opUnary(string op : "-", E)(in Quaternion!E q) const
    {
        return typeof(return)(typeof(typeof(return).init._vec4)(this._vec4 * -1));
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "+", E)(in Quaternion!E q) const
    if(!is(CommonType!(S, E) == void))
    {
        return typeof(return)(typeof(typeof(return).init._vec4)(this._vec4 + q._vec4));
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "-", E)(in Quaternion!E q) const
    if(!is(CommonType!(S, E) == void))
    {
        return typeof(return)(typeof(typeof(return).init._vec4)(this._vec4 - q._vec4));
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "*", E)(in Quaternion!E q) const
    if(!is(CommonType!(S, E) == void))
    {
        return quaternion(this.s * q.s - this.v.dot(q.v), (this.s * q.v) + (q.s * this.v) + (this.v.cross(q.v)));
    }


    auto opBinary(string op : "/", E)(in Quaternion!E q) const
    if(isFloatingPoint!(CommonType!(S, E)))
    {
        return this * q.inverse;
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "+", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst.a += s;
        return dst;
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op  : "-", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst.a -= s;
        return dst;
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "*", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst._vec4 *= s;
        return dst;
    }


    Quaternion!(CommonType!(S, E)) opBinary(string op : "/", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst._vec4 /= s;
        return dst;
    }


    Quaternion!(CommonType!(S, E)) opBinaryRight(string op : "+", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst.a += s;
        return dst;
    }


    Quaternion!(CommonType!(S, E)) opBinaryRight(string op : "-", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        return quaternion!(CommonType!(S, E))(s) - this;
    }


    Quaternion!(CommonType!(S, E)) opBinaryRight(string op : "*", E)(in E s) const
    if(!is(CommonType!(S, E) == void))
    {
        typeof(return) dst;
        dst = this;
        dst._vec4 *= s;
        return dst;
    }


    auto opBinaryRight(string op : "/", E)(in E s) const
    if(isFloatingPoint!(CommonType!(S, E)))
    {
        return s / this.sumOfSquare * this.conj;
    }


    void opAssign(E)(in Quaternion!E q)
    if(is(E : S))
    {
        this._vec4 = q._vec4;
    }


    void opAssign(E)(in E s)
    if(is(E : S))
    {
        this._vec4 = 0;
        this.a = s;
    }


    void opOpAssign(string op, E)(in Quaternion!E q)
    if(!is(CommonType!(S, E) == void))
    {
        this = mixin("this " ~ op ~ " q");
    }


    void opOpAssign(string op, E)(in E s)
    if(is(E : S))
    {
        this = mixin("this " ~ op ~ " s");
    }


    void toString(scope void delegate(const(char)[]) sink, string formatString) const
    {
        formattedWrite(sink, formatString, _vec4.array);
    }


    bool opEquals(E)(auto ref const Quaternion!E q) pure nothrow @safe const
    {
        foreach(i; 0 .. 4)
            if(this[i] != q[i])
                return false;
        return true;
    }


  private:
    SCVector!(S, 4) _vec4 = [1, 0, 0, 0].matrix!(4, 1);
}


/// 
unittest {
    assert(Quaternion!int.init == quaternion(1, 0, 0, 0));
    // 1 = [1; (0, 0, 0)]な四元数の作成
    auto q = quaternion(1);

    // 添字によるアクセス
    assert(q[0] == 1);
    assert(q[1] == 0);
    assert(q[2] == 0);
    assert(q[3] == 0);


    // 1 + 2i + 3j + 4k = [1; (2, 3, 4)]な四元数の作成
    q = quaternion(1, 2, 3, 4);
    assert(q[0] == 1);
    assert(q[1] == 2);
    assert(q[2] == 3);
    assert(q[3] == 4);

    // a, b, c, dによるアクセス
    assert(q.a == 1);
    assert(q.b == 2);
    assert(q.c == 3);
    assert(q.d == 4);

    // スカラー部であるs, ベクトル部であるvによるアクセス
    assert(q.s == 1);
    assert(q.v == [2, 3, 4].matrix!(3, 1));

    // v = (i, j, k)
    assert(q.i == 2);
    assert(q.j == 3);
    assert(q.k == 4);

    // opIndexやa, b, c, d, i, j, k, s, vへは代入可能
    q.s = 7;
    assert(q[0] == 7);

    // vはベクトルなので、ベクトルを代入可能
    q.v = [4, 5, 6].matrix!(3, 1);
    assert(q[1] == 4);
    assert(q[2] == 5);
    assert(q[3] == 6);

    // スカラー部とベクトル部による四元数の作成
    q = quaternion(8, [9, 10, 11].matrix!(3, 1));
    assert(q[0] == 8);
    assert(q[1] == 9);
    assert(q[2] == 10);
    assert(q[3] == 11);


    // 和
    q = quaternion(1, 2, 3, 4) + quaternion(2, 2, 2, 2);
    assert(q == quaternion(3, 4, 5, 6));

    q = q + 3;
    assert(q == quaternion(6, 4, 5, 6));

    q = 3 + q;
    assert(q == quaternion(9, 4, 5, 6));

    // 複合代入和
    q += q;
    assert(q == quaternion(18, 8, 10, 12));

    q += 3;
    assert(q == quaternion(21, 8, 10, 12));


    // 差
    q = quaternion(1, 2, 3, 4) - quaternion(2, 2, 2, 2);
    assert(q == quaternion(-1, 0, 1, 2));

    q = q - 3;
    assert(q == quaternion(-4, 0, 1, 2));

    q = 3 - q;
    assert(q == quaternion(7, 0, -1, -2));

    // 複合代入和
    q -= q;
    assert(q == quaternion(0, 0, 0, 0));

    q -= 3;
    assert(q == quaternion(-3, 0, 0, 0));


    // 積
    q = quaternion(1, 2, 3, 4) * quaternion(7, 6, 7, 8);
    assert(q == quaternion(-58, 16, 36, 32));

    q = quaternion(1, 2, 3, 4) * 4;
    assert(q == quaternion(4, 8, 12, 16));

    q = 4 * quaternion(1, 2, 3, 4);
    assert(q == quaternion(4, 8, 12, 16));

    q = quaternion(1, 2, 3, 4);
    q *= quaternion(7, 6, 7, 8);
    assert(q == quaternion(-58, 16, 36, 32));

    q = quaternion(1, 2, 3, 4);
    q *= 4;
    assert(q == quaternion(4, 8, 12, 16));


    // 商
    assert((quaternion(-58.0, 16, 36, 32) / quaternion(7, 6, 7, 8)).approxEqual(quaternion(1, 2, 3, 4)));
    assert(quaternion(4.0, 8, 12, 16) / 4 == quaternion(1, 2, 3, 4));
    assert((16.0 / quaternion(1.0, 2, 3, 4)).approxEqual(quaternion(16.0) / quaternion(1.0, 2, 3, 4)));
    auto p = quaternion(-58.0, 16, 36, 32);
    p /= quaternion(7, 6, 7, 8);
    assert(p.approxEqual(quaternion(1, 2, 3, 4)));

    p = quaternion(4.0, 8, 12, 16);
    p /= 4;
    assert(p.approxEqual(quaternion(1, 2, 3, 4)));
}


/**
四元数の各要素の自乗和を返します
*/
auto sumOfSquare(E)(in Quaternion!E q)
{
    return q.a ^^ 2 + q.b ^^ 2 + q.c ^^ 2 + q.d ^^ 2;
}

unittest
{
    assert(quaternion(1, 2, 3, 4).sumOfSquare == 30);
}


/**
四元数の絶対値を返します
*/
auto abs(E)(in Quaternion!E q)
{
  static if(isFloatingPoint!E)
    return q.sumOfSquare.sqrt;
  else
    return sqrt(q.sumOfSquare.to!real);
}

unittest
{
    assert(quaternion(2, 2, 2, 2).abs == 4);
    assert(quaternion(1, 2, 3, 4).abs == sqrt(30.0));
}


/**
四元数の共役を返します
*/
Quaternion!E conj(E)(in Quaternion!E q) pure nothrow @safe
{
    typeof(return) dst;
    dst.s = q.s;
    dst.v = q.v * -1;
    return dst;
}

unittest
{
    auto q = quaternion(1, 2, 3, 4);
    assert(q.conj == quaternion(1, -2, -3, -4));
}


/**
approxEqualの四元数バージョン
*/
bool approxEqual(alias pred = std.math.approxEqual, E1, E2)(in Quaternion!E1 q1, in Quaternion!E2 q2)
{
    foreach(i; 0 .. 4)
        if(!binaryFun!pred(q1[i], q2[i]))
            return false;
    return true;
}

unittest
{
    auto q = quaternion(1, 2, 3, 4);
    assert(approxEqual(q, q));
}


/**
正規化します
*/
auto normalize(E)(in Quaternion!E q)
{
    return q / q.abs;
}

unittest
{
    auto q = quaternion(1, 2, 3, 4);
    assert(std.math.approxEqual(q.normalize.sumOfSquare, 1));
}
import std.stdio;

/**
積の逆元
*/
auto inverse(E)(in Quaternion!E q)
{
  static if(!isFloatingPoint!E)
    return q.conj / q.sumOfSquare.to!real;
  else
    return q.conj / q.sumOfSquare;
}

unittest
{
    import std.stdio;

    q = quaternion(1, 2, 3, 4);
    assert(approxEqual((q * q.inverse), quaternion(1, 0, 0, 0)));
}
