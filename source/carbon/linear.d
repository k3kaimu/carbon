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
このモジュールは、式テンプレートベースの試験的な行列演算モジュールです。
*/
module carbon.linear;

import std.algorithm,
       std.array,
       std.ascii,
       std.conv,
       std.exception,
       std.format,
       std.functional,
       std.math,
       std.range,
       std.traits,
       std.typecons,
       std.string,
       std.typetuple;

version(unittest) import std.stdio;


/**
行列の格納方式
*/
enum Major
{
    row,
    column,
}

/**
デフォルトでの行列の格納方式は「行優先」です。
*/
enum defaultMajor = Major.row;

alias Msize_t = ptrdiff_t;

enum Msize_t wild = -2,
             dynamic = -1;


/**
行列型かどうかを判定します
*/
enum isMatrix(T) =
    is(typeof((const T m)
    {
        size_t rsize = m.rows;
        size_t csize = m.cols;

        size_t i = 0;

        auto e = m.at(i, i);
    }));


///
enum isNarrowMatrix(T) = 
    is(typeof((const T m)
    {
        size_t rsize = m.rows;
        size_t csize = m.cols;

        auto e1 = m[0, 0];
        auto e2 = m.at(0, 0);

        static assert(is(typeof(e2) : typeof(e1)));
        static assert(is(typeof(e1) : typeof(e2)));
    }));



///
unittest{
    static struct S(size_t R, size_t C)
    {
        enum rows = R;
        enum cols = C;

        auto opIndex(size_t i, size_t j) const
        {
            return i + j;
        }

        alias at = opIndex;
    }

    static assert(isNarrowMatrix!(S!(0, 0)));
    static assert(isMatrix!(S!(1, 1)));
}


/**
大きさが推論される行列かどうか判定します
*/
enum bool isAbstractMatrix(T) = !isMatrix!T &&
    is(typeof((T t)
    {
        auto e = t[0, 0];
        auto f = t.at(0, 0);
        static assert(!is(CommonType!(typeof(e), typeof(f)) == void));


        enum InferredResult result = T.inferSize(wild, wild);

        static if(result.isValid)
        {
            enum inferredRows = result.rows;
            enum inferredCols = result.cols;
        }

        enum someValue = 4; //非負の整数
        static assert(!T.inferSize(wild, wild).isValid);
        static assert(T.inferSize(wild, someValue).isValid);
        static assert(T.inferSize(wild, someValue).isValid);
    }));


/**
ベクトル型かどうか判定します
*/
enum bool isVector(T) =
    is(typeof((const T v)
    {
        size_t size = v.length;

      static if(isMatrix!T)
      {
        assert(min(v.rows, v.cols) == 1);
        assert(max(v.rows, v.cols) == size);
      }

        auto e = v.at(size-1);

      static if(isMatrix!T)
      {
        static assert(is(typeof(e) : typeof(v.at(size-1))));
        static assert(is(typeof(v.at(size-1)) : typeof(e)));
      }
    }));


/**
ベクトル型かどうか判定します
*/
enum isNarrowVector(V) = isMatrix!V && isVector!V && !isAbstractMatrix!V &&
    is(typeof((const V v)
    {
        static if(hasStaticRows!V && hasStaticCols!V)
            static assert(staticRows!V == 1 || staticCols!V == 1);
        else static if(hasStaticRows!V)
            static assert(staticRows!V == 1);
        else static if(hasStaticCols!V)
            static assert(staticCols!V == 1);
        else
            static assert(0);

        auto e = v[0];
        static assert(is(typeof(e) : typeof(v.at(0, 0))));
        static assert(is(typeof(v.at(0, 0)) : typeof(e)));
    }));


unittest{
    static struct V
    {
        enum rows = 1;
        enum cols = 3;
        enum length = 3;

        auto opIndex(size_t i, size_t j) const { return j; }
        auto opIndex(size_t j) const { return j; }

        alias at = opIndex;
    }

    static assert(isMatrix!V);
    static assert(isNarrowMatrix!V);
    static assert(isVector!V);
    static assert(!isAbstractMatrix!V);
    static assert(isNarrowVector!V);

    static assert(isVector!(int[]));
    static assert(isVector!(int[][]));
    static assert(isVector!(int[][1]));
    static assert(isVector!(int[1][]));
}


///
unittest{
    import std.bigint, std.typetuple;
    alias TT = TypeTuple!(ubyte, ushort, uint, ulong,
                           byte,  short,  int,  long,
                          float, double, real,
                          creal, cfloat, cdouble/*,*/
                          /*BigInt*/);

    static struct M(T, size_t r, size_t c)
    {
        enum rows = r;
        enum cols = c;

        auto opIndex(size_t i, size_t j) const { return T.init; }
        alias at = opIndex;
    }

    foreach(T; TT)
    {
        static assert(isNarrowMatrix!(M!(T, 3, 3)));
        static assert(isNarrowMatrix!(M!(const(T), 3, 3)));
        static assert(isNarrowMatrix!(M!(immutable(T), 3, 3)));
        static assert(isMatrix!(M!(T, 3, 3)));
        static assert(isMatrix!(M!(const(T), 3, 3)));
        static assert(isMatrix!(M!(immutable(T), 3, 3)));
    }
}


/**
行列型でも、ベクトル型でもないような型
*/
enum bool isNotVectorOrMatrix(T) =
    !(  isMatrix!T
     || isAbstractMatrix!T
     || isVector!T
    );

///
unittest{
    import std.bigint, std.numeric, std.typetuple;

    alias TT = TypeTuple!(ubyte, ushort, uint, ulong,
                           byte,  short,  int,  long,
                          float, double, real,
                          creal, cfloat, cdouble);

    foreach(T; TT)
    {
        static assert(isNotVectorOrMatrix!(T));
        static assert(isNotVectorOrMatrix!(const(T)));
        static assert(isNotVectorOrMatrix!(immutable(T)));
    }

    static assert(isNotVectorOrMatrix!BigInt);
    // static assert(isNotVectorOrMatrix!(CustomFloat!16)); In dmd2.064, isNotVectorOrMatrix!(CustomFloat!16) is true.
}


/**
行列やベクトルのビューを取得します。
*/
enum bool hasView(T) = is(typeof((T m){
        auto v = m.view;

        static if(isMatrix!T)
            static assert(isMatrix!(typeof(v)));
        else static if(isAbstractMatrix!T)
            static assert(isAbstractMatrix!(typeof(v)));
        else static if(isVector!T)
            static assert(isVector!T);
    }));



auto ref at(R)(auto ref R r, size_t i, size_t j)
if(!isNarrowMatrix!R && is(typeof(r[i][j])))
{
  static if(defaultMajor == Major.row)
    return r[i][j];
  else
    return r[j][i];
}


void assignAt(R, E)(auto ref R r, size_t i, size_t j, auto ref E e)
if(!isNarrowMatrix!R && is(typeof({ r[i][j] = forward!e; })))
{
  static if(defaultMajor == Major.row)
    r[i][j] = forward!e;
  else
    r[j][i] = forward!e;
}


auto ref at(R)(auto ref R r, size_t i, size_t j)
if(!isNarrowMatrix!R && is(typeof(r[i])) && !is(typeof(r[i][j])))
in{
  static if(defaultMajor == Major.row)
    assert(j == 0);
  else
    assert(i == 0);
}
body{
    return r[i+j];
}


void assignAt(R, E)(auto ref R r, size_t i, size_t j, auto ref E e)
if(!isNarrowMatrix!R && is(typeof({ r[i] = forward!e; })) && !is(typeof(r[i][j])))
in{
  static if(defaultMajor == Major.row)
    assert(j == 0);
  else
    assert(i == 0);
}
body{
    r[i+j] = e;
}


auto ref at(M)(auto ref M m, size_t i)
if(isMatrix!M && is(typeof(m.length)))
{
    static if(hasStaticRows!M)
        static if(staticRows!M == 1)
        {
            enum ReturnA = true;
            return m.at(0, i);
        }

  static if(!is(typeof({static assert(ReturnA);})))
  {
    static if(hasStaticCols!M)
        static if(staticCols!M == 1)
        {
            enum ReturnB = true;
            return m.at(i, 0);
        }

    static if(!is(typeof({static assert(ReturnB);})))
    {
      if(m.rows == 1)
          return m.at(0, i);
      else if(m.cols == 1)
          return m.at(i, 0);

      assert(0);
    }
  }
}


void assignAt(M, E)(auto ref M m, size_t i, auto ref E e)
if(isMatrix!M && is(typeof(m.length)) && is(typeof(m.assignAt(0, 0, forward!e))))
{
    static if(hasStaticRows!M)
        static if(staticRows!M == 1)
            return m.assignAt(0, i, forward!e);

    static if(hasStaticCols!M)
        static if(staticCols!M == 1)
            return m.assignAt(i, 0, forward!e);

    if(m.rows == 1)
        return m.assignAt(0, i, forward!e);
    else if(m.cols == 1)
        return m.assignAt(i, 0, forward!e);

    assert(0);
}


size_t rows(R)(auto ref R r) @property
if(!isNarrowMatrix!R && is(typeof(r[0][0])) && hasLength!R && hasLength!(typeof(r[0])))
{
  static if(defaultMajor == Major.row)
    return r.length;
  else
  {
    if(r.length)
        return r[0].length;
    else
        return 0;
  }
}


size_t rows(R)(auto ref R r) @property
if(!isNarrowMatrix!R && is(typeof(r[0])) && !is(typeof(r[0][0])) && hasLength!R)
{
  static if(defaultMajor == Major.row)
    return r.length;
  else
    return 1;
}


size_t cols(R)(auto ref R r) @property
if(is(typeof(r[0][0])) && hasLength!R && hasLength!(typeof(r[0])))
{
  static if(defaultMajor == Major.column)
    return r.length;
  else
  {
    if(r.length)
        return r[0].length;
    else
        return 0;
  }
}


size_t cols(R)(auto ref R r) @property
if(is(typeof(r[0])) && !is(typeof(r[0][0])) && hasLength!R)
{
  static if(defaultMajor == Major.row)
    return 1;
  else
    return r.length;
}


size_t staticRows(T)() @property
if(isNarrowMatrix!T)
{
  static if(is(typeof(T.staticRows)))
    return T.staticRows;
  else static if(is(typeof({ enum srows = T.rows; })))
    return T.rows;
  else
    static assert(0);
}


size_t staticRows(R)() @property
if(!isNarrowMatrix!R && is(typeof(R.init[0][0])) && hasLength!R && hasLength!(std.range.ElementType!R))
{
  static if((defaultMajor == Major.row) && is(typeof({ enum srows = R.length; })))
    return R.length;
  else static if((defaultMajor == Major.column) && is(typeof({ enum srows = std.range.ElementType!R.length; })))
    return std.range.ElementType!R.length;
  else
    static assert(0);
}


size_t staticRows(R)() @property
if(!isNarrowMatrix!R && is(typeof(R.init[0])) && !is(typeof(R.init[0][0])) && hasLength!R)
{
  static if((defaultMajor == Major.row) && is(typeof({ enum srows = R.length; })))
    return R.length;
  else static if(defaultMajor == Major.column)
    return 1;
  else
    static assert(0);
}


size_t staticCols(T)() @property
if(isNarrowMatrix!T)
{
  static if(is(typeof(T.staticCols)))
    return T.staticCols;
  else static if(is(typeof({ enum srows = T.cols; })))
    return T.cols;
  else
    static assert(0);
}


size_t staticCols(R)() @property
if(!isNarrowMatrix!R && is(typeof(R.init[0][0])) && hasLength!R && hasLength!(std.range.ElementType!R))
{
  static if((defaultMajor == Major.column) && is(typeof({ enum scols = R.length; })))
    return R.length;
  else static if((defaultMajor == Major.row) && is(typeof({ enum scols = std.range.ElementType!R.length; })))
    return std.range.ElementType!R.length;
  else
    static assert(0);
}


size_t staticCols(R)() @property
if(!isNarrowMatrix!R && is(typeof(R.init[0])) && !is(typeof(R.init[0][0])) && hasLength!R)
{
  static if((defaultMajor == Major.column) && is(typeof({ enum scols = R.length; })))
    return R.length;
  else static if(defaultMajor == Major.row)
    return 1;
  else
    static assert(0);
}


unittest{
    int[][] arr2d = [
        [ 1,  2,  3],
        [ 4,  5,  6],
        [ 7,  8,  9],
        [10, 11, 12]
    ];

    assert(arr2d.rows == 4);
    assert(arr2d.cols == 3);

    foreach(i; 0 .. arr2d.rows)
        foreach(j; 0 .. arr2d.cols)
            assert(arr2d.at(i, j) == arr2d[i][j]);

    static assert(isMatrix!(int[][]));


    int[] arr1d = [1, 2, 3, 4]; // 列ベクトル

    assert(arr1d.rows == 4);
    assert(arr1d.cols == 1);
    static assert(staticCols!(int[])() == 1);

    foreach(i; 0 .. arr1d.rows)
        foreach(j; 0 .. arr1d.cols)
            assert(arr1d.at(i, j) == arr1d[i] && arr1d.at(i) == arr1d[i]);

    arr2d = [arr1d];            // 行ベクトル
    assert(arr2d.rows == 1);
    assert(arr2d.cols == 4);

    foreach(i; 0 .. arr2d.rows)
        foreach(j; 0 .. arr2d.cols)
            assert(arr2d.at(i, j) == arr2d[i][j] && arr2d.at(j) == arr2d[i][j]);

    static assert(staticRows!(int[4][3]) == 3);
    static assert(staticCols!(int[4][3]) == 4);
    static assert(staticRows!(int[][4]) == 4);
    static assert(staticCols!(int[4][]) == 4);
    static assert(staticRows!(int[4]) == 4);

    static struct M(T, size_t r, size_t c)
    {
        enum rows = r;
        enum cols = c;

        auto opIndex(size_t i, size_t j) const {return T.init;}
        alias at = opIndex;
    }


    static assert(staticRows!(M!(int, 4, 3)) == 4);
    static assert(staticCols!(M!(int, 4, 3)) == 3);
}


unittest{
    static assert(isMatrix!(int[]));
    static assert(!isNarrowMatrix!(int[]));
    static assert(isVector!(int[]));
    static assert(isNarrowVector!(int[]));

    static assert(isMatrix!(int[][]));
    static assert(!isNarrowMatrix!(int[][]));
    static assert(isVector!(int[][]));
    static assert(!isNarrowVector!(int[][]));

    static assert(isMatrix!(int[][][]));
    static assert(!isNarrowMatrix!(int[][][]));
    static assert(isVector!(int[][][]));
    static assert(!isNarrowVector!(int[][][]));


    static struct M0
    {
        enum rows = 3;
        //enum cols = 3;

        auto at(size_t i, size_t j) const
        {
            return i;
        }
    }

    static assert(!isMatrix!(M0));
    static assert(!isNarrowMatrix!(M0));
    static assert(!isVector!(M0));
    static assert(!isNarrowVector!(M0));


    static struct M1
    {
        enum rows = 3;
        enum cols = 3;

        auto at(size_t i, size_t j) const
        {
            return i;
        }
    }

    static assert(isMatrix!(M1));
    static assert(!isNarrowMatrix!(M1));
    static assert(!isVector!(M1));
    static assert(!isNarrowVector!(M1));


    static struct M2
    {
        enum rows = 1;
        enum cols = 3;
        enum length = rows;

        auto at(size_t i, size_t j) const
        {
            return i;
        }

        auto at(size_t j) const
        {
            return at(0, j);
        }
    }

    static assert(isMatrix!(M2));
    static assert(!isNarrowMatrix!(M2));
    static assert(isVector!(M2));
    static assert(!isNarrowVector!(M2));
}


/**
行の大きさが静的な行列型かどうか判定します
*/
enum hasStaticRows(T) = is(typeof(staticRows!T()));

unittest{
    int[4] arr4;
    static assert(hasStaticRows!(int[4]));
}


/**
列の大きさが静的な行列型かどうか判定します
*/
enum hasStaticCols(T) = is(typeof(staticCols!T()));

unittest{
    int[4][] arr4x;
    static assert(hasStaticCols!(typeof(arr4x)));
}


/**
大きさが静的なベクトル型かどうか判定します
*/
enum hasStaticLength(T) = is(typeof({ enum len = T.length; }));

unittest{
    static assert(hasStaticLength!(int[4]));
}


/**
行の大きさが動的な行列型かどうか判定します
*/
enum hasDynamicRows(T) = !hasStaticRows!T && is(typeof({ size_t rs = T.init.rows; }));


/**
列の大きさが動的な行列型かどうか判定します
*/
enum hasDynamicColumns(T) = !hasStaticCols!T && is(typeof({ size_t cs = T.init.cols; }));


/**
大きさが動的なベクトル型かどうか判定します
*/
enum hasDynamicLength(T) = !hasStaticLength!T && is(typeof({ size_t len = T.init.length; }));


/**
大きさが推論される行列が、推論結果を返す際の結果の型です。
*/
struct InferredResult
{
    bool isValid;
    size_t rows;
    size_t cols;
}

/+
version(none):


/**
Matrix -> NarrowMatrix
*/
auto toNarrowMatrix(Major major = defaultMajor, M)(M m)
if(isMatrix!M && !isNarrowMatrix!M)
{
    static struct Result()
    {
      static if(isVector!M)
      {
        auto ref opIndex(size_t i) inout
        {
            return _m.at(i);
        }


        auto ref length() inout
        {
            return _m.length;
        }
      }

        auto ref opIndex(size_t i, size_t j) inout
        {
            return _m.at(i, j);
        }


        alias at = opIndex;


      static if(hasStaticRows!M)
      {
        enum rows = staticRows!M;
      }
      else
      {
        auto ref rows() const @property
        {
            return _m.rows;
        }
      }


      static if(hasStaticCols!M)
      {
        enum cols = staticCols!M;
      }
      else
      {
        auto ref cols() const @property
        {
            return _m.cols;
        }
      }


      private:
        M _m;
    }

    return Result!()(m);
}

unittest {
    auto nm = [1, 2, 3, 4].toNarrowMatrix();
    static assert(isNarrowMatrix!(typeof(nm)));
    static assert(isNarrowVector!(typeof(nm)));
}



version(none):

/**
ベクトルを、行列ベクトル型へ変換します
*/
auto toNarrowVector(Major major = defaultMajor, V)(V v)
if(isVector!V && !isNarrowVector!V)
{
    static struct Result()
    {
      static if(major == Major.row)
      {
        enum rows = 1;

        static if(hasStaticLength!V)
            enum cols = V.length;
        else
            @property size_t cols() const { return _v.length; }
      }
      else
      {
        enum cols = 1;

        static if(hasStaticLength!V)
            enum rows = V.length;
        else
            @property size_t rows() const { return _v.length; }
      }

        @property auto ref length() const { return _v.length; }
        alias opDollar = length;

        auto ref opIndex(size_t i) inout
        in{
            assert(i < length);
        }
        body{
            return _v[i];
        }


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _v[i+j];
        }


        mixin(defaultExprOps!(true));

      private:
        V _v;
    }


    return Result!()(v);
}
+/

/**
行列型の要素の型を取得します
*/
template ElementType(A)
if(isMatrix!A || isAbstractMatrix!A)
{
    alias typeof(A.init.at(0, 0)) ElementType;
}

///
unittest{
    static struct S
    {
        enum rows = 1;
        enum cols = 1;

        int opIndex(size_t, size_t) const
        {
            return 1;
        }

        alias at = opIndex;
    }

    static assert(is(ElementType!S == int));
}


/**
その行列の要素がstd.algorithm.swapを呼べるかどうかをチェックします
*/
template hasLvalueElements(A)
if(isMatrix!A || isAbstractMatrix!A)
{
    enum hasLvalueElements = is(typeof((A a){
            import std.algorithm : swap;

            swap(a.at(0, 0), a.at(0, 0));
        }));
}

///
unittest{
    static struct M
    {
        enum rows = 1;
        enum cols = 1;

        ref int opIndex(size_t i, size_t j) inout
        {
            static int a;
            return a;
        }

        alias at = opIndex;
    }

    static assert(hasLvalueElements!(M));
}


//version(none):


/**
A型の行列の要素にElementType!A型の値が代入可能かどうかをチェックします。
*/
template hasAssignableElements(A)
if(isMatrix!A || isAbstractMatrix!A)
{
    enum hasAssignableElements = is(typeof((A a){
            ElementType!A e;
            a.assignAt(0, 0, e);
        }));
}
unittest{
    static struct M
    {
        enum rows = 1;
        enum cols = 1;

        auto opIndex(size_t i, size_t j) const
        {
            return i;
        }

        void opIndexAssign(typeof(this[0, 0]) a, size_t i, size_t j){}

        auto at(size_t i, size_t j) const
        {
            return this[i, j];
        }

        void assignAt(size_t i, size_t j, typeof(this[0, 0]) e){}
    }

    static assert(hasAssignableElements!(M));
}


/**
aとbが等しいか、もしくはどちらかが0であるとtrueとなります。
2つの行列が演算可能かどうかを判定するのに使います。
*/
private bool isEqOrEitherEqX(alias pred = "a == b", T, X = T)(T a, T b, X x = 0)
{
    return binaryFun!pred(a, b) || a == x || b == x;
}

///
unittest{
    static assert(isEqOrEitherEqX(0, 0));
    static assert(isEqOrEitherEqX(1, 1));
    static assert(isEqOrEitherEqX(0, 1));
    static assert(isEqOrEitherEqX(1, 0));
}


/**
ポインタを管理します
*/
struct PMatrix(M)
if(isMatrix!M)
{
    this(ref M m)
    {
        ptr = &m;
    }


    this(M* m)
    {
        ptr = m;
    }


    auto ref opIndex(size_t r, size_t c) inout
    {
        return (*ptr)[r, c];
    }


  static if(is(typeof({ enum r = M.rows; })))
    enum rows = M.rows;
  else
  {
    auto ref rows() inout @property { return ptr.rows; }

    static if(is(typeof({ ptr.rows = ptr.rows; })))
    void rows(typeof(ptr.rows) r) { ptr.rows = r; }
  }


  static if(is(typeof({ enum r = M.cols; })))
    enum cols = M.cols;
  else
  {
    auto ref cols() inout @property { return ptr.cols; }

    static if(is(typeof({ ptr.cols = ptr.cols; })))
    void cols(typeof(ptr.cols) r) { ptr.cols = r; }
  }


    M* ptr;
    ref inout(typeof(this)) pref() inout pure nothrow @safe @nogc { return this; }


    void opAssign(X)(auto ref X m)
    if(is(typeof(*ptr = m)))
    {
        *ptr = m;
    }


    mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.opAssign, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
}


auto pref(NMatrix)(ref NMatrix nm) @property @trusted
if(isMatrix!NMatrix || isAbstractMatrix!NMatrix)
{
    return PMatrix!NMatrix(nm);
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 2, 2) m;
    m = [[0, 1],
         [2, 3]];

    auto t = m.pref;
    assert(t[0, 0] == 0);
    assert(t[0, 1] == 1);
    assert(t[1, 0] == 2);
    assert(t[1, 1] == 3);
}



/**
正しい演算かどうか判定します

Example:
----
static struct S(T, size_t r, size_t c){enum rows = r; enum cols = c; T opIndex(size_t i, size_t j) const {return T.init;}}
alias Static1x1 = S!(int, 1, 1);
alias Static1x2 = S!(int, 1, 2);
alias Static2x1 = S!(int, 2, 1);
alias Static2x2 = S!(int, 2, 2);

static struct D(T){size_t rows = 1, cols = 1; T opIndex(size_t i, size_t j) const {return T.init;}}
alias Dynamic = D!(int);

static struct I(T){
    enum rows = 0, cols = 0;
    T opIndex(size_t i, size_t j) const { return T.init; }
    static InferredResult inferSize(size_t rs, size_t cs){
        if(rs == 0 && cs == 0)
            return InferredResult(false, 0, 0);
        else if(rs == 0 || cs == 0)
            return InferredResult(true, max(rs, cs), max(rs, cs));
        else
            return InferredResult(true, rs, cs);
    }
}
alias Inferable = I!int;
static assert(Inferable.inferSize(1, 0).isValid);

alias T = Inferable;
static assert(T.rows == wild);
static assert(T.cols == wild);


static assert( isValidOperator!(Static1x1, "+", Static1x1));
static assert(!isValidOperator!(Static1x1, "+", Static1x2));
static assert( isValidOperator!(Static1x2, "+", Static1x2));
static assert(!isValidOperator!(Static1x2, "+", Static1x1));

static assert( isValidOperator!(Static1x1, "+", Dynamic));
static assert( isValidOperator!(Static1x2, "+", Dynamic));
static assert( isValidOperator!(Dynamic, "+", Static1x1));
static assert( isValidOperator!(Dynamic, "+", Static1x2));

static assert( isValidOperator!(Static1x1, "+", Inferable));
static assert( isValidOperator!(Static1x2, "+", Inferable));
static assert( isValidOperator!(Inferable, "+", Static1x1));
static assert( isValidOperator!(Inferable, "+", Static1x2));

static assert( isValidOperator!(Static1x1, "*", Static1x1));
static assert( isValidOperator!(Static1x1, "*", Static1x2));
static assert(!isValidOperator!(Static1x2, "*", Static1x2));
static assert(!isValidOperator!(Static1x2, "*", Static1x1));

static assert( isValidOperator!(Static1x1, "*", Dynamic));
static assert( isValidOperator!(Static1x2, "*", Dynamic));
static assert( isValidOperator!(Dynamic, "*", Static1x1));
static assert( isValidOperator!(Dynamic, "*", Static1x2));

static assert( isValidOperator!(Static1x1, "*", Inferable));
static assert( isValidOperator!(Static1x2, "*", Inferable));
static assert( isValidOperator!(Inferable, "*", Static1x1));
static assert( isValidOperator!(Inferable, "*", Static1x2));
----
*/
template isValidOperator(L, string op, R)
{
  static if(op != "=")
  {
    static if((isMatrix!L || isAbstractMatrix!L) && (isMatrix!R || isAbstractMatrix!R))
        enum isValidOperator = is(typeof(mixin("typeof(L.init.at(0, 0)).init " ~ op ~ " typeof(R.init.at(0, 0)).init"))) && isValidOperatorImpl!(L, op, R);
    else static if(isMatrix!L || isAbstractMatrix!L)
        enum isValidOperator = is(typeof(mixin("typeof(L.init.at(0, 0)).init " ~ op ~ " R.init"))) && isValidOperatorImpl!(L, op, R);
    else static if(isMatrix!R || isAbstractMatrix!R)
        enum isValidOperator = is(typeof(mixin("L.init " ~ op ~ " typeof(R.init.at(0, 0)).init"))) && isValidOperatorImpl!(L, op, R);
    else
        static assert(0);
  }
  else
  {
    static if((isMatrix!L || isAbstractMatrix!L) && (isMatrix!R || isAbstractMatrix!R)){
        enum isValidOperator = isAssignable!(typeof(L.init.at(0, 0)), typeof(R.init.at(0, 0))) && isValidOperatorImpl!(L, "+", R);
    }else static if(isMatrix!L || isAbstractMatrix!L)
        enum isValidOperator = isAssignable!(typeof(L.init.at(0,0)), R) && isValidOperatorImpl!(L, "+", R);
    else static if(isMatrix!R || isAbstractMatrix!R)
        enum isValidOperator = isAssignable!(L, typeof(R.init.at(0, 0))) && isValidOperatorImpl!(L, "+", R);
    else
        static assert(0);
  }
}


template isValidOperatorImpl(L, string op, R)
if((isMatrix!L || isAbstractMatrix!L) && (isMatrix!R || isAbstractMatrix!R) && op != "*")
{
    struct Inferred(M, size_t r, size_t c)
    {
        enum size_t rows = M.inferSize(r, c).rows;
        enum size_t cols = M.inferSize(r, c).cols;

        auto opIndex(size_t i, size_t j) const { return ElementType!M.init; }
    }

    static if(op != "+" && op != "-")
        enum isValidOperatorImpl = false;
    else static if(isAbstractMatrix!L && isAbstractMatrix!R)
        enum isValidOperatorImpl = true;
    else static if(isAbstractMatrix!L)
    {
        static if(hasStaticRows!R && hasStaticCols!R)
            enum isValidOperatorImpl = L.inferSize(staticRows!R, staticCols!R).isValid && isValidOperatorImpl!(Inferred!(L, staticRows!R, staticCols!R), op, R);
        else static if(hasStaticRows!R)
            enum isValidOperatorImpl = L.inferSize(staticRows!R, wild).isValid && isValidOperatorImpl!(Inferred!(L, staticRows!R, wild), op, R);
        else static if(hasStaticCols!R)
            enum isValidOperatorImpl = L.inferSize(wild, staticCols!R).isValid && isValidOperatorImpl!(Inferred!(L, wild, staticCols!R), op, R);
        else
            enum isValidOperatorImpl = true;
    }
    else static if(isAbstractMatrix!R)
        enum isValidOperatorImpl = isValidOperatorImpl!(R, op, L);
    else
    {
        static if(hasStaticRows!L)
        {
            static if(hasStaticRows!R)
                enum _isValidR = staticRows!L == staticRows!R;
            else
                enum _isValidR = true;
        }
        else
            enum _isValidR = true;

        static if(hasStaticCols!L)
        {
            static if(hasStaticCols!R)
                enum _isValidC = staticCols!L == staticCols!R;
            else
                enum _isValidC = true;
        }
        else
            enum _isValidC = true;

        enum isValidOperatorImpl = _isValidR && _isValidC;
    }
}


template isValidOperatorImpl(L, string op, R)
if((isMatrix!L || isAbstractMatrix!L) && (isMatrix!R || isAbstractMatrix!R) && op == "*")
{
    struct Inferred(M, size_t r, size_t c)
    if(r == wild || c == wild)
    {
        enum size_t rows = M.inferSize(r, c).rows;
        enum size_t cols = M.inferSize(r, c).cols;

        auto opIndex(size_t i, size_t j) const { return M.init[i, j]; }
    }


    static if(isAbstractMatrix!L && isAbstractMatrix!R)
        enum isValidOperatorImpl = false;
    else static if(isAbstractMatrix!L)
    {
        static if(hasStaticRows!R)
            enum isValidOperatorImpl = isValidOperatorImpl!(Inferred!(L, wild, staticRows!R), op, R);
        else
            enum isValidOperatorImpl = true;
    }
    else static if(isAbstractMatrix!R)
    {
        static if(hasStaticCols!L)
            enum isValidOperatorImpl = isValidOperatorImpl!(L, op, Inferred!(R, staticCols!L, wild));
        else
            enum isValidOperatorImpl = true;
    }
    else
    {
        static if(hasStaticCols!L && hasStaticRows!R)
            enum isValidOperatorImpl = staticCols!L == staticRows!R;
        else
            enum isValidOperatorImpl = true;
    }
}


template isValidOperatorImpl(L, string op, R)
if(((isMatrix!L || isAbstractMatrix!L) && isNotVectorOrMatrix!R) || ((isMatrix!R || isAbstractMatrix!R) && isNotVectorOrMatrix!L))
{
    static if(op != "+" && op != "-" && op != "*" && op != "/")
        enum isValidOperatorImpl = false;
    else
        enum isValidOperatorImpl = true;
}


unittest{
    static struct S(T, size_t r, size_t c)
    {
        enum rows = r;
        enum cols = c;
        T at(size_t i, size_t j) const { return T.init; }
        alias opIndex = at;

        static assert(isNarrowMatrix!(typeof(this)));
        static assert(isMatrix!(typeof(this)));
        static assert(hasStaticRows!(typeof(this)));
        static assert(hasStaticCols!(typeof(this)));
    }
    alias Static1x1 = S!(int, 1, 1);
    alias Static1x2 = S!(int, 1, 2);
    alias Static2x1 = S!(int, 2, 1);
    alias Static2x2 = S!(int, 2, 2);

    static struct D(T)
    {
        size_t rows = 1, cols = 1;
        T at(size_t i, size_t j) const { return T.init; }
        alias opIndex = at;

        static assert(isNarrowMatrix!(typeof(this)));
        static assert(isMatrix!(typeof(this)));
        static assert(!hasStaticRows!(typeof(this)));
        static assert(!hasStaticCols!(typeof(this)));
    }
    alias Dynamic = D!(int);

    static struct I(T)
    {
        T at(size_t i, size_t j) const { return T.init; }
        alias opIndex = at;

        static InferredResult inferSize(Msize_t rs, Msize_t cs)
        {
            if(rs == wild && cs == wild)
                return InferredResult(false, 0, 0);
            else if(rs == wild || cs == wild)
                return InferredResult(true, max(rs, cs), max(rs, cs));
            else
                return InferredResult(true, rs, cs);
        }
    }
    alias Inferable = I!int;
    static assert(Inferable.inferSize(1, wild).isValid);

    alias T = Inferable;
    static assert(isAbstractMatrix!(I!int));


    static assert( isValidOperator!(Static1x1, "+", Static1x1));
    static assert(!isValidOperator!(Static1x1, "+", Static1x2));
    static assert( isValidOperator!(Static1x2, "+", Static1x2));
    static assert(!isValidOperator!(Static1x2, "+", Static1x1));

    static assert( isValidOperator!(Static1x1, "+", Dynamic));
    static assert( isValidOperator!(Static1x2, "+", Dynamic));
    static assert( isValidOperator!(Dynamic, "+", Static1x1));
    static assert( isValidOperator!(Dynamic, "+", Static1x2));

    static assert( isValidOperator!(Static1x1, "+", Inferable));
    static assert( isValidOperator!(Static1x2, "+", Inferable));
    static assert( isValidOperator!(Inferable, "+", Static1x1));
    static assert( isValidOperator!(Inferable, "+", Static1x2));

    static assert( isValidOperator!(Static1x1, "*", Static1x1));
    static assert( isValidOperator!(Static1x1, "*", Static1x2));
    static assert(!isValidOperator!(Static1x2, "*", Static1x2));
    static assert(!isValidOperator!(Static1x2, "*", Static1x1));

    static assert( isValidOperator!(Static1x1, "*", Dynamic));
    static assert( isValidOperator!(Static1x2, "*", Dynamic));
    static assert( isValidOperator!(Dynamic, "*", Static1x1));
    static assert( isValidOperator!(Dynamic, "*", Static1x2));

    static assert( isValidOperator!(Static1x1, "*", Inferable));
    static assert( isValidOperator!(Static1x2, "*", Inferable));
    static assert( isValidOperator!(Inferable, "*", Static1x1));
    static assert( isValidOperator!(Inferable, "*", Static1x2));

    foreach(i, E1; TypeTuple!(byte, short, int, long))
    {
        foreach(E2; TypeTuple!(byte, short, int, long)[0 .. i+1])
        {
            static assert( isValidOperator!(S!(E1, 1, 1), "=", S!(E2, 1, 1)));
            static assert(!isValidOperator!(S!(E1, 1, 1), "=", S!(E2, 1, 2)));
            static assert( isValidOperator!(S!(E1, 1, 2), "=", S!(E2, 1, 2)));
            static assert(!isValidOperator!(S!(E1, 1, 2), "=", S!(E2, 1, 1)));

            static assert( isValidOperator!(S!(E1, 1, 1), "=", D!(E2)));
            static assert( isValidOperator!(S!(E1, 1, 2), "=", D!(E2)));
            static assert( isValidOperator!(D!(E1), "=", S!(E2, 1, 1)));
            static assert( isValidOperator!(D!(E1), "=", S!(E2, 1, 2)));

            static assert( isValidOperator!(S!(E1, 1, 1), "=", I!(E2)));
            static assert( isValidOperator!(S!(E1, 1, 2), "=", I!(E2)));
            static assert( isValidOperator!(I!(E1), "=", S!(E2, 1, 1)));
            static assert( isValidOperator!(I!(E1), "=", S!(E2, 1, 2)));

            static assert( isValidOperator!(S!(E1, 1, 1), "=", E2));
            static assert( isValidOperator!(D!(E1), "=", E2));
            static assert( isValidOperator!(I!(E1), "=", E2));
        }

        foreach(E2; TypeTuple!(byte, short, int, long)[i+1 .. $])
        {
            static assert(!isValidOperator!(S!(E1, 1, 1), "=", S!(E2, 1, 1)));
            static assert(!isValidOperator!(S!(E1, 1, 1), "=", S!(E2, 1, 2)));
            static assert(!isValidOperator!(S!(E1, 1, 2), "=", S!(E2, 1, 2)));
            static assert(!isValidOperator!(S!(E1, 1, 2), "=", S!(E2, 1, 1)));

            static assert(!isValidOperator!(S!(E1, 1, 1), "=", D!(E2)));
            static assert(!isValidOperator!(S!(E1, 1, 2), "=", D!(E2)));
            static assert(!isValidOperator!(D!(E1), "=", S!(E2, 1, 1)));
            static assert(!isValidOperator!(D!(E1), "=", S!(E2, 1, 2)));

            static assert(!isValidOperator!(S!(E1, 1, 1), "=", I!(E2)));
            static assert(!isValidOperator!(S!(E1, 1, 2), "=", I!(E2)));
            static assert(!isValidOperator!(I!(E1), "=", S!(E2, 1, 1)));
            static assert(!isValidOperator!(I!(E1), "=", S!(E2, 1, 2)));

            static assert(!isValidOperator!(S!(E1, 1, 1), "=", E2));
            static assert(!isValidOperator!(D!(E1), "=", E2));
            static assert(!isValidOperator!(I!(E1), "=", E2));
        }
    }
}


/**
式テンプレート演算子の種類
*/
enum ETOSpec : uint
{
    none = 0,
    matrixAddMatrix = (1 << 0),
    matrixSubMatrix = (1 << 1),
    matrixMulMatrix = (1 << 2),
    matrixAddScalar = (1 << 3),
    scalarAddMatrix = (1 << 4),
    matrixSubScalar = (1 << 5),
    scalarSubMatrix = (1 << 6),
    matrixMulScalar = (1 << 7),
    scalarMulMatrix = (1 << 8),
    matrixDivScalar = (1 << 9),
    scalarDivMatrix = (1 << 10),
    addScalar = (1 << 11),
    subScalar = (1 << 12),
    mulScalar = (1 << 13),
    divScalar = (1 << 14),
    opEquals = (1 << 15),
    toString = (1 << 16),
    opAssign = (1 << 17),
    swizzle = (1 << 18),
    modifiedOperator = addScalar | subScalar | mulScalar | divScalar | opAssign,
    all = (1 << 19) -1,
}


/**
式テンプレートでの演算子の種類を返します
*/
template ETOperatorSpec(A, string op, B)
if(isValidOperator!(A, op, B))
{
    static if((isMatrix!A || isAbstractMatrix!A) && (isMatrix!B || isAbstractMatrix!B))
        enum ETOSpec ETOperatorSpec = op == "+" ? ETOSpec.matrixAddMatrix
                                                : (op == "-" ? ETOSpec.matrixSubMatrix
                                                             : ETOSpec.matrixMulMatrix);
    else static if(isNotVectorOrMatrix!A)
        enum ETOSpec ETOperatorSpec = op == "+" ? ETOSpec.scalarAddMatrix
                                                : (op == "-" ? ETOSpec.scalarSubMatrix
                                                             : (op == "*" ? ETOSpec.scalarMulMatrix
                                                                          : ETOSpec.scalarDivMatrix));
    else
        enum ETOSpec ETOperatorSpec = op == "+" ? ETOSpec.matrixAddScalar
                                                : (op == "-" ? ETOSpec.matrixSubScalar
                                                             : (op == "*" ? ETOSpec.matrixMulScalar
                                                                          : ETOSpec.matrixDivScalar));
}

///
unittest{
    static struct S(T, size_t r, size_t c)
    {
        enum rows = r;
        enum cols = c;
        T opIndex(size_t i, size_t j) const {return T.init;}
        alias at = opIndex;
    }
    alias Matrix2i = S!(int, 2, 2);

    static assert(ETOperatorSpec!(Matrix2i, "+", Matrix2i) == ETOSpec.matrixAddMatrix);
    static assert(ETOperatorSpec!(Matrix2i, "-", Matrix2i) == ETOSpec.matrixSubMatrix);
    static assert(ETOperatorSpec!(Matrix2i, "*", Matrix2i) == ETOSpec.matrixMulMatrix);
    static assert(ETOperatorSpec!(Matrix2i, "*", int) == ETOSpec.matrixMulScalar);
    static assert(ETOperatorSpec!(int, "*", Matrix2i) == ETOSpec.scalarMulMatrix);
}


/**
式テンプレートでの、式を表します
*/
struct MatrixExpression(Lhs, string s, Rhs)
if(isValidOperator!(Lhs, s, Rhs)
  && (isAbstractMatrix!Lhs || isAbstractMatrix!Rhs)
  && !(isMatrix!Lhs || isMatrix!Rhs))
{
    enum etoSpec = ETOperatorSpec!(Lhs, s, Rhs);


    static InferredResult inferSize(Msize_t r, Msize_t c)
    {
        static if(isAbstractMatrix!Lhs && isAbstractMatrix!Rhs)
        {
            static assert(s != "*");
            auto rLhs = Lhs.inferSize(r, c);
            auto rRhs = Rhs.inferSize(r, c);

            bool b = rLhs.isValid && rRhs.isValid && rLhs.rows == rRhs.rows && rLhs.cols == rRhs.cols;
            return InferredResult(b, rLhs.rows, rLhs.cols);
        }
        else static if(isAbstractMatrix!Lhs)
            return Lhs.inferSize(r, c);
        else
            return Rhs.inferSize(r, c);
    }


    auto opIndex(size_t i, size_t j) const
    {
      static if(etoSpec == ETOSpec.matrixAddMatrix)
        return this.lhs[i, j] + this.rhs[i, j];
      else static if(etoSpec == ETOSpec.matrixSubMatrix)
        return this.lhs[i, j] - this.rhs[i, j];
      else static if(etoSpec == ETOSpec.matrixMulMatrix)
      {
        static assert(0);
        return typeof(this.lhs.at(0, 0) + this.rhs.at(0, 0)).init;
      }
      else
      {
        static if(isMatrix!Lhs || isAbstractMatrix!Lhs)
            return mixin("this.lhs.at(i, j) " ~ s ~ " this.rhs");
        else
            return mixin("this.lhs " ~ s ~ " this.rhs.at(i, j)");
      }
    }


    mixin(defaultExprOps!(true));

  private:
    Lhs lhs;
    Rhs rhs;
}


/// ditto
struct MatrixExpression(Lhs, string s, Rhs)
if(isValidOperator!(Lhs, s, Rhs)
  && !((isAbstractMatrix!Lhs || isAbstractMatrix!Rhs)
    && !(isMatrix!Lhs || isMatrix!Rhs)))
{
    enum etoSpec = ETOperatorSpec!(Lhs, s, Rhs);


    static if((isMatrix!Lhs || isAbstractMatrix!Lhs) && (isMatrix!Rhs || isAbstractMatrix!Rhs))
    {
        static if(s == "*")
        {
            static if(hasStaticRows!Lhs)
            {
                enum rows = Lhs.rows;
                private enum staticrows = rows;
            }
            else static if(isAbstractMatrix!Lhs && hasStaticRows!Rhs)
            {
                enum rows = Lhs.inferSize(wild, Rhs.rows).rows;
                private enum staticrows = rows;
            }
            else static if(hasDynamicRows!Lhs)
            {
                @property size_t rows() const { return this.lhs.rows; }
                private enum staticrows = wild;
            }
            else static if(isAbstractMatrix!Lhs && hasDynamicRows!Rhs)
            {
                @property size_t rows() const { return this.lhs.inferSize(wild, rhs.rows).rows; }
                private enum staticrows = wild;
            }
            else
                static assert(0);


            static if(hasStaticCols!Rhs)
            {
                enum cols = Rhs.cols;
                private enum staticcols = cols;
            }
            else static if(isAbstractMatrix!Rhs && hasStaticCols!Lhs)
            {
                enum cols = Rhs.inferSize(Lhs.cols, wild).cols;
                private enum staticcols = cols;
            }
            else static if(hasDynamicRows!Rhs)
            {
                @property size_t cols() const { return this.rhs.cols; }
                private enum staticcols = wild;
            }
            else static if(isAbstractMatrix!Rhs && hasDynamicColumns!Lhs)
            {
                @property size_t cols() const { return this.rhs.inferSize(lhs.cols, wild).cols; }
                private enum staticcols = wild;
            }
            else
                static assert(0);
        }
        else
        {
            static if(hasStaticRows!Lhs)
            {
                enum rows = Lhs.rows;
                private enum staticrows = rows;
            }
            else static if(hasStaticRows!Rhs)
            {
                enum rows = Rhs.rows;
                private enum staticrows = rows;
            }
            else static if(hasDynamicRows!Lhs)
            {
                @property size_t rows() const { return this.lhs.rows; }
                private enum staticrows = wild;
            }
            else
            {
                @property size_t rows() const { return this.rhs.rows; }
                private enum staticrows = wild;
            }

            static if(hasStaticCols!Lhs)
            {
                enum cols = Lhs.cols;
                private enum staticcols = cols;
            }
            else static if(hasStaticCols!Rhs)
            {
                enum cols = Rhs.cols;
                private enum staticcols = cols;
            }
            else static if(hasDynamicColumns!Lhs)
            {
                @property size_t cols() const { return this.lhs.cols; }
                private enum staticcols = wild;
            }
            else
            {
                @property size_t cols() const { return this.rhs.cols; }
                private enum staticcols = wild;
            }
        }
    }
    else static if(isMatrix!Lhs || isAbstractMatrix!Lhs)
    {
        static assert(!isAbstractMatrix!Lhs);

        static if(hasStaticRows!Lhs)
        {
            enum rows = Lhs.rows;
            private enum staticrows = rows;
        }
        else
        {
            @property size_t rows() const { return this.lhs.rows; }
            private enum staticrows = wild;
        }

        static if(hasStaticCols!Lhs)
        {
            enum cols = Lhs.cols;
            private enum staticcols = cols;
        }
        else
        {
            @property size_t cols() const { return this.lhs.cols; }
            private enum staticcols = wild;
        }
    }
    else
    {
        static assert(!isAbstractMatrix!Rhs);

        static if(hasStaticRows!Rhs)
        {
            enum rows = Rhs.rows;
            private enum staticrsght = rows;
        }
        else
        {
            @property size_t rows() const { return this.rhs.rows; }
            private enum staticrsght = wild;
        }

        static if(hasStaticCols!Rhs)
        {
            enum cols = Rhs.cols;
            private enum staticcsght = cols;
        }
        else
        {
            @property size_t cols() const { return this.rhs.cols; }
            private enum staticcsght = wild;
        }
    }


    auto opIndex(size_t i, size_t j) const
    in{
        assert(i < this.rows);
        assert(j < this.cols);
    }
    body{
      static if(etoSpec == ETOSpec.matrixAddMatrix)
        return this.lhs.at(i, j) + this.rhs.at(i, j);
      else static if(etoSpec == ETOSpec.matrixSubMatrix)
        return this.lhs.at(i, j) - this.rhs.at(i, j);
      else static if(etoSpec == ETOSpec.matrixMulMatrix)
      {
        auto sum = cast(Unqual!(typeof(this.lhs.at(0, 0) * this.rhs.at(0, 0))))0;

        static if(hasStaticCols!Lhs)
            immutable cnt = Lhs.cols;
        else static if(hasStaticRows!Rhs)
            immutable cnt = Rhs.rows;
        else static if(hasDynamicColumns!Lhs)
            immutable cnt = this.lhs.cols;
        else
            immutable cnt = this.rhs.rows;

        foreach(k; 0 .. cnt)
            sum += this.lhs.at(i, k) * this.rhs.at(k, j);
        return sum;
      }
      else
      {
        static if(isMatrix!Lhs || isAbstractMatrix!Lhs)
            return mixin("this.lhs.at(i, j) " ~ s ~ " this.rhs");
        else
            return mixin("this.lhs " ~ s ~ " this.rhs.at(i, j)");
      }
    }

    mixin(defaultExprOps!(false));

  private:
    Lhs lhs;
    Rhs rhs;
}


/// ditto
auto matrixExpression(string s, A, B)(auto ref A a, auto ref B b)
if(isValidOperator!(A, s, B))
{
    return MatrixExpression!(A, s, B)(a, b);
    static assert(isNarrowMatrix!(MatrixExpression!(A, s, B))
               || isAbstractMatrix!(MatrixExpression!(A, s, B)));
}


/**
specに示された演算子をオーバーロードします。specはETOSpecで指定する必要があります。
*/
template ExpressionOperators(size_t spec, size_t rs, size_t cs)
{
    enum stringMixin = 
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        static if(is(typeof({enum _unused_ = this.rows;}))) static assert(rows != 0);
        static if(is(typeof({enum _unused_ = this.cols;}))) static assert(cols != 0);

        alias at = opIndex;
    } ~


    ( rs == 1 ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        alias cols length;
        alias length opDollar;


        auto ref opIndex(size_t i) inout
        in{
            assert(i < this.cols);
        }
        body{
            return this[0, i];
        }

      static if(is(typeof({this[0, 0] = this[0, 0];})))
      {
        auto ref opIndexAssign(S)(S value, size_t i)
        if(is(typeof(this[0, i] = value)))
        in{
            assert(i < this.cols);
        }
        body{
            return this[0, i] = value;
        }


        auto ref opIndexOpAssign(string op, S)(S value, size_t i)
        if(is(typeof(mixin("this[0, i] " ~ op ~ "= value"))))
        in{
            assert(i < this.cols);
        }
        body{
            return mixin("this[0, i] " ~ op ~ "= value");
        }
      }
    } : ( cs == 1 ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        alias rows length;
        alias length opDollar;


        auto ref opIndex(size_t i) inout
        in{
            assert(i < this.rows);
        }
        body{
            return this[i, 0];
        }

      static if(is(typeof({this[0, 0] = this[0, 0];})))
      {
        auto ref opIndexAssign(S)(S value, size_t i)
        if(is(typeof(this[i, 0] = value)))
        in{
            assert(i < this.rows);
        }
        body{
            return this[0, i] = value;
        }


        auto ref opIndexOpAssign(string op, S)(S value, size_t i)
        if(is(typeof(mixin("this[i, 0] " ~ op ~ "= value"))))
        in{
            assert(i < this.rows);
        }
        body{
            return mixin("this[i, 0] " ~ op ~ "= value");
        }
      }
    } : ""
    )) ~


    /*
    ((rs == 1 || cs == 1) && (spec & ETOSpec.opAssign) ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opAssign(Array)(Array arr)
        if(!isNarrowMatrix!Array && is(typeof(arr[size_t.init])) && isAssignable!(typeof(this[size_t.init]), typeof(arr[size_t.init])))
        {
            foreach(i; 0 .. this.length)
                this[i] = arr[i];
        }
    } : ""
    ) ~
    */


    (rs == 1 && cs == 1 ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto det() const @property
        {
            return this[0, 0];
        }

        alias det this;


        auto ref opAssign(S)(S value)
        if(is(typeof(this[0, 0] = value)))
        {
            return this[0, 0] = value;
        }


        auto ref opOpAssign(S)(S value)
        if(is(typeof(mixin("this[0, 0] " ~ op ~ "= value"))))
        {
            return mixin("this[0, 0] " ~ op ~ "= value");
        }
    } : ""
    ) ~


    (spec & ETOSpec.opEquals ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        bool opEquals(Rhs)(auto ref const Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        {
            static assert(isValidOperator!(Unqual!(typeof(this)), "+", Rhs));

            static if(isAbstractMatrix!Rhs)
            {
                auto result = Rhs.inferSize(this.rows, this.cols);
                if(!result.isValid)
                    return false;
            }
            else
            {
                if(this.rows != mat.rows)
                    return false;

                if(this.cols != mat.cols)
                    return false;
            }

            foreach(i; 0 .. this.rows)
                foreach(j; 0 .. this.cols)
                    if(this[i, j] != mat.at(i, j))
                        return false;
            return true;
        }
    } : ""
    ) ~


    (spec & ETOSpec.toString ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        @property
        void toString(scope void delegate(const(char)[]) sink, string formatString) const @system
        {
            sink.formattedWrite(formatString, this.toRange);
        }
    } : ""
    ) ~


    (spec & ETOSpec.opAssign ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opAssign(M)(M m)
        if((isMatrix!M || isAbstractMatrix!M) && is(typeof(this[0, 0] = m.at(0, 0))))
        in{
            static if(isAbstractMatrix!M)
                assert(m.inferSize(this.rows, this.cols).isValid);
            else
            {
                assert(m.rows == this.rows);
                assert(m.cols == this.cols);
            }
        }
        body{
            static assert(isValidOperator!(typeof(this), "=", M));

            foreach(i; 0 .. this.rows)
                foreach(j; 0 .. this.cols)
                    this[i, j] = m.at(i, j);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixAddMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "+", Rhs)(auto ref Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(isAbstractMatrix!Rhs)
                assert(mat.inferSize(this.rows, this.cols).isValid);
            else
            {
                assert(mat.rows == this.rows);
                assert(mat.cols == this.cols);
            }
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"+"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixSubMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "-", Rhs)(auto ref Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(isAbstractMatrix!Rhs)
                assert(mat.inferSize(this.rows, this.cols).isValid);
            else
            {
                assert(mat.rows == this.rows);
                assert(mat.cols == this.cols);
            }
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"-"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixMulMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "*", Rhs)(auto ref Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(isAbstractMatrix!Rhs)
                assert(mat.inferSize(this.cols, wild).isValid);
            else
                assert(mat.rows == this.cols);
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"*"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixAddScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "+", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"+"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarAddMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "+", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"+"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixSubScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "-", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"-"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarSubMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "-", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"-"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixMulScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "*", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"*"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarMulMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "*", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"*"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixDivScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "/", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"/"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarDivMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "/", S)(S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"/"(s, this);
        }
    } : ""
    ) ~ 


    (spec & ETOSpec.addScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "+", S)(S scalar)
        if(is(typeof(this[0, 0] += scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] +=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.subScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "-", S)(S scalar)
        if(is(typeof(this[0, 0] -= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] -=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.mulScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "*", S)(S scalar)
        if(is(typeof(this[0, 0] *= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] *=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.divScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "/", S)(S scalar)
        if(is(typeof(this[0, 0] /= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] /=  scalar;
        }
    } : ""
    ) ~


    ((spec & ETOSpec.swizzle) && (rs == 1 || cs == 1) ? 
        (rs*cs >= 1 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref a() inout @property { return this[0]; }
            alias x = a;
            alias r = a;
            alias re = a;
        } : ""
        ) ~ 
        (rs*cs >= 2 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref b() inout @property { return this[1]; }
            alias y = b;
            alias im = b;
            alias i = b;
        } : ""
        ) ~ 
        (rs*cs >= 3 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref c() inout @property { return this[2]; }
            alias z = c;
            alias j = c;
        } : ""
        ) ~ 
        (rs*cs >= 4 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref d() inout @property { return this[3]; }
            alias k = d;
            alias w = d;
        } : ""
        ) ~ 
        (rs*cs >= 5 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref e() inout @property { return this[4]; }
        } : ""
        ) ~ 
        (rs*cs >= 6 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref f() inout @property { return this[5]; }
        } : ""
        ) ~ 
        (rs*cs >= 7 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref g() inout @property { return this[6]; }
        } : ""
        ) ~ 
        (rs*cs >= 8 ?
        format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
        q{
            auto ref h() inout @property { return this[7]; }
        } : ""
        ) : ""
    );


    mixin template templateMixin()
    {
        mixin(stringMixin);
    }
}


/// ditto
template ExpressionOperatorsInferable(size_t spec)
{
    enum stringMixin = 
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        alias at = opIndex;
    } ~


    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        bool opEquals(Rhs)(auto ref in Rhs mat) const
        if(isMatrix!Rhs && !is(Unqual!Rhs == typeof(this)) && !isAbstractMatrix!(Rhs))
        {
            static assert(isValidOperator!(Unqual!(typeof(this)), "+", Rhs));

            if(!this.inferSize(mat.rows, mat.cols).isValid)
                return false;

            foreach(i; 0 .. mat.rows)
                foreach(j; 0 .. mat.cols)
                    if(this[i, j] != mat.at(i, j))
                        return false;
            return true;
        }
    } ~


    (spec & ETOSpec.matrixAddMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "+", Rhs)(auto ref const Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(!isAbstractMatrix!Rhs)
                assert(this.inferSize(mat.rows, mat.cols).isValid);
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"+"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixSubMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "-", Rhs)(auto ref const Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(!isAbstractMatrix!Rhs)
                assert(this.inferSize(mat.rows, mat.cols).isValid);
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"-"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixMulMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "*", Rhs)(auto ref const Rhs mat) const
        if(isMatrix!Rhs || isAbstractMatrix!Rhs)
        in{
            static if(!isAbstractMatrix!Rhs)
                assert(this.inferSize(wild, mat.rows).isValid);
        }
        body{
            static assert(isValidOperator!(typeof(this), op, Rhs));
            return matrixExpression!"*"(this, mat);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixAddScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "+", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"+"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarAddMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "+", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"+"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixSubScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "-", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"-"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarSubMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "-", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"-"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixMulScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "*", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"*"(this, s);
        }
    } : ""
    ) ~


    (spec & ETOSpec.scalarMulMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "*", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"*"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.matrixDivScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinary(string op : "/", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(typeof(this), op, S));
            return matrixExpression!"/"(this, s);
        }
    } : ""
    ) ~

    (spec & ETOSpec.scalarDivMatrix ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        auto opBinaryRight(string op : "/", S)(const S s) const
        if(isNotVectorOrMatrix!S)
        {
            static assert(isValidOperator!(S, op, typeof(this)));
            return matrixExpression!"/"(s, this);
        }
    } : ""
    ) ~


    (spec & ETOSpec.addScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "+", S)(const S scalar)
        if(isNotVectorOrMatrix!S && is(typeof(this[0, 0] += scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] +=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.subScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "-", S)(const S scalar)
        if(isNotVectorOrMatrix!S && is(typeof(this[0, 0] -= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] -=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.mulScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "*", S)(const S scalar)
        if(isNotVectorOrMatrix!S && is(typeof(this[0, 0] *= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] *=  scalar;
        }
    } : ""
    ) ~


    (spec & ETOSpec.divScalar ?
    format(`#line %s "%s"`, __LINE__+2, __FILE__) ~
    q{
        void opOpAssign(string op : "+", S)(const S scalar)
        if(isNotVectorOrMatrix!S && is(typeof(this[0, 0] /= scalar)))
        {
            foreach(r; 0 .. rows)
                foreach(c; 0 .. cols)
                    this[r, c] /=  scalar;
        }
    } : ""
    );


    mixin template templateMixin()
    {
        mixin(stringMixin);
    }
}


/**
全ての演算子をオーバーロードします。
*/
template defaultExprOps(bool isInferable = false)
{
    enum defaultExprOps = 
    isInferable ?
    q{
        mixin(ExpressionOperatorsInferable!(ETOSpec.all).stringMixin);
        //mixin(ExpressionOperatorsInferable!(ETOSpec.all & ~ETOSpec.opEquals & ~ETOSpec.toString).stringMixin);
        //mixin(ExpressionOperatorsInferable!(ETOSpec.modifiedOperator).stringMixin);
        //const{mixin(ExpressionOperatorsInferable!(ETOSpec.all & ~ETOSpec.modifiedOperator).stringMixin);}
        //immutable{mixin(ExpressionOperatorsInferable!(ETOSpec.all & ~ETOSpec.opEquals & ~ETOSpec.toString).stringMixin);}
    }
    :
    q{
        mixin(ExpressionOperators!(ETOSpec.all, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
        //mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.opEquals & ~ETOSpec.toString, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
        //mixin(ExpressionOperators!(ETOSpec.modifiedOperator, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
        //const{mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.modifiedOperator, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);}
        //immutable{mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.opEquals & ~ETOSpec.toString, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);}
    };
}


unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    static struct M(size_t rs, size_t cs)
    {
        enum rows = rs;
        enum cols = cs;

        size_t opIndex(size_t i, size_t j) inout {return i + j;}

        //inout:
        mixin(defaultExprOps!(false));
    }


    alias S3 = M!(3, 3);
    alias S23 = M!(2, 3);

    static assert(isNarrowMatrix!S3);
    static assert(hasStaticRows!S3);
    static assert(hasStaticCols!S3);
    static assert(isNarrowMatrix!S23);
    static assert(hasStaticRows!S23);
    static assert(hasStaticCols!S23);


    M!(1, 1) m11;
    static assert(isNarrowMatrix!(typeof(m11)));
    size_t valueM11 = m11;

    M!(3, 1) m31;
    M!(1, 3) m13;
    valueM11 = m13 * m31;


    // swizzle
    M!(1, 8) m18;
    assert(m18[0] == m18.a);
    assert(m18[1] == m18.b);
    assert(m18[2] == m18.c);
    assert(m18[3] == m18.d);
    assert(m18[4] == m18.e);
    assert(m18[5] == m18.f);
    assert(m18[6] == m18.g);
    assert(m18[7] == m18.h);

    assert(m18[0] == m18.r);
    assert(m18[1] == m18.i);
    assert(m18[2] == m18.j);
    assert(m18[3] == m18.k);

    assert(m18[0] == m18.x);
    assert(m18[1] == m18.y);
    assert(m18[2] == m18.z);
    assert(m18[3] == m18.w);

    assert(m18[0] == m18.re);
    assert(m18[1] == m18.im);


    static struct I
    {
        size_t opIndex(size_t i, size_t j) inout { return i == j ? 1  : 0;}
        alias at = opIndex;

        static InferredResult inferSize(Msize_t r, Msize_t c)
        {
            if(r == wild && c == wild)
                return InferredResult(false);
            else if(r == c || r == wild || c == wild)
                return InferredResult(true, max(r, c), max(r, c));
            else
                return InferredResult(false);
        }

        mixin(defaultExprOps!(true));
    }

    //static assert(isNarrowMatrix!I);
    static assert(isAbstractMatrix!I);
    static assert( I.inferSize(wild, 1).isValid);
    static assert( I.inferSize(3, 3).isValid);
    static assert(!I.inferSize(1, 3).isValid);


    static struct D{
        size_t rows;
        size_t cols;

        size_t opIndex(size_t i, size_t j) inout {return i + j;}

        mixin(defaultExprOps!(false));
    }
    static assert(isNarrowMatrix!D);
    static assert(hasDynamicRows!D);
    static assert(hasDynamicColumns!D);


    S3 a;
    auto add = a + a;
    static assert(isNarrowMatrix!(typeof(add)));
    static assert(hasStaticRows!(typeof(add)));
    static assert(hasStaticCols!(typeof(add)));
    assert(add[0, 0] == 0); assert(add[0, 1] == 2); assert(add[0, 2] == 4);
    assert(add[1, 0] == 2); assert(add[1, 1] == 4); assert(add[1, 2] == 6);
    assert(add[2, 0] == 4); assert(add[2, 1] == 6); assert(add[2, 2] == 8);

    auto mul = a * a;
    static assert(isNarrowMatrix!(typeof(mul)));
    static assert(hasStaticRows!(typeof(mul)));
    static assert(hasStaticCols!(typeof(mul)));
    assert(mul[0, 0] == 5); assert(mul[0, 1] == 8); assert(mul[0, 2] ==11);
    assert(mul[1, 0] == 8); assert(mul[1, 1] ==14); assert(mul[1, 2] ==20);
    assert(mul[2, 0] ==11); assert(mul[2, 1] ==20); assert(mul[2, 2] ==29);

    auto sadd = a + 3;
    static assert(isNarrowMatrix!(typeof(sadd)));
    static assert(hasStaticRows!(typeof(sadd)));
    static assert(hasStaticCols!(typeof(sadd)));
    assert(sadd[0, 0] == 3); assert(sadd[0, 1] == 4); assert(sadd[0, 2] == 5);
    assert(sadd[1, 0] == 4); assert(sadd[1, 1] == 5); assert(sadd[1, 2] == 6);
    assert(sadd[2, 0] == 5); assert(sadd[2, 1] == 6); assert(sadd[2, 2] == 7);

    // auto addMasS = a + m11;

    auto add5 = a + a + cast(const)(a) * 3;
    static assert(isNarrowMatrix!(typeof(add5)));
    static assert(hasStaticRows!(typeof(add5)));
    static assert(hasStaticCols!(typeof(add5)));
    assert(add5 == a * 5);

    I i;
    auto addi = a + i;
    static assert(isNarrowMatrix!(typeof(addi)));
    static assert(hasStaticRows!(typeof(addi)));    static assert(typeof(addi).rows == 3);
    static assert(hasStaticCols!(typeof(addi))); static assert(typeof(addi).cols == 3);
    assert(addi[0, 0] == 1); assert(addi[0, 1] == 1); assert(addi[0, 2] == 2);
    assert(addi[1, 0] == 1); assert(addi[1, 1] == 3); assert(addi[1, 2] == 3);
    assert(addi[2, 0] == 2); assert(addi[2, 1] == 3); assert(addi[2, 2] == 5);

    auto i2 = i * 2;
    static assert(!isNarrowMatrix!(typeof(i2)));
    static assert(isAbstractMatrix!(typeof(i2)));
    static assert( typeof(i2).inferSize(wild, 1).isValid);
    static assert( typeof(i2).inferSize(3, 3).isValid);
    static assert(!typeof(i2).inferSize(1, 3).isValid);

    auto addi2 = a + i2;
    static assert(isNarrowMatrix!(typeof(addi2)));
    static assert(hasStaticRows!(typeof(addi2)));    static assert(typeof(addi2).rows == 3);
    static assert(hasStaticCols!(typeof(addi2))); static assert(typeof(addi2).cols == 3);
    assert(addi2[0, 0] == 2); assert(addi2[0, 1] == 1); assert(addi2[0, 2] == 2);
    assert(addi2[1, 0] == 1); assert(addi2[1, 1] == 4); assert(addi2[1, 2] == 3);
    assert(addi2[2, 0] == 2); assert(addi2[2, 1] == 3); assert(addi2[2, 2] == 6);

    static assert(!is(typeof(S23.init + i)));
    static assert(!is(typeof(i + S23.init)));
    assert(S23.init * i == S23.init);
    assert(i * S23.init == S23.init);


    import core.exception, std.exception;

    D d33 = D(3, 3);
    auto addsd = a + d33;
    static assert(isNarrowMatrix!(typeof(addsd)));
    static assert(hasStaticRows!(typeof(addsd)));
    static assert(hasStaticCols!(typeof(addsd)));
    assert(addsd == a * 2);
    assert(addsd == d33 * 2);

    auto addsdr = d33 + a;
    static assert(isNarrowMatrix!(typeof(addsdr)));
    static assert(hasStaticRows!(typeof(addsdr)));
    static assert(hasStaticCols!(typeof(addsdr)));
    assert(addsdr == addsd);
    assert(addsdr == addsd);

    version(Release){}else assert(collectException!AssertError(D(2, 3) + a));
    version(Release){}else assert(collectException!AssertError(D(2, 3) + i));
    assert(D(2, 3) * i == D(2, 3));

    version(Release){}else assert(collectException!AssertError(D(2, 3) + D(2, 2)));
    version(Release){}else assert(collectException!AssertError(D(2, 3) + D(3, 3)));
    assert((D(2, 3) + D(2, 3)).rows == 2);
    assert((D(2, 3) + D(2, 3)).cols == 3);
    assert((D(2, 3) * D(3, 4)).rows == 2);
    assert((D(2, 3) * D(3, 4)).cols == 4);

    auto mulds = d33 * 3;
    assert(mulds == d33 + d33 + d33);
}


/**
InferableMatrixをある大きさの行列へ固定します。
*/
auto congeal(Msize_t rs, Msize_t cs, A)(A mat)
if(isAbstractMatrix!A && A.inferSize(rs, cs).isValid)
{
    static struct Result()
    {
        enum size_t rows = A.inferSize(rs, cs).rows;
        enum size_t cols = A.inferSize(rs, cs).cols;

        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _mat[i, j];
        }


      static if(carbon.linear.hasAssignableElements!A)
      {
        void opIndexAssign(E)(E e, size_t i, size_t j)
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            _mat[i, j] = e;
        }
      }

        mixin(defaultExprOps!(false));

      private:
        A _mat;
    }

    return Result!()(mat);
}

///
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    static struct I{

        size_t opIndex(size_t i, size_t j) inout { return i == j ? 1  : 0;}

        static InferredResult inferSize(Msize_t r, Msize_t c)
        {
            if(r == wild && c == wild)
                return InferredResult(false);
            else if(isEqOrEitherEqX(r, c, wild))
                return InferredResult(true, max(r, c), max(r, c));
            else
                return InferredResult(false);
        }

        mixin(defaultExprOps!(true));
    }

    static assert(!isNarrowMatrix!I);
    static assert(isAbstractMatrix!I);
    static assert( I.inferSize(wild, 1).isValid);
    static assert( I.inferSize(3, 3).isValid);
    static assert(!I.inferSize(1, 3).isValid);

    I id;
    auto i3x3 = id.congeal!(3, 3)();
    static assert(isNarrowMatrix!(typeof(i3x3)));
    static assert(hasStaticRows!(typeof(i3x3)));
    static assert(hasStaticCols!(typeof(i3x3)));
    static assert(i3x3.rows == 3);
    static assert(i3x3.cols == 3);
    assert(i3x3[0, 0] == 1);assert(i3x3[1, 0] == 0);assert(i3x3[2, 0] == 0);
    assert(i3x3[0, 1] == 0);assert(i3x3[1, 1] == 1);assert(i3x3[2, 1] == 0);
    assert(i3x3[0, 2] == 0);assert(i3x3[1, 2] == 0);assert(i3x3[2, 2] == 1);
}


/// ditto
auto congeal(A)(auto ref A mat, size_t r, size_t c)
if(isAbstractMatrix!A)
in{
    assert(A.inferSize(r, c).isValid);
}
body{
    static struct Result()
    {
        @property size_t rows() const { return _rs; }
        @property size_t cols() const { return _cs; }

        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _mat[i, j];
        }


      static if(carbon.linear.hasAssignableElements!A)
      {
        void opIndexAssign(E)(E e, size_t i, size_t j)
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            _mat[i, j] = e;
        }
      }

        mixin(defaultExprOps!(false));

        size_t _rs, _cs;
        A _mat;
    }


    return Result!()(r, c, mat);
}


///
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    static struct I{

        size_t opIndex(size_t i, size_t j) inout { return i == j ? 1  : 0;}

        static InferredResult inferSize(Msize_t r, Msize_t c)
        {
            if(r == wild && c == wild)
                return InferredResult(false);
            else if(isEqOrEitherEqX(r, c, wild))
                return InferredResult(true, max(r, c), max(r, c));
            else
                return InferredResult(false);
        }

        mixin(defaultExprOps!(true));
    }

    static assert(!isNarrowMatrix!I);
    static assert(isAbstractMatrix!I);
    static assert( I.inferSize(wild, 1).isValid);
    static assert( I.inferSize(3, 3).isValid);
    static assert(!I.inferSize(1, 3).isValid);

    I id;
    auto i3x3 = id.congeal(3, 3);
    static assert(isNarrowMatrix!(typeof(i3x3)));
    static assert(hasDynamicRows!(typeof(i3x3)));
    static assert(hasDynamicColumns!(typeof(i3x3)));
    assert(i3x3.rows == 3);
    assert(i3x3.cols == 3);
    assert(i3x3[0, 0] == 1);assert(i3x3[1, 0] == 0);assert(i3x3[2, 0] == 0);
    assert(i3x3[0, 1] == 0);assert(i3x3[1, 1] == 1);assert(i3x3[2, 1] == 0);
    assert(i3x3[0, 2] == 0);assert(i3x3[1, 2] == 0);assert(i3x3[2, 2] == 1);
}


/**
DynamicMatrixをある大きさへ固定します。
*/
auto congeal(Msize_t rs, Msize_t cs, A)(auto ref A mat)
//if(!isAbstractMatrix!A && (hasDynamicRows!A || rs == A.rows) || (hasDynamicColumns!A || cs == A.cols))
if(is(typeof({
    static assert(!isAbstractMatrix!A);
  static if(hasStaticRows!A)
    static assert(rs == staticRows!A);
  static if(hasStaticCols!A)
    static assert(cs == staticCols!A);
  })))
in{
    assert(mat.rows == rs);
    assert(mat.cols == cs);
}
body{
    static struct Result()
    {
        enum rows = rs;
        enum cols = cs;


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _mat[i, j];
        }


        static if(carbon.linear.hasAssignableElements!A)
        {
          void opIndexAssign(E)(E e, size_t i, size_t j)
          in{
              assert(i < rows);
              assert(j < cols);
          }
          body{
              _mat[i, j] = e;
          }
        }


        mixin(defaultExprOps!(false));

      private:
        A _mat;
    }

    return Result!()(mat);
}


/// ditto
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    static struct D{
        size_t rows;
        size_t cols;

        size_t opIndex(size_t i, size_t j) inout {return i + j;}

        mixin(defaultExprOps!(false));
    }
    static assert(isNarrowMatrix!D);
    static assert(hasDynamicRows!D);
    static assert(hasDynamicColumns!D);

    D d3x3 = D(3, 3);
    auto s3x3 = d3x3.congeal!(3, 3)();
    static assert(isNarrowMatrix!(typeof(s3x3)));
    static assert(s3x3.rows == 3);
    static assert(s3x3.cols == 3);
    assert(s3x3[0, 0] == 0); assert(s3x3[1, 0] == 1); assert(s3x3[2, 0] == 2);
    assert(s3x3[0, 1] == 1); assert(s3x3[1, 1] == 2); assert(s3x3[2, 1] == 3);
    assert(s3x3[0, 2] == 2); assert(s3x3[1, 2] == 3); assert(s3x3[2, 2] == 4);
}


///
auto matrix(size_t rs, size_t cs, alias f, S...)(S sizes)
if(is(typeof(f(0, 0))) && S.length == ((rs == 0) + (cs == 0)) && (S.length == 0 || is(CommonType!S : size_t)))
{
    static struct Result()
    {
      static if(rs)
        enum rows = rs;
      else{
        private size_t _rs;
        @property size_t rows() const { return _rs; }
      }

      static if(cs)
        enum cols = cs;
      else{
        private size_t _cs;
        @property size_t cols() const { return _cs; }
      }


        auto ref opIndex(size_t i, size_t j) const
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return f(i, j);
        }


        mixin(defaultExprOps!(false));
    }

    static if(S.length == 0)
      return Result!()();
    else static if(S.length == 1)
      return Result!()(sizes[0]);
    else static if(S.length == 2)
      return Result!()(sizes[0], sizes[1]);
}


auto matrix(alias f)(size_t r, size_t c)
if(is(typeof(f(0, 0))))
{
    return matrix!(0, 0, f)(r, c);
}


unittest{
    auto m = matrix!(2, 3, (i, j) => i * 3 + j);
    static assert(isNarrowMatrix!(typeof(m)));
    static assert(hasStaticRows!(typeof(m)));
    static assert(hasStaticCols!(typeof(m)));
    static assert(m.rows == 2);
    static assert(m.cols == 3);
    assert(m[0, 0] == 0); assert(m[0, 1] == 1); assert(m[0, 2] == 2);
    assert(m[1, 0] == 3); assert(m[1, 1] == 4); assert(m[1, 2] == 5);


    auto md = matrix!((i, j) => i * 3 + j)(2, 3);
    assert(m == md);
}


auto matrix(alias f)()
{
    static struct Result()
    {


        static InferredResult inferSize(Msize_t r, Msize_t c)
        {
            if(r == wild && c == wild)
                return  InferredResult(false);
            else if(r == wild || c == wild)
                return InferredResult(true, max(r, c), max(r, c));
            else
                return InferredResult(true, r, c);
        }


        auto ref opIndex(size_t i, size_t j) const { return f(i, j); }


        mixin(defaultExprOps!(true));
    }

      return Result!()();
}
unittest{
    auto mi = matrix!((i, j) => i * 3 + j);
    static assert(isAbstractMatrix!(typeof(mi)));
    assert(mi == matrix!((i, j) => i * 3 + j)(2, 3));
}


/**
内部で2次元配列を持つ行列です
*/
struct DMatrix(T, Msize_t rs = dynamic, Msize_t cs = dynamic, Major mjr = Major.row)
{
    enum bool isColumnMajor = mjr == Major.column;
    enum bool isRowMajor    = mjr == Major.row;
    enum major = mjr;


    this(M)(auto ref M m)
    if(!is(M == typeof(this)))
    {
      static if(isMatrix!M)
        this.noAlias = m;
      else
        this.opAssign(m);
    }


    static if(rs != dynamic)
    {
        enum size_t rows = rs;
    }
    else
    {
        @property
        size_t rows() const
        {
          static if(cs == 1)
            return _array.length;
          else static if(isColumnMajor)
          {
            if(this.tupleof[0].length)
                return this.tupleof[0][0].length;
            else
                return 0;
          }
          else
            return this.tupleof[0].length;
        }


        @property
        void rows(size_t newSize)
        {
          static if(rs == 1)
            return _array.length;
          else static if(isColumnMajor)
          {
            foreach(ref e; _array)
              e.length = newSize;
          }
          else
            _array.length = newSize;
        }
    }

    static if(cs != dynamic)
    {
        enum size_t cols = cs;
    }
    else
    {
        @property
        size_t cols() const
        {
          static if(rs == 1)
            return _array.length;
          else static if(isRowMajor){
            if(this.tupleof[0].length)
                return this.tupleof[0][0].length;
            else
                return 0;
          }
          else
            return this.tupleof[0].length;
        }


        @property
        void cols(size_t newSize)
        {
          static if(rs == 1)
            return _array.length = newSize;
          else static if(isRowMajor)
          {
            foreach(ref e; _array)
              e.length = newSize;
          }
          else
            _array.length = newSize;
        }
    }


    auto ref opIndex(size_t i, size_t j) inout
    in{
        assert(i < rows);
        assert(j < cols);
    }
    body{
      static if(rs == 1 || cs == 1)
        return _array[i+j];
      else static if(isRowMajor)
        return _array[i][j];
      else
        return _array[j][i];
    }


    mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.opAssign, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
    //mixin(defaultExprOps!(false));


    void opAssign(M)(auto ref M mat)
    if(!is(typeof(this) == M) && isValidOperator!(typeof(this), "=", M))
    in{
      static if(rs && hasDynamicRows!M)
        assert(this.rows == mat.rows);

      static if(cs && hasDynamicColumns!M)
        assert(this.cols == mat.cols);

      static if(isAbstractMatrix!M)
        assert(mat.inferSize(this.rows, this.cols).isValid);
    }
    body
    {
      static if(isAbstractMatrix!M)
      {
        immutable rl = this.rows,
                  cl = this.cols;
      }
      else
      {
        immutable rl = mat.rows,
                  cl = mat.cols;
      }

        immutable n = rl * cl;

        if(_buffer.length < n)
            _buffer.length = n;

        foreach(i; 0 .. rl)
            foreach(j; 0 .. cl)
            {
                static if(major == Major.row)
                    _buffer[i * cl + j] = mat.at(i, j);
                else
                    _buffer[j * rl + i] = mat.at(i, j);
            }

      static if(rs == dynamic)
        this.rows = rl;

      static if(cs == dynamic)
        this.cols = cl;

      static if(rs == 1 || cs == 1)
        _array[] = _buffer[0 .. n][];
      else{
        foreach(i; 0 .. _array.length)
            _array[i][] = _buffer[i * _array[0].length .. (i+1) * _array[0].length][];
      }
    }


    void opAssign(X)(X m)
    if(!isNarrowMatrix!X && isRandomAccessRange!X && (rs || !isInfinite!X)
                   && isRandomAccessRange!(std.range.ElementType!X)
                   && (cs || !isInfinite!(std.range.ElementType!X))
                   && isAssignable!(T, std.range.ElementType!X))
    {
        if(m.length && m[0].length){
          static if(rs == dynamic){
            if(m.length != this.rows)
                this.rows = m.length;
          }
            
          static if(cs == dynamic){
            if(m[0].length != this.cols)
                this.cols = m[0].length;
          }

            foreach(i; 0 .. this.rows)
                foreach(j; 0 .. this.cols)
                    this[i, j] = m[i][j];
        }
    }


    void opAssign(X)(X m)
    if(!isNarrowMatrix!X && isRandomAccessRange!X && isAssignable!(T, std.range.ElementType!X))
    {
        foreach(i; 0 .. this.rows)
            foreach(j; 0 .. this.cols)
                this[i, j] = m[i * this.cols + j];
    }


  static if(rs == 1 || cs == 1)
  {
    void opAssign(Array)(Array arr)
    if(!isNarrowMatrix!Array && isAssignable!(T, typeof(arr[size_t.init])))
    {
        foreach(i; 0 .. this.length)
            this[i] = arr[i];
    }
  }


    @property
    void noAlias(M)(auto ref M mat)
    if(isValidOperator!(typeof(this), "=", M) && ((!rs || !hasStaticRows!M) ||    is(typeof({static assert(this.rows == M.rows);})))
                                              && ((!cs || !hasStaticCols!M) || is(typeof({static assert(this.cols == M.cols);}))))
    in{
      static if(rs != dynamic)
        assert(this.rows == mat.rows);

      static if(cs != dynamic)
        assert(this.cols == mat.cols);
    }
    body{
      static if(is(typeof(this) == M))
        this = mat;
      else
      {
        immutable rl = mat.rows,
                  cl = mat.cols,
                  n = rl * cl;

      static if(is(typeof(_array) == T[]))
      {
        if(_array.length < n)
            _array.length = n;
      }
      else
      {
        immutable x = (major == Major.row) ? rl : cl,
                  y = (major == Major.row) ? cl : rl;

        if(_array.length < x)
            _array.length = x;

        foreach(ref e; _array)
            if(e.length < y)
                e.length = y;
      }

        static if(rs == dynamic)
          this.rows = rl;

        static if(cs == dynamic)
          this.cols = cl;

        foreach(i; 0 .. rl)
            foreach(j; 0 .. cl)
            {
              static if(rs == 1 || cs == 1)
                _array[i+j] = mat.at(i, j);
              else static if(major == Major.row)
                  _array[i][j] = mat.at(i, j);
              else
                  _array[j][i] = mat.at(i, j);
            }
      }
    }


    @property
    auto reference() inout
    {
        return this;
    }


  private:
  static if(rs == 1 || cs == 1)
  {
    T[] _array;
  }
  else
  {
    T[][] _array;
  }

  static:
    T[] _buffer;
}

unittest{
    DMatrix!float m = 
    [[1, 2, 3],
     [4, 5, 6]];

     assert(m.rows == 2);
     assert(m.cols == 3);

     assert(m[0, 0] == 1);
     assert(m[0, 1] == 2);
     assert(m[0, 2] == 3);
     assert(m[1, 0] == 4);
     assert(m[1, 1] == 5);
     assert(m[1, 2] == 6);
}


DMatrix!(T, r, c, mjr) matrix(T, Msize_t r = dynamic, Msize_t c = dynamic, Major mjr = Major.row, size_t N)(size_t[N] size...)
if(N == (r == dynamic) + (c == dynamic))
{
    typeof(return) dst;

    static if(r != dynamic)
        immutable size_t rs = r;
    else
        immutable size_t rs = size[0];

    static if(c != dynamic)
        immutable size_t cs = c;
    else
        immutable size_t cs = size[$-1];

    immutable h = mjr == Major.row ? rs : cs,
              w = mjr == Major.row ? cs : rs;

    static if(r == 1 || c == 1)
        dst._array = new T[h * w];
    else
        dst._array = new T[][](h, w);

    return dst;
}

unittest{
    foreach(major; TypeTuple!(Major.row, Major.column))
    {
        auto mr23 = matrix!(int, 2, 4, major)();
        static assert(isNarrowMatrix!(typeof(mr23)));
        static assert(hasStaticRows!(typeof(mr23)));
        static assert(hasStaticCols!(typeof(mr23)));
        static assert(mr23.rows == 2);
        static assert(mr23.cols == 4);

        auto mr2_ = matrix!(int, 2, dynamic, major)(4);
        static assert(isNarrowMatrix!(typeof(mr2_)));
        static assert(hasStaticRows!(typeof(mr2_)));
        static assert(hasDynamicColumns!(typeof(mr2_)));
        static assert(mr2_.rows == 2);
        assert(mr2_.cols == 4);

        auto mr_2 = matrix!(int, dynamic, 2, major)(4);
        static assert(isNarrowMatrix!(typeof(mr_2)));
        static assert(hasDynamicRows!(typeof(mr_2)));
        static assert(hasStaticCols!(typeof(mr_2)));
        assert(mr_2.rows == 4);
        static assert(mr_2.cols == 2);

        auto mr__ = matrix!(int, dynamic, dynamic, major)(2, 4);
        static assert(isNarrowMatrix!(typeof(mr__)));
        static assert(hasDynamicRows!(typeof(mr__)));
        static assert(hasDynamicColumns!(typeof(mr__)));
        assert(mr__.rows == 2);
        assert(mr__.cols == 4);
    }
}


DMatrix!(T, r, c, mjr) matrix(size_t r, size_t c, Major mjr = Major.row, T)(T[] arr)
if(r != 0 || c != 0)
in{
  static if(r != 0 && c != 0)
    assert(arr.length == r * c);
  else{
    assert(!(arr.length % r + c));
  }
}
body{
    static if(r == 1 || c == 1)
    {
      typeof(return) dst;
      dst._array = arr;
      return dst;
    }
    else
    {
      immutable rs = r == 0 ? arr.length / c : r;
      immutable cs = c == 0 ? arr.length / r : c;

      immutable h = mjr == Major.row ? rs : cs,
                w = mjr == Major.row ? cs : rs;

      typeof(return) dst;
      dst._array.length = h;
      foreach(i; 0 .. h)
        dst._array[i] = arr[i * w .. (i+1) * w];

      return dst;
    }
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto mr = matrix!(2, 3)([0, 1, 2, 3, 4, 5]);
    static assert(isNarrowMatrix!(typeof(mr)));
    static assert(hasStaticRows!(typeof(mr)));
    static assert(hasStaticCols!(typeof(mr)));
    static assert(mr.rows == 2);
    static assert(mr.cols == 3);
    assert(mr[0, 0] == 0); assert(mr[0, 1] == 1); assert(mr[0, 2] == 2);
    assert(mr[1, 0] == 3); assert(mr[1, 1] == 4); assert(mr[1, 2] == 5);

    mr[0, 0] = 10;
    assert(mr[0, 0] == 10); assert(mr[0, 1] == 1); assert(mr[0, 2] == 2);
    assert(mr[1, 0] ==  3); assert(mr[1, 1] == 4); assert(mr[1, 2] == 5);

    mr = matrix!(2, 3, (i, j) => cast(int)((i*3+j)*2));
    assert(mr[0, 0] == 0); assert(mr[0, 1] == 2); assert(mr[0, 2] == 4);
    assert(mr[1, 0] == 6); assert(mr[1, 1] == 8); assert(mr[1, 2] == 10);

    auto mc = matrix!(2, 3, Major.column)([0, 1, 2, 3, 4, 5]);
    static assert(isNarrowMatrix!(typeof(mc)));
    static assert(hasStaticRows!(typeof(mc)));
    static assert(hasStaticCols!(typeof(mc)));
    static assert(mc.rows == 2);
    static assert(mc.cols == 3);
    assert(mc[0, 0] == 0); assert(mc[0, 1] == 2); assert(mc[0, 2] == 4);
    assert(mc[1, 0] == 1); assert(mc[1, 1] == 3); assert(mc[1, 2] == 5);

    mc[0, 0] = 10;
    assert(mc[0, 0] == 10); assert(mc[0, 1] == 2); assert(mc[0, 2] == 4);
    assert(mc[1, 0] ==  1); assert(mc[1, 1] == 3); assert(mc[1, 2] == 5);

    mc = matrix!(2, 3, (i, j) => cast(int)((i*3+j)*2));
    assert(mc[0, 0] == 0); assert(mc[0, 1] == 2); assert(mc[0, 2] == 4);
    assert(mc[1, 0] == 6); assert(mc[1, 1] == 8); assert(mc[1, 2] == 10);
}


DMatrix!(T, wild, wild, mjr) matrix(Major mjr = Major.row, T)(T[] arr, size_t r, size_t c)
in{
  if(r != 0 && c != 0)
    assert(arr.length == r * c);
  else if(r != 0 || c != 0)
    assert(!(arr.length % (r + c)));
  else
    assert(0);
}
body{
    immutable rs = r == 0 ? arr.length / c : r;
    immutable cs = c == 0 ? arr.length / r : c;

    immutable h = mjr == Major.row ? rs : cs,
              w = mjr == Major.row ? rs : cs;

    typeof(return) dst;
    dst._array.length = h;
    foreach(i; 0 .. h)
      dst._array[i] = arr[i * w .. (i+1) * w];

    return dst;
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto mr = matrix!(2, 3)([0, 1, 2, 3, 4, 5]);
    static assert(isNarrowMatrix!(typeof(mr)));
    static assert(hasStaticRows!(typeof(mr)));
    static assert(hasStaticCols!(typeof(mr)));
    static assert(mr.rows == 2);
    static assert(mr.cols == 3);
    assert(mr[0, 0] == 0); assert(mr[0, 1] == 1); assert(mr[0, 2] == 2);
    assert(mr[1, 0] == 3); assert(mr[1, 1] == 4); assert(mr[1, 2] == 5);


    auto mc = matrix!(2, 3, Major.column)([0, 1, 2, 3, 4, 5]);
    static assert(isNarrowMatrix!(typeof(mc)));
    static assert(hasStaticRows!(typeof(mc)));
    static assert(hasStaticCols!(typeof(mc)));
    static assert(mc.rows == 2);
    static assert(mc.cols == 3);
    assert(mc[0, 0] == 0); assert(mc[0, 1] == 2); assert(mc[0, 2] == 4);
    assert(mc[1, 0] == 1); assert(mc[1, 1] == 3); assert(mc[1, 2] == 5);
}


auto matrix(Major mjr = Major.row, T, size_t N, size_t M)(ref T[M][N] arr)
{
  static if(mjr == Major.row)
    DMatrix!(T, N, M, mjr) dst;
  else
    DMatrix!(T, M, N, mjr) dst;

    dst._array.length = N;
    foreach(i; 0 .. N)
      dst._array[i] = arr[i];
    return dst;
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    int[3][2] arr = [[0, 1, 2], [3, 4, 5]];

    auto mr = matrix(arr);
    static assert(isNarrowMatrix!(typeof(mr)));
    static assert(hasStaticRows!(typeof(mr)));
    static assert(hasStaticCols!(typeof(mr)));
    static assert(mr.rows == 2);
    static assert(mr.cols == 3);
    assert(mr[0, 0] == 0); assert(mr[0, 1] == 1); assert(mr[0, 2] == 2);
    assert(mr[1, 0] == 3); assert(mr[1, 1] == 4); assert(mr[1, 2] == 5);
}

auto matrix(Major mjr = Major.row, A)(A mat)
if(isNarrowMatrix!A && !isAbstractMatrix!A)
{
  static if(hasStaticRows!A && hasStaticCols!A)
    DMatrix!(ElementType!A, A.rows, A.cols, mjr) dst;
  else static if(hasStaticRows!A)
    DMatrix!(ElementType!A, A.rows, wild, mjr) dst;
  else static if(hasStaticCols!A)
    DMatrix!(ElementType!A, wild, A.cols, mjr) dst;
  else
    DMatrix!(ElementType!A, wild, wild, mjr) dst;

    dst.noAlias = mat;
    return dst;
}


auto matrix(Msize_t rs, Msize_t cs = 0, Major mjr = Major.row, A)(A mat)
if(isAbstractMatrix!A && A.inferSize(rs, cs).isValid)
{
    return mat.congeal!(rs, cs).matrix();
}


auto matrix(Major mjr = Major.row, A)(A mat, size_t r, size_t c = 0)
if(isAbstractMatrix!A)
in{
  assert(A.inferSize(r, c).isValid);
}
body{
  return mat.congeal(r, c).matrix();
}


/**
要素がメモリ上に連続して存在するような行列
*/
struct SMatrix(T, Msize_t rs = 0, Msize_t cs = 0, Major mjr = Major.row)
if(rs >= 0 && cs >= 0)
{
    enum bool isColumnMajor = mjr == Major.column;
    enum bool isRowMajor    = mjr == Major.row;
    enum major = mjr;
    enum size_t rows = rs;
    enum size_t cols = cs;


    this(M)(auto ref M mat)
    if(!is(M == typeof(this)))
    {
      static if(isNarrowMatrix!M)
        this.noAlias = mat;
      else
        this.opAssign(mat);
    }


    //@disable this(this);


    auto ref opIndex(size_t i, size_t j) inout
    in{
        assert(i < rows);
        assert(j < cols);
    }
    body{
        static if(major == Major.row)
            return _array[i * cols + j];
        else
            return _array[j * rows + i];
    }


    @property
    auto array() pure nothrow @safe inout
    {
        return _array[];
    }


    void opAssign(M)(auto ref M mat)
    if(isValidOperator!(typeof(this), "=", M))
    {
        auto buffer = {
            if(__ctfe)
                return new T[rs * cs];
            else
                return SMatrix._buffer[];
        }();

        foreach(i; 0 .. rows)
            foreach(j; 0 .. cols)
            {
                static if(major == Major.row)
                    buffer[i * cols + j] = mat.at(i, j);
                else
                    buffer[j * rows + i] = mat.at(i, j);
            }
        
        _array[] = buffer[];
    }


    @property
    void noAlias(M)(auto ref M mat)
    if(isValidOperator!(typeof(this), "=", M))
    {
        foreach(i; 0 .. rows)
            foreach(j; 0 .. cols)
            {
                static if(major == Major.row)
                    _array[i * cols + j] = mat[i, j];
                else
                    _array[j * rows + i] = mat[i, j];
            }
    }


    //@property
    //auto stackRef() inout pure nothrow @safe
    //{
    //    //Issue: 9983 http://d.puremagic.com/issues/show_bug.cgi?id=9983
    //    //return matrix!(rows, cols)(_array[]);
    //    return _referenceImpl(this);
    //}


    //alias reference this;

    mixin(ExpressionOperators!(ETOSpec.all & ~ETOSpec.opAssign, mixin(is(typeof({enum _unused_ = rows;})) ? "this.rows" : "wild"), mixin(is(typeof({enum _unused_ = cols;})) ? "this.cols" : "wild")).stringMixin);
    //mixin(defaultExprOps!(false));


  private:
    T[rs * cs] _array;

  static:
    T[rs * cs] _buffer;


    //// Workaround of issue 9983 http://d.puremagic.com/issues/show_bug.cgi?id=9983
    //auto _referenceImpl(M)(ref M m) @trusted pure nothrow
    //{
    //    static if(is(M == immutable(M)))
    //        return _referenceImplImmutable(cast(immutable(T)[])m._array[]);
    //    else static if(is(M == const(M)))
    //        return _referenceImplConst(cast(const(T)[])m._array[]);
    //    else
    //        return _referenceImplMutable(cast(T[])m._array[]);
    //}


    //auto _referenceImplMutable(E)(E[] arr)
    //{
    //    return arr.matrix!(rows, cols);
    //}


    //auto _referenceImplConst(E)(const E[] arr)
    //{
    //    return arr.matrix!(rows, cols);
    //}


    //auto _referenceImplImmutable(E)(immutable E[] arr)
    //{
    //    return arr.matrix!(rows, cols);
    //}
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 3, 3) m;
    m[0, 0] = 0; m[0, 1] = 1; m[0, 2] = 2;
    m[1, 0] = 1; m[1, 1] = 2; m[1, 2] = 3;
    m[2, 0] = 2; m[2, 1] = 3; m[2, 2] = 4;

    auto mref = m.pref;

    SMatrix!(int, 3, 3) m2 = mref * mref;
    mref = mref * mref;
    assert(mref == m2);
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 2, 2, Major.row) mr;    // 2x2, int型, 行優先
    assert(mr.array.equal([0, 0, 0, 0]));       // 初期化される

    mr[0, 1] = 1;
    mr[1, 0] = 2;
    mr[1, 1] = 3;
    assert(mr.array.equal([0, 1, 2, 3]));       // 行優先順


    SMatrix!(int, 2, 2, Major.column) mc; // 2x2, int型, 列優先
    assert(mc.array.equal([0, 0, 0, 0]));       // 初期化される

    mc[0, 1] = 1;
    mc[1, 0] = 2;
    mc[1, 1] = 3;
    assert(mc.array.equal([0, 2, 1, 3]));       // 列優先順


    SMatrix!(int, 2, 2, Major.row) minit = mc;
    assert(minit.array.equal([0, 1, 2, 3]));   // 全要素12で初期化されている
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 1, 3) m;
    m[0] = 3;
    assert(m[0] == 3);
    static assert(m.length == 3);
    assert(m[$-1] == 0);
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 2, 2) m;
    auto rm = m.pref;

    assert(rm + rm == m.pref + m);
    assert(rm - rm == m.pref - m);
    assert(rm * rm == m.pref * m);

    m = [[1, 2], [2, 3]];

    SMatrix!(int, 2, 2) m2 = m;
    m.noAlias = m2.pref + m2;
    assert(m[0, 0] == 2);
}


unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    alias SRVector!(int, 3) R;
    R rv1;
    static assert(rv1.rows == 1);
    static assert(rv1.cols == 3);
    static assert(rv1.length  == 3);

    rv1[0] = 3;
    assert(rv1[0] == 3);
    assert(rv1[1] == 0);
    assert(rv1[2] == 0);
    rv1 += 3;
    assert(rv1[0] == 6);
    assert(rv1[1] == 3);
    assert(rv1[2] == 3);
    rv1[0] += 3;
    assert(rv1[0] == 9);
    assert(rv1[1] == 3);
    assert(rv1[2] == 3);

    SRVector!(int, 4) rv2;
    static assert(rv2.rows == 1);
    static assert(rv2.cols == 4);
    static assert(rv2.length  == 4);

    SCVector!(int, 3) cv1;
    static assert(cv1.rows == 3);
    static assert(cv1.cols == 1);
    static assert(cv1.length  == 3);

    SCVector!(int, 4) cv2;
    static assert(cv2.rows == 4);
    static assert(cv2.cols == 1);
    static assert(cv2.length  == 4);
}


///ditto
template SRVector(T, Msize_t size)
{
    alias SMatrix!(T, 1, size, Major.row) SRVector;
}

///ditto
template SCVector(T, Msize_t size)
{
    alias SMatrix!(T, size, 1, Major.column) SCVector;
}

///ditto
template SVector(T, Msize_t size)
{
    alias SCVector!(T, size) SVector;
}


/**
転置行列を返します。
*/
@property
auto transpose(A)(A mat)
if(isNarrowMatrix!A)
{
    static struct Transposed()
    {
      static if(isAbstractMatrix!A)
      {
        enum size_t rows = wild;
        enum size_t cols = wild;

        static InferredResult inferSize(Msize_t rs, Msize_t cs)
        {
            return A.inferSize(cs, rs);
        }
      }
      else
      {
        static if(hasStaticCols!A)
            enum size_t rows = A.cols;
        else
            @property auto ref rows() const { return _mat.cols; }

        static if(hasStaticRows!A)
            enum size_t cols = A.rows;
        else
            @property auto ref cols() const { return _mat.rows; }
      }


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _mat[j, i];
        }


      static if(carbon.linear.hasAssignableElements!A)
      {
        void opIndexAssign(E)(E e, size_t i, size_t j)
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            _mat[j, i] = e;
        }

        static if(isVector!A)
        {
            void opIndexAssign(E)(E e, size_t i)
            in{
                assert(i < this.length);
            }
            body{
                static if(is(typeof({static assert(rows == 1);})))
                    this[0 , i] = e;
                else
                    this[i, 0] = e;
            }
        }
      }

        mixin(defaultExprOps!(isAbstractMatrix!A));


        auto ref transpose() @property inout
        {
            return _mat;
        }


      private:
        A _mat;
    }


    return Transposed!()(mat);
}
unittest{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 2, 2) m;
    m = [[0, 1],
         [2, 3]];

    auto t = m.pref.transpose;
    assert(t[0, 0] == 0);
    assert(t[0, 1] == 2);
    assert(t[1, 0] == 1);
    assert(t[1, 1] == 3);
}
unittest{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SCVector!(int, 3) v;
    v[0] = 1; v[1] = 2; v[2] = 3;

    auto t = v.pref.transpose;
    t[0] = 1;
    t[1] = 2;
    t[2] = 3;
    //t = [1, 2, 3];

    assert(t.rows == 1);
    assert(t.cols == 3);


    static assert(is(typeof(v.pref) == typeof(t.transpose)));
}


/**
エルミート行列を返します
*/
auto hermitian(A)(A mat)
if(isNarrowMatrix!A)
{
    static struct Hermitian()
    {
      static if(isAbstractMatrix!A)
      {
        enum size_t rows = wild;
        enum size_t cols = wild;

        static InferredResult inferSize(Msize_t rs, Msize_t cs)
        {
            return A.inferSize(cs, rs);
        }
      }
      else
      {
        static if(hasStaticCols!A)
            enum size_t rows = A.cols;
        else
            @property auto ref rows() inout { return _mat.cols; }

        static if(hasStaticRows!A)
            enum size_t cols = A.rows;
        else
            @property auto ref cols() inout { return _mat.rows; }
      }


        auto opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _mat[j, i].conj;
        }


        mixin(defaultExprOps!(isAbstractMatrix!A));


        auto ref hermitian() @property inout
        {
            return _mat;
        }


      private:
        A _mat;
    }

    return Hermitian!()(mat);
}
unittest{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(cfloat, 2, 2) m;
    m = [[0+0i, 1+1i],
         [2+2i, 3+3i]];

    auto t = m.pref.hermitian;
    assert(t[0, 0] == 0-0i);
    assert(t[0, 1] == 2-2i);
    assert(t[1, 0] == 1-1i);
    assert(t[1, 1] == 3-3i);
}



/**

*/
auto toRange(A)(A mat)
if(isNarrowMatrix!A)
{
    static struct ToRange()
    {
        static struct Element()
        {
            @property auto ref front() { return _mat[_r, _cf]; }

            @property auto ref back() { return _mat[_r, _cb]; }

            auto ref opIndex(size_t i) { i += _cf; return _mat[_r, i]; }

            void popFront() { ++_cf; }
            void popBack() { --_cb; }

            @property bool empty() { return _cf == _cb; }
            @property size_t length() { return _cb - _cf; }
            alias opDollar = length;

            @property auto save() { return this; }

            auto opSlice() { return this.save; }
            auto opSlice(size_t i, size_t j) { return typeof(this)(_mat, _r, _cf + i, j); }


          private:
            A _mat;
            size_t _r;
            size_t _cf = 0;
            size_t _cb;
        }


        @property auto front() { return Element!()(this._mat, _rf, 0, this._mat.cols); }

        @property auto back() { return Element!()(this._mat, _rb, 0, this._mat.cols); }

        auto opIndex(size_t i) { i += _rf; return Element!()(this._mat, i, 0, this._mat.cols);}

        void popFront() { ++_rf; }
        void popBack() { --_rb; }

        @property bool empty() { return _rf == _rb; }
        @property size_t length() { return _rb - _rf; }
        alias opDollar = length;

        @property auto save() { return this; }

        auto opSlice() { return this.save; }
        auto opSlice(size_t i, size_t j) { return typeof(this)(_mat, _rf + i, j); }

      private:
        A _mat;
        size_t _rf = 0;
        size_t _rb;
    }


    return ToRange!()(mat, 0, mat.rows);
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 3, 3) rm33;
    rm33[0, 0] = 1; rm33[0, 1] = 2; rm33[0, 2] = 3;
    assert(equal!"equal(a, b)"(rm33.stackRef.toRange, [[1, 2, 3], [0, 0, 0], [0, 0, 0]]));

    SMatrix!(int, 1, 1) rm11;
    assert(equal!"equal(a, b)"(rm11.stackRef.toRange, [[0]]));
}


/**
行列をレンジにします
*/
auto toFlatten(A)(A mat)
if(isNarrowMatrix!A && !isAbstractMatrix!A)
{
    alias ElementType!A E;

    static struct ToFlatten()
    {
        @property
        auto ref front()
        {
            return _mat[_f / _mat.cols, _f % _mat.cols];
        }


        @property
        auto ref back()
        {
            return _mat[_b / _mat.cols, _b % _mat.cols];
        }


        auto ref opIndex(size_t i) inout
        in{
            assert(_f + i < _b);
        }body{
            i += _f;
            return _mat[i / _mat.cols, i % _mat.cols];
        }


        static if(hasAssignableElements!A)
        {
            @property
            void front(E v)
            {
                _mat[_f / _mat.cols, _f % _mat.cols] = v;
            }


            @property
            void back(E v)
            {
                _mat[_b / _mat.cols, _b % _mat.cols] = v;
            }


            void opIndexAssign(E v, size_t i)
            in{
                assert(_f + i < _b);
            }
            body{
                i += _f;
                _mat[i / _mat.cols, i % _mat.cols] = v;
            }
        }


        @property
        bool empty() pure nothrow @safe const
        {
            return _f >= _b;
        }


        void popFront() pure nothrow @safe
        {
            _f++;
        }


        void popBack() pure nothrow @safe
        {
            _b--;
        }


        @property
        size_t length() pure nothrow @safe const
        {
            return _b - _f;
        }


        alias length opDollar;


        @property
        typeof(this) save() pure nothrow @safe
        {
            return this;
        }


    private:
        A _mat;
        size_t _f, _b;
    }

    return ToFlatten!()(mat, 0, mat.rows * mat.cols);
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    SMatrix!(int, 3, 3, Major.row) rm33;
    rm33[0, 0] = 1; rm33[0, 1] = 2; rm33[0, 2] = 3;
    //writeln(rm33.array.length;)
    assert(rm33.array == [1, 2, 3, 0, 0, 0, 0, 0, 0]);

    alias Rt1 = typeof(toFlatten(rm33));
    static assert(isRandomAccessRange!(Rt1));
    static assert(std.range.hasLvalueElements!(Rt1));
    static assert(std.range.hasAssignableElements!(Rt1));
    static assert(hasLength!(Rt1));
    assert(equal(rm33.toFlatten, rm33.array));

    SMatrix!(int, 3, 3, Major.column) cm33;
    cm33[0, 0] = 1; cm33[0, 1] = 2; cm33[0, 2] = 3;
    assert(cm33.array == [1, 0, 0, 2, 0, 0, 3, 0, 0]);
    assert(equal(cm33.toFlatten, [1, 2, 3, 0, 0, 0, 0, 0, 0]));
}



/**
レンジから行列を作ります。
*/
auto toMatrix(Msize_t rs, Msize_t cs, Major mjr = Major.row, R)(R range)
if(isRandomAccessRange!R && isNotVectorOrMatrix!(Unqual!(std.range.ElementType!R)) && (mjr == Major.row ? (cs != wild) : (rs != wild)))
{
  //static if(mjr == Major.column)
    //return range.toMatrix!(cs, rs, Major.row).transpose;
  //else
  //{
    alias E = Unqual!(std.range.ElementType!R);

    static struct ToMatrix()
    {
      static if(rs != wild)
        enum size_t rows = rs;
      else
        auto ref rows() const @property
        {
            return _range.length / typeof(this).cols;
        }

      static if(cs != wild)
        enum size_t cols = cs;
      else
        auto ref cols() const @property
        {
            return _range.length / typeof(this).rows;
        }


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows || rows == 0);
            assert(j < cols || cols == 0);

          static if(hasLength!R && mjr == Major.row)
            assert(i * cols + j < this._range.length);

          static if(hasLength!R && mjr == Major.column)
            assert(j * rows + i < this._range.length);
        }
        body{
          static if(mjr == Major.row)
            return this._range[i * cols + j];
          else
            return this._range[j * rows + i];
        }


        mixin(defaultExprOps!(false));

      private:
        R _range;
    }

    return ToMatrix!()(range);
  //}
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto r = iota(4);
    auto mr = toMatrix!(2, 2)(r);
    assert(mr.toFlatten.equal([0, 1, 2, 3]));

    auto mc = r.toMatrix!(2, 2, Major.column);
    assert(mc.toFlatten.equal([0, 2, 1, 3]));
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto mem = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    auto mr = mem.toMatrix!(3, 3);
    static assert(isNarrowMatrix!(typeof(mr)));
    static assert(hasLvalueElements!(typeof(mr)));
    assert(mr.toFlatten.equal(mem[0 .. 9]));

    mem.length = 16;
    auto mc = mem.toMatrix!(4, 4, Major.column);
    static assert(isNarrowMatrix!(typeof(mr)));
    static assert(hasLvalueElements!(typeof(mr)));
    mc[3, 3] = 15;
    assert(mc.transpose.toFlatten.equal([0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                                            0, 0, 0, 0, 0, 15]));
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto mem = [0, 1, 2, 3];
    auto r1 = mem.toMatrix!(wild, 1, Major.row);
    assert(equal(r1.toFlatten, mem[0 .. 4]));

    mem ~= [4, 5];
    auto r2 = mem.toMatrix!(wild, 2, Major.row);
    assert(r2[2, 0] == 4);
    assert(r2[2, 1] == 5);

    auto c1 = mem.toMatrix!(1, wild, Major.column);
    assert(equal(c1.toFlatten, mem));
}



auto toMatrix(Msize_t rs, Msize_t cs, Major mjr = Major.row, R)(R range)
if(isRandomAccessRange!R && isRandomAccessRange!(Unqual!(std.range.ElementType!R)) && isNotVectorOrMatrix!(Unqual!(std.range.ElementType!(Unqual!(std.range.ElementType!R)))))
{
    static struct ToMatrix()
    {
      static if(rs != dynamic)
        enum size_t rows = rs;
      else
        auto ref rows() const @property
        {
          static if(mjr == Major.row)
            return _range.length;
          else
            return _range[0].length;
        }


      static if(cs != dynamic)
        enum size_t cols = cs;
      else
        auto ref cols() const @property
        {
          static if(mjr == Major.column)
            return _range.length;
          else
            return _range[0].length;
        }


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows || rows == 0);
            assert(j < cols || cols == 0);

          static if(hasLength!R)
            assert((mjr == Major.row ? i : j) < _range.length);

          static if(hasLength!(Unqual!(std.range.ElementType!R)))
            assert((mjr == Major.row ? j : i) < _range[i].length);
        }
        body{
          static if(mjr == Major.row)
            return _range[i][j];
          else
            return _range[j][i];
        }

        mixin(defaultExprOps!(false));

      private:
        R _range;
    }
  
    return ToMatrix!()(range);
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto arr = [[0, 1], [2, 3], [4, 5]];
    auto r1 = toMatrix!(3, 2, Major.row)(arr);
    static assert(isNarrowMatrix!(typeof(r1)));
    assert(equal!"equal(a, b)"(r1.toRange, arr));

    auto r2 = arr.toMatrix!(1, 1, Major.row);
    assert(r2[0] == 0);

    auto r3 = arr.toMatrix!(dynamic, 2, Major.row);
    assert(r3.congeal!(3, 2) == r1);

    auto r4 = arr.toMatrix!(2, dynamic, Major.row);
    assert(equal(r4.congeal!(2, 2)().toFlatten(), [0, 1, 2, 3]));

    auto r5 = arr.toMatrix!(dynamic, dynamic, Major.row);
    assert(r5 == r1);
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto arr = [[0, 1], [2, 3], [4, 5]];
    auto r1 = arr.toMatrix!(2, 3, Major.column);
    assert(equal!"equal(a, b)"(r1.transpose.toRange, arr));
    assert(r1[0, 0] == 0); assert(r1[0, 1] == 2); assert(r1[0, 2] == 4);
    assert(r1[1, 0] == 1); assert(r1[1, 1] == 3); assert(r1[1, 2] == 5);

    auto r2 = arr.toMatrix!(1, 1, Major.column);
    assert(r2[0] == 0);

    auto r3 = arr.toMatrix!(dynamic, 3, Major.column);
    assert(r3 == r1);

    auto r4 = arr.toMatrix!(2, dynamic, Major.column);
    assert(equal(r4.transpose.toFlatten, [0, 1, 2, 3, 4, 5]));

    auto r5 = arr.toMatrix!(dynamic, dynamic, Major.column);
    assert(r5 == r1);
}


/**
単位行列
*/
@property
auto identity(E)()if(isNotVectorOrMatrix!E)
{
    static struct Identity()
    {


        static InferredResult inferSize(Msize_t i, Msize_t j)
        {
            if(i < 0 && j < 0)
                return InferredResult(false);
            else if(i < 0 || j < 0)
                return InferredResult(true, max(i, j), max(i, j));
            else if(i == j)
                return InferredResult(true, i, j);
            else
                return InferredResult(false);
        }


        E opIndex(size_t i, size_t j) inout
        {
            return (i == j) ? (cast(E)1) : (cast(E)0);
        }

        mixin(defaultExprOps!(true));
    }

    return Identity!()();
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto id = identity!int;
    static assert(isAbstractMatrix!(typeof(id)));
    static assert(typeof(id).inferSize(4, 4).isValid);
    static assert(typeof(id).inferSize(wild, 2).isValid);
    static assert(!typeof(id).inferSize(1, 3).isValid);

    auto m1 = SMatrix!(int, 2, 2).init;
    m1.array[] = [0, 1, 2, 3];
    assert(equal((m1 * id).toFlatten, [0, 1, 2, 3]));

    auto id2 = id + id;
    static assert(isAbstractMatrix!(typeof(id2)));
    static assert(typeof(id2).inferSize(4, 4).isValid);


    auto id22 = id.congeal!(wild, 2);
    static assert(id22.rows == 2);
    static assert(id22.cols == 2);
    assert(equal(id22.toFlatten, [1, 0, 0, 1]));

    auto id3 = id22 * id;
    static assert(id3.rows == 2);
    static assert(id3.cols == 2);
    assert(equal(id3.toFlatten, [1, 0, 0, 1]));

    auto ins = id2.congeal!(2, 2);
    static assert(isNarrowMatrix!(typeof(ins)));
    assert(equal(ins.toFlatten, [2, 0, 0, 2]));
}


/**
全要素が1な行列を返します。
*/
@property
auto ones(E)()if(isNotVectorOrMatrix!E)
{
    static struct Ones()
    {


        E opIndex(size_t i, size_t j) inout
        {
            return cast(E)1;
        }


        static InferredResult inferSize(Msize_t i, Msize_t j)
        {
            if(i == wild && j == wild)
                return InferredResult(false);
            else if(i == wild || j == wild)
                return InferredResult(true, max(i, j), max(i, j));
            else
                return InferredResult(true, i, j);
        }


        mixin(defaultExprOps!(true));
    }

    static assert(isAbstractMatrix!(Ones!()));

    return Ones!().init;
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto m1 = ones!float;
    assert(m1[0, 1] == 1);

    auto m3 = m1 * 3;
    assert(m3[0, 1] == 3);

    auto m9 = m3 * 3;
    assert(m9[0, 1] == 9);
}


/**
部分行列を返します
*/
auto sub(alias rArray, alias cArray, A)(A mat)
if(isArray!(typeof(rArray)) && isArray!(typeof(cArray)) && isNarrowMatrix!A && !isAbstractMatrix!A
    && (hasDynamicRows!A || is(typeof({static assert(rArray.find!"a>=b"(A.rows).empty);})))
    && (hasDynamicColumns!A || is(typeof({static assert(cArray.find!"a>=b"(A.cols).empty);}))))
in{
    static if(hasDynamicRows!A)
        assert(rArray.find!"a>=b"(mat.rows).empty);
    static if(hasDynamicColumns!A)
        assert(cArray.find!"a>=b"(mat.cols).empty);
}
body{
  static if(rArray.length == 0 && cArray.length == 0)
    return mat;
  else
  {
    static struct Sub()
    {
      static if(rArray.length == 0)
        alias rows = _mat.rows;
      else
        enum rows = rArray.length;

      static if(cArray.length == 0)
        alias cols = _mat.cols;
      else
        enum cols = cArray.length;


        auto ref opIndex(size_t i, size_t j) inout
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
          static if(rArray.length && cArray.length)
            return _mat[rArray[i], cArray[j]];
          else static if(rArray.length)
            return _mat[rArray[i], j];
          else static if(cArray.length)
            return _mat[i, cArray[j]];
          else
            static assert(0);
        }


        mixin(defaultExprOps!(false));


      private:
        A _mat;
    }

    return Sub!()(mat);
  }
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto m1 = [[0, 1], [2, 3], [4, 5]].toMatrix!(3, 2, Major.row);
    auto s1 = m1.sub!([1, 2], [0]);
    static assert(s1.rows == 2);
    static assert(s1.cols == 1);

    assert(s1[0, 0] == 2);
    assert(s1[1, 0] == 4);


    auto m2 = [[0, 1], [2, 3], [4, 5]].toMatrix!(dynamic, dynamic, Major.row)();
    auto s2 = sub!((size_t[]).init, (size_t[]).init)(m2);
    assert(m1 == s2.congeal!(3, 2));


    auto m3 = identity!int.congeal!(2, 2)().sub!([0, 0, 0], [0, 0, 0])();
    assert(m3 == ones!int);
}


/**
swizzle : glm参照
*/
auto swizzle(A)(A mat) @property
if(isNarrowMatrix!A && !isAbstractMatrix!A)
{
    static struct Swizzle()
    {
        auto opDispatch(string exp)()
        if((isVector!A ? (isSwizzleExp(exp) && isSwizzlable!A(exp)) : false) || (isSliceExp(exp) && isSlicable!(A, exp)))
        {
            static struct SwizzleResult()
            {
              static if(isSwizzleExp(exp))
              {
                static if(A.cols == 1)
                {
                  enum size_t rows = exp.length;
                  enum size_t cols = 1;
                }
                else
                {
                  enum size_t rows = 1;
                  enum size_t cols = exp.length;
                }


                auto ref opIndex(size_t i, size_t j) inout
                in{
                    assert((i+j) < (rows+cols-1));
                }
                body{
                    immutable size_t s = swizzleType(exp) == 'a' ? exp[i] - 'a' : (exp[i] == 'w' ? 3 : (exp[i] - 'x'));

                  static if(cols == 1)
                    return _mat[s, 0];
                  else
                    return _mat[0, s];
                }
              }
              else      // isSliceExp
              {
                private enum _swizzleExpSpec = spec(exp);
                enum size_t rows = mixin(_swizzleExpSpec.cs);
                enum size_t cols = mixin(_swizzleExpSpec.rs);


                auto ref opIndex(size_t i, size_t j) inout
                in{
                    assert(i < rows);
                    assert(j < cols);
                }
                body{
                    immutable size_t r = mixin(_swizzleExpSpec.rb) + i,
                                     c = mixin(_swizzleExpSpec.cb) + j;

                    return _mat[r, c];
                }
              }


                mixin(defaultExprOps!(false));

              private:
                A _mat;
            }


            return SwizzleResult!()(_mat);
        }

      private:
        A _mat;

      static:

        bool isSwizzleExp(string str) pure nothrow @safe
        {
            char d;
            foreach(c; str)
                if(!(('a' <= c && c <= 'h') || (c == 'x' || c == 'y' || c == 'z' || c == 'w')))
                    return false;
                else if('a' <= c && c <= 'h'){
                    if(d == char.init)
                        d = 'a';
                    else if(d != 'a')
                        return false;
                }else{
                    if(d == char.init)
                        d = 'x';
                    else if(d != 'x')
                        return false;
                }

            return true;
        }
        unittest{
            assert(isSwizzleExp("aaaaaaa"));
            assert(isSwizzleExp("aaaahaa"));
            assert(!isSwizzleExp("aaaaiaa"));
            assert(!isSwizzleExp("aaxa"));
            assert(isSwizzleExp("xxxx"));
            assert(isSwizzleExp("xyzw"));
            assert(!isSwizzleExp("xyza"));
        }


        // pure nothrow @safeにするため
        string find_(string str, char c) pure nothrow @safe
        {
            while(str.length && str[0] != c)
                str = str[1 .. $];
            return str;
        }


        string until_(string str, char c) pure nothrow @safe
        {
            foreach(i; 0 .. str.length)
                if(str[i] == c)
                    return str[0 .. i];

            return str;
        }


        // for matrix, format: r<bias>c<bias>m<row>x<cols>
        alias ExpSpec = Tuple!(string, "rb", string, "cb", string, "rs", string, "cs");


        ExpSpec spec(string exp) pure nothrow @safe
        {
            ExpSpec spec = ExpSpec("0", "0", "", "");
            {
                auto t = until_(until_(find_(exp, 'r'), 'c'), 'm');
                if(t.length > 1)        //r<Num>の形式なので、rを加えて1文字以上無いといけない
                    spec.rb = t[1 .. $];
            }

            {
                auto t = until_(find_(exp, 'c'), 'm');
                if(t.length > 1)        //c<Num>の形式なので、rを加えて1文字以上無いといけない
                    spec.cb = t[1 .. $];
            }

            {
                auto t = until_(find_(exp, 'm'), 'x');
                if(t.length > 1)        //m<Num>の形式なので、mを加えて1文字以上無いといけない
                    spec.rs = t[1 .. $];
            }

            {
                auto t = find_(exp, 'x');
                if(t.length > 1)
                    spec.cs = t[1 .. $];
            }
            return spec;
        }
        unittest{
            assert(spec("r1c1m1x1") == tuple("1", "1", "1", "1"));
            assert(spec("r1_100c21m5x5") == tuple("1_100", "21", "5", "5"));
            assert(spec("m1x2") == tuple("0", "0", "1", "2"));
        }


        bool isSliceExp(string exp) pure nothrow @safe
        {
            bool isAllDigit(string str) pure nothrow @safe
            {
                if(str.length == 0)
                    return false;

                foreach(c; str)
                    if(!(c.isDigit || c == '_'))
                        return false;
                return true;
            }

            auto sp = spec(exp);
            return (exp[0] == 'm' || exp[0] == 'r' || exp[0] == 'c') && isAllDigit(sp.rb) && isAllDigit(sp.cb) && isAllDigit(sp.rs) && isAllDigit(sp.cs);
        }
        unittest{
            assert(isSliceExp("r1c1m1x1"));
            assert(isSliceExp("r1_100c21m5x5"));
            assert(isSliceExp("m1x2"));
            assert(!isSliceExp("m2m1"));
            assert(!isSliceExp("_2mx1"));
            assert(isSliceExp("c1m1x1"));
        }


        // for vec
        char swizzleType(string exp) pure nothrow @safe
        {
            if('a' <= exp[0] && exp[0] <= 'h')
                return 'a';
            else
                return 'x';
        }
        unittest{
            assert(swizzleType("aaaaaaa") == 'a');
            assert(swizzleType("aaaahaa") == 'a');
            assert(swizzleType("xxxx") == 'x');
            assert(swizzleType("xyzv") == 'x');
        }


        bool isSwizzlable(T)(string exp) pure nothrow @safe
        {
            static if(isVector!T){
              enum size = T.length - 1;

              if(swizzleType(exp) == 'a'){
                  foreach(c; exp)
                      if(c > 'a' + size)
                          return false;
                  return true;
              }else{
                  foreach(c; exp)
                      if(c != 'x' && c != 'y' && c != 'z' && c != 'w')
                          return false;
                  return true;
              }
            }
            else
              return false;
        }
        unittest{
            alias V3 = SMatrix!(int, 1, 3);
            assert(isSwizzlable!V3("aaa"));
            assert(isSwizzlable!V3("abc"));
            assert(!isSwizzlable!V3("abd"));
            assert(isSwizzlable!V3("xyz"));
            assert(!isSwizzlable!V3("xyzv"));

            alias V4 = SMatrix!(int, 1, 4);
            assert(isSwizzlable!V4("xyzw"));
            assert(!isSwizzlable!V4("xyzv"));
        }


        bool isSlicable(T, string exp)() pure nothrow @safe
        {
          static if(isSliceExp(exp)){
            enum sp = spec(exp);
            return ((mixin(sp.rs) + mixin(sp.rb)) <= T.cols) && ((mixin(sp.cs) + mixin(sp.cb)) <= T.rows);
          }
          else
            return false;
        }
        unittest{
            alias M33 = SMatrix!(int, 3, 3);
            assert(isSlicable!(M33, "m3x3"));
            assert(isSlicable!(M33, "m1x3"));
            assert(isSlicable!(M33, "r1m2x3"));
            assert(isSlicable!(M33, "c1m2x2"));
        }
    }


    return Swizzle!()(mat);
}

unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto org = matrix!((i, j) => i * 3 + j)();
    SMatrix!(size_t, 4, 4) a = org;
    auto m = a.swizzle.m2x2;
    static assert(isNarrowMatrix!(typeof(m)));
    assert(m == org);


    auto m2 = a.swizzle.r1c1m2x2;
    static assert(isNarrowMatrix!(typeof(m2)));
    assert(m2 == matrix!((i, j) => (i+1)*3 + j + 1)());


    assert(a.swizzle.m1x4.swizzle.xyzw == a.swizzle.m1x4);
}


/**
行ベクトルのランダムアクセスレンジ
*/
auto rowVectors(A)(A mat) @property
if(isNarrowMatrix!A && !isAbstractMatrix!A)
{
    static struct RowVectors()
    {
        auto front() @property { return this.opIndex(0); }
        auto back() @property { return this.opIndex(_end-1); }
        void popFront() @property { ++_idx; }
        void popBack() @property { --_end; }
        bool empty() @property const { return _idx == _end; }
        auto save() @property { return this; }



        auto opIndex(size_t i)
        {
            static struct RowVectorByIndex()
            {
                alias rows = _m.rows;
                enum cols = 1;


                auto ref opIndex(size_t i, size_t j) inout
                in{
                    assert(i < rows);
                    assert(j < cols);
                }
                body{
                    return _m[i, _idx];
                }


                mixin(defaultExprOps!(false));


                size_t _idx;
                A _m;
            }


            return RowVectorByIndex!()(i + _idx, _m);
        }


        size_t length() const @property
        {
            return _end - _idx;
        }


        alias opDispatch = length;

      private:
        size_t _idx;
        size_t _end;
        A _m;
    }


    return RowVectors!()(0, mat.cols, mat);
}
unittest
{
    real[3][3] mStack = [[1, 2, 2],
                         [2, 1, 1],
                         [2, 2, 2]];

    auto r = matrix(mStack).rowVectors;

    static assert(isRandomAccessRange!(typeof(r)));

    foreach(i; 0 .. 3)
        foreach(j; 0 .. 3)
            assert(r[i][j] == mStack[j][i]);
}


/**
行ベクトルのランダムアクセスレンジ
*/
auto columnVectors(A)(A mat) @property
if(isNarrowMatrix!A && !isAbstractMatrix!A)
{
    static struct ColumnVectors()
    {
        auto front() @property { return this.opIndex(0); }
        auto back() @property { return this.opIndex(_end-1); }
        void popFront() @property { ++_idx; }
        void popBack() @property { --_end; }
        bool empty() @property const { return _idx == _end; }
        auto save() @property { return this; }



        auto opIndex(size_t i)
        {
            static struct ColumnVectorByIndex()
            {
                enum rows = 1;
                alias cols = _m.cols;


                auto ref opIndex(size_t i, size_t j) inout
                in{
                    assert(i < rows);
                    assert(j < cols);
                }
                body{
                    return _m[_idx, j];
                }


                mixin(defaultExprOps!(false));


                size_t _idx;
                A _m;
            }

            return ColumnVectorByIndex!()(i + _idx, _m);
        }


        size_t length() const @property
        {
            return _end - _idx;
        }


        alias opDispatch = length;

      private:
        size_t _idx;
        size_t _end;
        A _m;
    }


    return ColumnVectors!()(0, mat.rows, mat);
}
unittest
{
    real[3][3] mStack = [[1, 2, 2],
                         [2, 1, 1],
                         [2, 2, 2]];

    auto r = matrix(mStack).columnVectors;

    static assert(isRandomAccessRange!(typeof(r)));

    foreach(i; 0 .. 3)
        foreach(j; 0 .. 3)
            assert(r[i][j] == mStack[i][j]);
}


/**
行列の跡(trace)を返します。正方行列についてのみ定義されます
*/
ElementType!A trace(A)(A mat)
if(isNarrowMatrix!A && !isAbstractMatrix!A && (!(hasStaticRows!A && hasStaticCols!A) || is(typeof({static assert(A.rows == A.cols);}))))
{
    alias ElementType!A T;
    T sum = cast(T)0;

    foreach(i; 0 .. mat.rows)
        sum += mat[i, i];

    return sum;
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto m = SMatrix!(int, 2, 2)();
    m[0, 0] = 0; m[0, 1] = 1;
    m[1, 0] = 2; m[1, 1] = 3;

    auto tr = m.trace;
    assert(tr == 3);
}


auto dot(V1, V2)(V1 vec1, V2 vec2)
if(isVector!V1 && isVector!V2 && (!(hasStaticLength!V1 && hasStaticLength!V2) || is(typeof({static assert(V1.length == V2.length);}))))
in{
    static if(!(hasStaticLength!V1 && hasStaticLength!V2))
    {
        assert(vec1.length == vec2.length);
    }
}
body{
    alias typeof(ElementType!V1.init * ElementType!V2.init) T;
    T sum = cast(T)0;

    foreach(i; 0 .. vec1.length){
        sum += vec1[i] * vec2[i];
    }

    return sum;
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto rv = SRVector!(int, 3)(),
         cv = SCVector!(int, 3)();

    rv.array[] = [0, 1, 2];
    cv.array[] = [1, 2, 3];

    assert((rv * cv)[0] == 8);  //8
    assert(rv.dot(cv) == 8);
    assert(cv.dot(rv) == 8);

    assert(rv.dot(rv) == 5);
    assert(cv.dot(cv) == 14);


    assert(approxEqual((rv * 0.5).dot(rv), 2.5));
}


/**
ベクトル同士のクロス積
*/
auto cross(Major mjr = Major.column, V1, V2)(V1 vec1, V2 vec2)
if(isVector!V1 && isVector!V2 && (hasStaticLength!V1 && is(typeof({static assert(V1.length == 3);})))
                              && (hasStaticLength!V2 && is(typeof({static assert(V2.length == 3);}))))
in{
    assert(vec1.length == 3);
    assert(vec2.length == 3);
}
body{
    static struct CrossResult
    {
        enum rows = mjr == Major.row ? 1 : 3;
        enum cols = mjr == Major.row ? 3 : 1;


        auto opIndex(size_t i, size_t j) const
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            switch(i + j){
              case 0: return _v1[1] * _v2[2] - _v1[2] * _v2[1];
              case 1: return _v1[2] * _v2[0] - _v1[0] * _v2[2];
              case 2: return _v1[0] * _v2[1] - _v1[1] * _v2[0];
              default: assert(0);
            }
        }

        mixin(defaultExprOps!(false));

      private:
        V1 _v1;
        V2 _v2;
    }

    return CrossResult(vec1, vec2);
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto rv = SVector!(int, 3)(),
         cv = SVector!(int, 3)();

    rv.array[] = [0, 1, 2];
    cv.array[] = [1, 2, 3];

    auto cp = rv.cross(cv);

    static assert(isVector!(typeof(cp)));
    static assert(hasStaticLength!(typeof(cp)));
    static assert(hasStaticRows!(typeof(cp)));
    static assert(hasStaticCols!(typeof(cp)));

    assert(cp[0] == -1);
    assert(cp[1] == 2);
    assert(cp[2] == -1);
}


/**
直積
*/
auto cartesian(V1, V2)(V1 vec1, V2 vec2)
if(isVector!V1 && isVector!V2)
{
    static struct Cartesian()
    {
        alias rows = _vec1.length;
        alias cols = _vec2.length;


        auto opIndex(size_t i, size_t j) const
        in{
            assert(i < rows);
            assert(j < cols);
        }
        body{
            return _vec1[i] * _vec2[j];
        }


        mixin(defaultExprOps!(false));


      private:
        V1 _vec1;
        V2 _vec2;
    }


    return Cartesian!()(vec1, vec2);
}
unittest{
    //scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    //scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}


    auto v1 = [0, 1, 2, 3].toMatrix!(3, 1);
    auto v2 = [2, 3, 4, 5].toMatrix!(1, 2);

    assert(v1.cartesian(v2) == v1 * v2);
    static assert(hasStaticRows!(typeof(v1.cartesian(v2))));
    static assert(hasStaticCols!(typeof(v1.cartesian(v2))));
}



/**
置換行列を作ります
*/
auto permutation(size_t size = wild, size_t)(const size_t[] pos) pure nothrow @safe
in{
    foreach(e; pos)
        assert(e < pos.length);

  static if(size != wild)
    assert(pos.length == size);
}
body{
    static struct Permutation
    {
      static if(size != wild)
        enum rows = size;
      else
        size_t rows() pure nothrow @safe const @property { return _pos.length; }

        alias cols = rows;


        auto opIndex(size_t i, size_t j) pure nothrow @safe const 
        {
            return _pos[i] == j ? 1 : 0;
        }


        mixin(defaultExprOps!(false));


        @property auto inverse() pure nothrow @safe const
        {
            static struct InvPermutation
            {
                static if(size != wild)
                enum rows = size;
              else
                size_t rows() pure nothrow @safe const @property { return _pos.length; }

                alias cols = rows;


                auto opIndex(size_t i, size_t j) pure nothrow @safe const
                {
                    return _pos[j] == i ? 1 : 0;
                }


                mixin(defaultExprOps!(false));


                @property auto inverse() pure nothrow @safe const
                {
                    return Permutation(_pos);
                }


              private:
                const(size_t)[] _pos;
            }


            return InvPermutation(_pos);
        }


        @property const(size_t)[] exchangeTable() pure nothrow @safe const
        {
            return _pos;
        }


      private:
        const(size_t)[] _pos;
    }


    return Permutation(pos);
}


template isPermutationMatrix(A)
{
    enum isPermutationMatrix = isNarrowMatrix!A && is(Unqual!(typeof(A.init.exchangeTable)) : size_t[]);
}



struct PLU(M)
if(isNarrowMatrix!M && !isAbstractMatrix!M)
{
  static if(hasStaticRows!M)
    alias rows = lu.rows;
  else
    @property size_t rows() pure nothrow @safe const { return piv.length; }

    alias cols = rows;

    size_t[] piv;
    bool isEvenP;
    M lu;


    auto p() pure nothrow @safe const
    {
        return permutation(piv);
    }



    auto l() pure nothrow @safe
    {
        static struct L()
        {
          static if(hasStaticRows!M)
            enum rows = M.rows;
          else static if(hasStaticCols!M)
            enum rows = M.cols;
          else
            size_t rows() const  @property { return _lu.rows; }

            alias cols = rows;


            typeof(_lu[0, 0]) opIndex(size_t i, size_t j) const
            in{
                assert(i < rows);
                assert(j < cols);
            }
            body{
                if(i == j)
                    return cast(typeof(return))1;
                else if(i < j)
                    return cast(typeof(return))0;
                else
                    return _lu[i, j];
            }


            mixin(defaultExprOps!(false));


          private:
            M _lu;
        }


        return L!()(lu);
    }



    auto u() pure nothrow @safe
    {
        static struct U()
        {
          static if(hasStaticRows!M)
            enum rows = M.rows;
          else static if(hasStaticCols!M)
            enum rows = M.cols;
          else
            size_t rows() const  @property { return _lu.rows; }

            alias cols = rows;


            typeof(_lu[0, 0]) opIndex(size_t i, size_t j) const
            in{
                assert(i < rows);
                assert(j < cols);
            }
            body{
                if(i > j)
                    return cast(typeof(return))0;
                else
                    return _lu[i, j];
            }


            mixin(defaultExprOps!(false));


          private:
            M _lu;
        }


        return U!()(lu);
    }


    /**
    Ax = bとなるxを解きます
    */
    auto solveInPlace(V)(V b)
    if(isVector!V /*&& isFloatingPoint!(ElementType!V) && is(typeof({b[0] = real.init;}))*/ )
    in{
        assert(b.length == rows);
    }
    body{
        /*
        Ax = bの両辺にPをかけることにより
        PAx = Pbとなるが、LU分解によりPA = LUであるから、
        LUx = Pbである。

        ここで、y=Uxとなるyベクトルを考える。
        Ly = Pbである。
        Lは下三角行列なので、簡単にyベクトルは求まる。

        次に、Ux=yより、xベクトルを同様に求めれば良い
        */

        immutable size_t size = rows;

        // b <- Pb
        b = this.p * b;

        // Ly=Pbからyを求める
        foreach(i; 1 .. size)
            foreach(j; 0 .. i)
                b[i] -= lu[i, j] * b[j];

        // Ux=Py
        foreach_reverse(i; 0 .. size){
            foreach_reverse(j; i+1 .. size)
                b[i] -= lu[i, j] * b[j];

            b[i] /= lu[i, i];
        }
    }


    /**
    逆行列を求める
    */
    M inverse() @property
    {
        immutable size_t size = lu.rows;

        M m = identity!(ElementType!M)().congeal(size, size);

        foreach(i; 0 .. lu.cols)
            this.solveInPlace(m.rowVectors[i]);

        return m;
    }


    auto det() @property
    {
        auto dst = cast(ElementType!M)(isEvenP ? 1 : -1);
        foreach(i; 0 .. rows)
            dst *= lu[i, i];

        return dst;
    }
}


/**
In-Placeで、行列をLU分解します。

"Numerical Recipes in C"
*/
PLU!(A) pluDecomposeInPlace(A)(A m)
if(isNarrowMatrix!A && hasLvalueElements!A && (!hasStaticRows!A || !hasStaticCols!A || is(typeof({static assert(A.rows == A.cols);}))))
in{
    assert(m.rows == m.cols);
}
body{
    immutable size = m.rows;
    scope vv = new real[size];
    bool isEvenP;
    size_t[] idx = new size_t[size];

    foreach(i, ref e; idx)
        e = i;

    foreach(i; 0 .. size){
        real big = 0;

        foreach(j; 0 .. size){
            immutable temp = m[i, j].abs();
            if(temp > big)
                big = temp;
        }

        if(big == 0) enforce("Input matrix is a singular matrix");

        vv[i] = 1.0 / big;
    }


    foreach(j; 0 .. size){
        foreach(i; 0 .. j){
            auto sum = m[i, j];
            foreach(k; 0 .. i) sum -= m[i, k] * m[k, j];
            m[i, j] = sum;
        }

        real big = 0;
        size_t imax;
        foreach(i; j .. size){
            auto sum = m[i, j];
            foreach(k; 0 .. j) sum -= m[i, k] * m[k, j];
            m[i, j] = sum;

            immutable dum = vv[i] * sum.abs();
            if(dum >= big){
                big = dum;
                imax = i;
            }
        }

        if(j != imax){
            foreach(k; 0 .. size)
                swap(m[imax, k], m[j, k]);

            isEvenP = !isEvenP;
            vv[imax] = vv[j];

            swap(idx[j], idx[imax]);
        }

        //idx[j] = imax;

        //if(m[j, j] == 0) m[j, j] = 1.0E-20;

        if(j != size-1){
            immutable dum = 1 / m[j, j];
            foreach(i; j+1 .. size)
                m[i, j] *= dum;
        }
    }

    return PLU!A(idx, isEvenP, m);
}
unittest{
    real[3][3] mStack = [[1, 2, 2],
                         [2, 1, 1],
                         [2, 2, 2]];

    auto m = matrix(mStack);

    SMatrix!(real, 3, 3) org = m;
    auto plu = m.pluDecomposeInPlace();

    SMatrix!(real, 3, 3) result = plu.p.inverse * plu.l * plu.u;

    foreach(i; 0 .. 3) foreach(j; 0 .. 3)
        assert(approxEqual(result[i, j], org[i, j]));   // A = P^(-1)LU

    assert(approxEqual(plu.det, 0));
}

unittest{
    real[3][3] mStack = [[2, 4, 2],
                         [4, 10, 3],
                         [3, 7, 1]];

    auto m = mStack.matrix();

    SMatrix!(real, 3, 3) org = m;
    auto plu = m.pluDecomposeInPlace();

    auto v = matrix!(3, 1)(cast(real[])[8, 17, 11]);

    plu.solveInPlace(v);
    foreach(i; 0 .. 3)
        assert(approxEqual(v[i], 1));
}

unittest{
    real[3][3] mStack = [[2, 4, 2],
                         [4, 10, 3],
                         [3, 7, 1]];

    auto m = mStack.matrix();

    SMatrix!(real, 3, 3) org = m;
    auto plu = m.pluDecomposeInPlace();
    auto iden = org * plu.inverse;
    
    foreach(i; 0 .. 3)
        foreach(j; 0 .. 3)
            assert(approxEqual(iden[i, j], identity!real[i, j]));
}


/**
ベクトルのノルムを計算します
*/
auto norm(real N = 2, V)(V v)
{
    real sum = 0;
    foreach(i; 0 .. v.length)
        sum += v[i] ^^ N;
    return sum ^^ (1/N);
}
