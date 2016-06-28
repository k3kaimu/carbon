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
このモジュールは、信号処理のための試験的なモジュールです。
このモジュールで定義されているストリームは、Rangeに拡張を加える事で大量のデータを処理することに最適です。
また、状況によってはSIMD最適化を狙えるよう設計になっています。
*/
module carbon.stream;

import carbon.math,
       carbon.functional,
       carbon.nonametype,
       carbon.simd;

import std.algorithm,
       std.container,
       std.file,
       std.functional,
       std.math,
       std.range,
       std.stdio,
       std.traits,
       std.typecons;


/**
入力ストリームは、`read`メソッドに与えられたバッファに要素を格納可能な型です。
実行時には、次のような特徴を満たさなければいけません。

+ `stream.empty`は、そのストリームからノンブロッキングで一要素でも取り出せる場合には`false`となる。
+ `stream.front`は、そのストリームからノンブロッキングで一要素取り出す。
+ `stream.popFront`は、そのストリームをノンブロッキングでひとつ進める。
+ `stream.length`が有効である場合、この値はノンブロッキングで読み出すことができる要素数となる。
+ `stream.read(buf)`は、ノンブロッキングで処理しなければいけない。
+ `stream.read(buf)`は、bufのうち先頭から読み込みに成功した要素数だけのスライスを返す。
    - `stream.length >= buf.length`のとき、常に、`buf.length == stream.read(buf).length`となる。
//+ `stream.closed`は、いくら待ってもそれ以上要素が取り出せない状況で`true`となる。
//    - `stream.closed`が真の場合、`stream.empty`であり、`lenght`が有効であれば`stream.length == 0`を満たす。
+ `stream.fetch()`は、`stream.empty`が偽になるまで、
    もしくはそのストリームからは今後一切データを取り出せないと判断した時点で処理を返す。
    `stream.fetch()`は、待機後の`stream.empty()`を返す。
+ `stream`が無限レンジの場合、`stream.read(buf)`は常に`buf`の全要素に読み込む。
*/
enum bool isInputStream(T) = isInputRange!T && is(typeof((T t){
        alias E = Unqual!(ElementType!T);
        while(!t.empty || !t.fetch()) E[] var = t.read(new E[1024]);
    }));


/**
入力ストリームから、ストリーム終端になるまで可能な限り読み出します。
*/
E[] fillBuffer(S, E)(ref S s, E[] buf)
if(isInputStream!S)
{
    E[] rem = buf;
    while(rem.length && (!s.empty || !s.fetch()))
        rem = rem[s.read(rem).length .. $];
    
    return buf[0 .. $ - rem.length];
}


/**
演算可能なストリームとは、`readOp`メソッドに与えられたバッファ上に、計算した要素を格納可能な入力ストリームです。
これは、次のような実行時条件を満たしている必要があります。

+ `stream.readOp!"op"(buf)`は、`a op= b`という演算をbuf上で行う。
    つまり、
    - op : "+"のとき、streamから読み出された値を、bufに加える演算を表す。
    - op : "-"のとき、streamから読み出された値を、bufから引く演算を表す。
    + op : ""のときは、`stream.read(buf)`と等価です。
+ `stream.readOp!func(buf)`は、`func(a, b)`という演算結果をbufに格納する
    - `stream.readOp!((a, b) => b)(buf)`は、`stream.read(buf)`と等価です。
    - `stream.readOp!((a, b) => a + b)(buf)`は、`stream.readOp!"+"(buf)`と等価です。
*/
enum bool isInplaceComputableStream(T, alias op = "", U = Unqual!(ElementType!T)) = isInputStream!T &&
    is(typeof((T t, U[] buf){
        buf = t.readOp!op(buf);   // as read(buf)
    }));


/**
出力ストリームは、`t.write`メソッドに与えられたバッファを出力可能な型です。
実行時には次のような条件を満たしている必要があります。

+ `stream.write(buf)`は、ノンブロッキングでバッファを出力し、まだ出力できていないバッファを返す。
+ `stream.fill`が偽であれば、一要素でも`stream.write`でノンブロッキング出力可能である
+ `stream.flush()`は、ブロッキング処理で`t.fill`が偽になるか、
    もしくはそれ以上出力不可能だと判断した時点で、`t.fill`を返す。
*/
enum bool isOutputStream(T, E) = 
    is(typeof((T t, E e){
        E[] writeData = new E[1024];
        while(writeData.length && (!t.fill || !t.flush())) writeData = t.write(writeData);
    }));


/**
*/
E[] fillBufferOp(alias op, S, E)(ref S s, E[] buffer)
{
    auto rem = buffer;
    while(rem.length && (!s.empty || !s.fetch()))
        rem = s.readOp!op(rem);
    return buffer[0 .. $ - rem.length];
}


/**
内部にバッファを持つような入力ストリームです。

+ `stream.availables`は内部のバッファを返す。
+ `stream.consume(size)`は、内部バッファの先頭から`size`要素だけを捨てる。
*/
enum bool isBufferedInputStream(T) = isInputStream!T && 
    is(typeof((T t){
        alias E = ElementType!T;
        const(E)[] buf = t.availables;
        t.consume(buf.length);
    }));


/**
内部にバッファを持つような出力ストリームです。

+ `stream.buffer`は内部のバッファを返す。
+ `stream.flush(size)`は、内部バッファの先頭から`size`要素だけ出力する。
*/
enum bool isBufferedOutputStream(T) = isOutputStream!T &&
    is(typeof((T t){
        auto buf = t.buffer;
        static assert(is(typeof(buf) : E[], E));
        static assert(is(typeof(buf) == Unqual!(typeof(buf))));
        t.flush(buf.length);
    }));


/**
InplaceComputableStreamを作成する際に有用な、std.functional.binaryFunの拡張です
*/
auto ref A binaryFunExt(alias op, A, B)(auto ref A a, auto ref B b)
if(is(typeof(mixin(`a` ~ op ~ `=b`))))
{
    mixin(`a` ~ op ~ "=b;");
    return a;
}


/// ditto
auto ref A binaryFunExt(alias func, A, B)(auto ref A a, auto ref B b)
if(is(typeof(a = naryFun!func(a, forward!b))))
{
    a = naryFun!func(a, forward!b);
    return a;
}


/**
レンジをisInplaceComputableStreamに変換します
*/
auto toStream(R)(R range)
if(isInputRange!R && !isInputStream!R)
{
    alias E = Unqual!(ElementType!R);

    static struct InputStreamRange()
    {
        R range;
        alias range this;
        alias closed = range.empty;
        bool fetch(){ return range.empty; }

        T[] readOp(alias func, T)(T[] buf)
        {
            auto p = buf.ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end && !range.empty){
                binaryFunExt!func(*p, range.front);
                range.popFront();
                () @trusted { ++p; }();
            }

            return () @trusted { return buf[0 .. cast(size_t)(p - buf.ptr)]; }();
        }


        T[] read(T)(T[] buf) { return readOp!""(buf); }

        //mixin(defaultStreamSIMDOperator);
    }


    return InputStreamRange!()(range);
}


/**
正確なComplexNCO
*/
auto preciseComplexNCO(real freq, real deltaT, real theta = 0) pure nothrow @safe @nogc
{
    static struct PreciseComplexNCO()
    {
        creal front() const @property { return this[0]; }
        void popFront() { _theta += _dt2PI * _freq; }
        enum bool empty = false;
        PreciseComplexNCO!() save() const @property { return this; }
        creal opIndex(size_t i) const @property { return std.math.expi(_theta + i * _dt2PI * _freq); }
        struct OpDollar{} enum OpDollar opDollar = OpDollar();
        PreciseComplexNCO!() opSlice() const { return this; }
        PreciseComplexNCO!() opSlice(size_t i, OpDollar) const { PreciseComplexNCO!() dst = this; dst._theta += i * _dt2PI * _freq; return dst; }
        auto opSlice(size_t i, size_t j) const { return this[i .. $].take(j - i); }

        bool fetch() { return false; }

        T[] readOp(alias op, T)(T[] buf)
        {
            auto p = buf.ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end){
                binaryFunExt!op(*p, std.math.expi(_theta));
                _theta += _dt2PI * _freq;
                () @trusted { ++p; }();
            }

            return buf;
        }


        Cpx[] read(Cpx)(Cpx[] buf){ return readOp!""(buf); }

        //mixin(defaultStreamSIMDOperator);

      @property
      {
        real freq() const @property { return _freq; }
        void freq(real f) @property { _freq = f; }

        real deltaT() const @property { return _dt2PI / 2 / PI; }
        void deltaT(real dt) @property { _dt2PI = dt * 2 * PI; }
      }

      private:
        real _freq;
        real _dt2PI;
        real _theta;
    }

    return PreciseComplexNCO!()(freq, deltaT * 2 * PI, theta);
}


///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto sig1 = preciseComplexNCO(1000, 0.001, 0);
    static assert(isInputStream!(typeof(sig1)));
    static assert(isInplaceComputableStream!(typeof(sig1)));
    static assert(is(ElementType!(typeof(sig1)) == creal));

    assert(equal!((a, b) => approxEqual(a.re, b.re) && approxEqual(a.im, b.im))
                (sig1[0 .. 4], cast(creal[])[1, 1, 1, 1]));

    sig1 = preciseComplexNCO(1, 0.25, 0);
    assert(equal!((a, b) => approxEqual(a.re, b.re) && approxEqual(a.im, b.im))
                (sig1[0 .. 4], cast(creal[])[1, 0+1i, -1, -1i]));

    sig1 = preciseComplexNCO(1000, 10.0L^^-6, std.math.E);
    auto buf = sig1[0 .. 1024].array;
    assert(sig1.readOp!"-"(buf).length == buf.length);
    assert(equal!"a == 0"(buf, buf));

    sig1.readOp!"a+b"(buf);
}



/**
Lookup-Table方式の高速な局部発振器を提供します。
テンプレートパラメータの`func`には周期2PIの周期関数を与えることが出来ます。
たとえば、`std.math.expi`を与えれば複素発振器となり、`std.math.sin`であれば正弦波を出力します。

この局部発振器は周波数の動的な制御が可能なので、信号の周波数をフィードバック制御する際に用いることができます。
Lookup-Tableは、テンプレートパラメータ毎にプログラムの初期化時に生成されるので、
最初の初期化が終われば、実行コストはテーブルの参照のみになり、高速にアクセス可能です。
また、テーブル長を伸ばしても初期化コストが増加するだけで、実行コストはあまり大きくならないことも特徴です。
*/
template lutNCO(alias func, size_t divN)
if(isPowOf2(divN))
{
    alias E = typeof(func(0.0));
    immutable(E[]) table;

    shared static this()
    {
        E[divN] t;
        foreach(i, ref e; t)
            e = func(i * 2 * PI / divN);

        table = t.dup;
    }


    struct LutNCO()
    {
        E front() const @property { return table[cast(ptrdiff_t)(_phase) & (divN - 1)]; }
        void popFront() { _phase += _freq * _deltaT * divN; _phase %= divN; }
        enum bool empty = false;
        LutNCO save() const @property { return this; }
        E opIndex(size_t i) const { return table[cast(ptrdiff_t)(_phase + i * _freq * _deltaT * divN) & (divN - 1)]; }
        struct OpDollar{} enum opDollar = OpDollar();
        LutNCO opSlice() const { return this; }
        LutNCO opSlice(size_t i, OpDollar) const { auto dst = this[]; dst._phase += i * _freq * _deltaT; return dst; }
        auto opSlice(size_t i, size_t j) const { return this[i .. $].take(j - i); }

        real phase() const @property { return _phase; }
        void phase(real p) @property { _phase = p; }
        real freq() const @property { return _freq; }
        void freq(real f) @property { _freq = f; }
        real deltaT() const @property { return _deltaT; }
        void deltaT(real t) @property { _deltaT = t; }

        bool fetch() { return false; }

        T[] readOp(alias op, T)(T[] buf)
        if(is(typeof(binaryFunExt!op(buf[0], table[0]))))
        {
            immutable dph = _freq * _deltaT * divN;
            auto p = buf.ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end){
                binaryFunExt!op(*p, table[cast(ptrdiff_t)(_phase) & (divN - 1)]);
                _phase += dph;
                () @trusted { ++p; }();
            }

            return buf[0 .. $];
        }

        auto readOp(alias op, E, size_t N)(SIMDArray!(E, N) buf)
        if(is(typeof(binaryFunExt!op(buf[0], _table[0]))))
        {
            immutable dph = _freq * _deltaT * divN * N;
            auto p = buf[].ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end){
                binaryFunExt!op(*p, table[cast(ptrdiff_t)(_phase) & (divN - 1)]);
                _phase += dph;
                () @trusted { ++p; }();
            }

            return buf;
        }

        T[] read(T)(T[] buf) @safe { return readOp!""(buf); }

        auto read(E, size_t N)(SIMDArray!(E, N) buf) { return readOp!""(buf); }

      private:
        real _phase;
        real _freq;
        real _deltaT;
    }


    auto lutNCO(real freq, real deltaT, real theta = 0) pure nothrow @safe @nogc
    {
        return .lutNCO(table, freq, deltaT, theta);
    }
}


///
unittest{
    auto sig1 = lutNCO!(std.math.expi, 4)(1, 0.25, 0);
    static assert(isInputStream!(typeof(sig1)));
    static assert(isInplaceComputableStream!(typeof(sig1)));
    static assert(is(ElementType!(typeof(sig1)) : creal));

    assert(equal!((a, b) => approxEqual(a.re, b.re) && approxEqual(a.im, b.im))
        (sig1[0 .. 1024], preciseComplexNCO(1, 0.25, 0)[0 .. 1024]));

    sig1 = lutNCO!(std.math.expi, 4)(1000, 10.0L^^-6, std.math.E);
    auto buf = sig1[0 .. 1024].array;
    assert(sig1.readOp!"-"(buf).length == buf.length);
    assert(equal!"a == 0"(buf, buf));
}


/**
*/
auto lutNCO(R)(R range, real freq, real deltaT, real theta = 0) pure nothrow @safe @nogc
if(isRandomAccessRange!R && hasLength!R)
{
    alias E = Unqual!(std.range.ElementType!R);

    static struct LutNCO()
    {
        E front() @property { return _table[cast(ptrdiff_t)(_phase) % $]; }
        void popFront() { _phase += _freq * _deltaT * _table.length; _phase %= _table.length; }
        enum bool empty = false;
        auto save() @property { return .lutNCO(_table.save, _freq, _deltaT, _phase); }
        E opIndex(size_t i) { return _table[cast(ptrdiff_t)(_phase + i * _freq * _deltaT * $) % $]; }
        struct OpDollar{} enum opDollar = OpDollar();
        auto opSlice() { return .lutNCO(_table.save, _freq, _deltaT, _phase); }
        auto opSlice(size_t i, OpDollar) { auto dst = this[]; dst._phase += i * _freq * _deltaT; return dst; }
        auto opSlice(size_t i, size_t j) { return this[i .. $].take(j - i); }

      static if(is(typeof((const R r, size_t i){auto e = r[i];})))
      {
        E front() const @property { return _table[cast(ptrdiff_t)(_phase) % $]; }
        E opIndex(size_t i) const { return _table[cast(ptrdiff_t)(_phase + i * _freq * _deltaT * $) % $]; }
      }

      static if(is(typeof((const R r){r.save();})))
      {
        auto save() const @property { return .lutNCO(_table.save, _freq, _deltaT, _phase); }
        auto opSlice() const { return .lutNCO(_table.save, _freq, _deltaT, _phase); }
        auto opSlice(size_t i, OpDollar) const { auto dst = this[]; dst._phase += i * _freq * _deltaT; return dst; }
        auto opSlice(size_t i, size_t j) const { return this[i .. $].take(j - i); }
      }

        real phase() const @property { return _phase; }
        void phase(real p) @property { _phase = p; }
        real freq() const @property { return _freq; }
        void freq(real f) @property { _freq = f; }
        real deltaT() const @property { return _deltaT; }
        void deltaT(real t) @property { _deltaT = t; }

        bool fetch() { return false; }

        T[] readOp(alias op, T)(T[] buf)
        if(is(typeof(binaryFunExt!op(buf[0], _table[0]))))
        {
            immutable dph = _freq * _deltaT * _table.length;
            auto p = buf.ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end){
                binaryFunExt!op(*p, _table[cast(ptrdiff_t)(_phase) % $]);
                _phase += dph;
                () @trusted { ++p; }();
            }

            return buf[0 .. $];
        }


        auto readOp(alias op, E, size_t N)(SIMDArray!(E, N) buf)
        if(is(typeof(binaryFunExt!op(buf[0], _table[0]))))
        {
            immutable divN = _table.length;

            immutable dph = _freq * _deltaT * divN * N;
            auto p = buf[].ptr;
            const end = () @trusted { return p + buf.length; }();
            while(p != end){
                binaryFunExt!op(*p, _table[cast(ptrdiff_t)(_phase) % $]);
                _phase += dph;
                () @trusted { ++p; }();
            }

            return buf;
        }


        T[] read(T)(T[] buf) { return readOp!""(buf); }

        auto read(E, size_t N)(SIMDArray!(E, N) buf) { return readOp!""(buf); }

        //mixin(defaultStreamSIMDOperator);


      private:
        R _table;
        real _phase;
        real _freq;
        real _deltaT;
    }


    return LutNCO!()(range, theta, freq, deltaT);
}


/**
永遠とその配列をループし続けるストリーム
*/
auto repeatStream(E)(const E[] array)
in{
    assert(array.length);
}
body{
    static struct RepeatStream()
    {
        const(E) front() const @property { return _arr[_pos]; }
        enum empty = false;
        void popFront() { ++_pos; _pos %= _arr.length; }
        RepeatStream!() save() const @property { return this; }
        const(E) opIndex(size_t i) const { return _arr[_pos % $]; }
        RepeatStream!() opSlice(){ return this; }
        struct OpDollar{} enum opDollar = OpDollar();
        RepeatStream!() opSlice(size_t i, OpDollar){ typeof(return) dst; dst._pos = (_pos + i) % _arr.length; return dst; }
        auto opSlice(size_t i, size_t j){ return this[i .. $].take(j - i); }

        bool fetch() { return false; }

        U[] readOp(alias op, U)(U[] buf)
        {
            auto rem = buf;
            while(rem.length){
                auto minL = min(rem.length, _arr.length - _pos);

              static if(is(typeof({ mixin(`rem[]` ~ op ~ `=_arr[];`); })))
                mixin(`rem[0 .. minL] `~ op ~ "= _arr[_pos .. _pos + minL];");
              else{
                auto rem_ptr = rem.ptr,
                     buf_ptr = () @trusted { return _arr.ptr + _pos; }();
                const rem_end = () @trusted { return rem_ptr + minL; }();

                while(rem_ptr != rem_end){
                    binaryFunExt!op(*rem_ptr, *buf_ptr);
                    () @trusted { ++rem_ptr; ++buf_ptr; }();
                }
              }
              _pos += minL;
              _pos %= _arr.length;
              rem = rem[minL .. $];
            }

            return buf;
        }


        U[] read(U)(U[] buf) { return readOp!""(buf); }

        //mixin(defaultStreamSIMDOperator);


        const(E)[] availables() @property { return _arr[_pos .. $]; }
        void consume(size_t n) {
            _pos += n;
            _pos %= _arr.length;
        }

      private:
        const(E)[] _arr;
        size_t _pos;
    }


    return RepeatStream!()(array, 0);
}


/// ditto
auto repeatStream(E)(E element)
if(!is(E : T[], T))
{
    static struct RepeatStream()
    {
        enum bool empty = false;
        auto front() const @property { return _e; }
        void popFront() {}
        auto save() @property { return this; }
        auto save() const @property { return .repeatStream(_e); }
        auto save() immutable @property { return .repeatStream(_e); }
        auto opIndex(size_t) const @property { return _e; }
        RepeatStream!() opSlice() const { return this; }
        struct OpDollar{} enum opDollar = OpDollar();
        RepeatStream!() opSlice(size_t, OpDollar) const { return this; }
        auto opSlice(size_t i , size_t j) const { return this.take(j - i); }

        bool fetch() { return false; }


        U[] readOp(alias op, U)(U[] buf)
        {
          static if(is(typeof({ mixin(`buf[] ` ~ op ~ "= _e;"); })))
            mixin(`buf[] ` ~ op ~ "= _e;");
          else
          {
            auto p = buf.ptr,
                 e = () @trusted { return p + buf.length; }();

            while(p != e){
                binaryFunExt!op(*p, _e);
                () @trusted { ++p; }();
            }
          }

            return buf;
        }


        U[] read(U)(U[] buf)
        {
            return readOp!""(buf);
        }

        //mixin(defaultStreamSIMDOperator);

      private:
        E _e;
    }


    return RepeatStream!()(element);
}

///
unittest{
    int[] arr = [0, 1, 2, 3, 4, 5, 6, 7];
    auto rs = arr.repeatStream;
    static assert(isInfinite!(typeof(rs)));
    static assert(isInputStream!(typeof(rs)));
    static assert(isInplaceComputableStream!(typeof(rs)));
    static assert(isBufferedInputStream!(typeof(rs)));


    int[] buf1 = new int[24];
    assert(rs.readOp!"+"(buf1) == arr ~ arr ~ arr);

    short[] buf2 = new short[17];
    assert(rs.readOp!"cast(short)b"(buf2) == buf1[0 .. 17]);
}

///
unittest{
    auto rs = 1.repeatStream;
    static assert(isInfinite!(typeof(rs)));
    static assert(isInputStream!(typeof(rs)));
    static assert(isInplaceComputableStream!(typeof(rs)));

    assert(rs.read(new int[4]) == [1, 1, 1, 1]);
}


/**
一度に巨大なファイルを読み込むことに特化した，バッファ持ち入力ストリームです。
*/
auto rawFileStream(T)(string filename, size_t bufferSize = 1024 * 1024)
if(is(Unqual!T == T))
{
    static struct RawFileStream()
    {
        private void refill()
        {
            _pos = 0;
            if(!_file.isOpen){
                _buffer = null;
                return;
            }

            _pos = 0;
            immutable beforeSize = _buffer.length;
            _buffer = _file.rawRead(_buffer);
            if(_buffer.length != beforeSize)
                _file.detach();
        }


        this(File file, T[] buf)
        {
            _file = file;
            _buffer = buf;
            _pos = 0;
        }


        /** 入力レンジのプリミティブ
        */
        T front() const @property { return _buffer[_pos]; }
        bool empty() const @property { return _buffer.length == _pos; }     /// ditto
        void popFront() { ++_pos; }                                         /// ditto
        size_t length() const @property { return _buffer.length - _pos; }   /// ditto


        /**
        入力ストリームのプリミティブ
        */
        bool fetch()
        {
            if(!this.empty) return false;
            refill();
            return this.empty;
        }


        /// ditto
        E[] readOp(alias func, E)(E[] buf)
        if(is(typeof(binaryFunExt!func(buf[0], _buffer[0]))))
        {
            immutable minL = min(buf.length, _buffer.length - _pos);
          static if(is(typeof(mixin(`buf[]` ~ func ~ `= _buffer[]`))))
            mixin(`buf[0 .. minL] ` ~ func ~ "= _buffer[_pos .. _pos + minL];");
          else
          {
            auto rem_ptr = buf.ptr,
                 buf_ptr = () @trusted { return _buffer.ptr + _pos; }();
            const rem_end = () @trusted { return rem_ptr + minL; }();

            while(rem_ptr != rem_end){
                binaryFunExt!func(*rem_ptr, *buf_ptr);
                () @trusted { ++rem_ptr; ++buf_ptr; }();
            }
          }
            _pos += minL;
            return buf[0 .. minL];
        }


        /// ditto
        E[] read(E)(E[] buf)
        //if(isAssignable!(E, T))
        { return readOp!""(buf); }


        //mixin(defaultStreamSIMDOperator);


        /**
        バッファ持ち入力レンジのプリミティブ
        */
        const(T)[] availables() const @property { return _buffer[_pos .. $]; }


        /**
        バッファ持ち入力レンジのプリミティブ
        */
        void consume(size_t n)
        {
            while(n && !this.empty){
                if(n >= _buffer.length - _pos){
                    n -= _buffer.length - _pos;
                    if(_file.isOpen)
                        refill();
                    else{
                        _buffer = null;
                        _pos = 0;
                    }
                }
                else{
                    _pos += n;
                    n = 0;
                }
            }
        }


      private:
        T[] _buffer;
        size_t _pos;
        File _file;
    }


    auto dst = RefCounted!(RawFileStream!())(File(filename), new T[bufferSize]);
    dst.refill();
    return dst;
}

///
unittest{
    immutable fname = "testData.dat";
    std.file.write(fname, cast(ubyte[])[0, 1, 2, 3, 4, 5]); // 6byte
    scope(exit)
        std.file.remove(fname);

    auto sig1 = rawFileStream!int(fname);
    static assert(isInputStream!(typeof(sig1)));
    static assert(isInplaceComputableStream!(typeof(sig1)));
    static assert(isBufferedInputStream!(typeof(sig1)));

    assert(sig1.availables.length == 1);
    sig1.consume(1);
    assert(sig1.empty && sig1.fetch());
}

///
unittest{
    immutable fname = "testData.dat";
    std.file.write(fname, [0, 1, 2, 3, 4, 5]); // 24byte
    scope(exit)
        std.file.remove(fname);

    auto sig1 = rawFileStream!int(fname);
    assert(sig1.availables == [0, 1, 2, 3, 4, 5]);
    sig1.consume(6);
    assert(sig1.empty && sig1.fetch());
}


/**
二つの信号の積を返します。
２つ目の信号は演算による理想信号でなければいけません。
*/
auto mixer(Sg1, Sg2)(Sg1 sg1, Sg2 sg2)
if(isInputStream!Sg1 && isInplaceComputableStream!(Sg2, "*") && isInfinite!Sg2)
{
    static struct Mixer()
    {
        auto ref front() const @property { return _sg1.front * _sg2.front; }

      static if(isInfinite!Sg1)
        enum bool empty = false;
      else
        bool empty() const @property { return _sg1.empty; }

        void popFront() { _sg1.popFront(); _sg2.popFront(); }

        bool fetch()
        {
          static if(isInfinite!Sg1)
            return false;
          else
          {
            if(!_sg1.empty) return false;
            //_sg2.fetch();
            return _sg1.fetch();
          }
        }


        E[] read(E)(E[] buf)
        {
            return readOp!""(buf);
        }


        auto read(E, size_t N)(SIMDArray!(E, N) buf)
        {
            return readOp!""(buf);
        }


        E[] readOp(alias op, E)(E[] buf)
        if((op == "*" || op == "/")
        && isInplaceComputableStream!(Sg1, op)
        && isInplaceComputableStream!(Sg2, op))
        {
            return _sg2.readOp!op(_sg1.readOp!op(buf));
        }


        E[] readOp(alias op : "", E)(E[] buf)
        {
            return _sg2.readOp!"*"(_sg1.read(buf));
        }


        auto readOp(alias op, E, size_t N)(SIMDArray!(E, N) buf)
        if((op == "*" || op == "/")
        && isInplaceComputableStream!(Sg1, op)
        && isInplaceComputableStream!(Sg2, op))
        {
            return _sg2.readOp!op(_sg1.readOp!op(buf));
        }


        auto readOp(alias op : "", E, size_t N)(SIMDArray!(E, N) buf)
        {
            return _sg2.readOp!"*"(_sg1.read(buf));
        }


      private:
        Sg1 _sg1;
        Sg2 _sg2;
    }


    return Mixer!()(sg1, sg2);
}


///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr1 = [0, 1, 0, 1, 0, 1, 0, 1].repeatStream;
    auto arr2 = [0, 0, 1, 1, 0, 0, 1, 1].repeatStream;
    auto mx1 = arr1.mixer(arr2);
    static assert(isInfinite!(typeof(mx1)));
    static assert(isInputStream!(typeof(mx1)));

    int[] buf1 = new int[16];
    assert(mx1.read(buf1) == [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]);

    auto arr3 = [0, 0, 0, 0, 1, 1, 1, 1].repeatStream;
    auto mx2 = mx1.mixer(arr3);

    int[] buf2 = new int[16];
    assert(mx2.read(buf2) == [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);
}


/**
二つの信号を足します。
２つ目の信号は、演算により生成された理想信号でなければいけません。
*/
auto adder(Sg1, Sg2)(Sg1 sg1, Sg2 sg2)
if(isInputStream!Sg1 && isInplaceComputableStream!(Sg2, "+") && isInfinite!Sg2)
{
    static struct Adder()
    {
        auto ref front() const @property { return _sg1.front + _sg2.front; }

      static if(isInfinite!Sg1)
        enum bool empty = false;
      else
        bool empty() const @property { return _sg1.empty; }

        void popFront() { _sg1.popFront(); _sg2.popFront(); }

        bool fetch() {
          static if(isInfinite!Sg1)
            return false;
          else
          {
            if(!_sg1.empty) return false;
            //_sg2.fetch();
            return _sg1.fetch();
          }
        }

        E[] read(E)(E[] buf)
        {
            return readOp!""(buf);
        }


        E[] readOp(alias op, E)(E[] buf)
        if((op == "+" || op == "-")
        && isInplaceComputableStream!(Sg1, op)
        && isInplaceComputableStream!(Sg2, op))
        {
            return _sg2.readOp!op(_sg1.readOp!op(buf));
        }


        auto readOp(alias op, E, size_t N)(SIMDArray!(E, N) buf)
        {
            return _sg2.readOp!op(_sg1.readOp!op(buf));
        }


        E[] readOp(alias op : "", E)(E[] buf)
        {
            return _sg2.readOp!"+"(_sg1.read(buf));
        }


        auto readOp(alias op, E, size_t N)(SIMDArray!(E, N) buf)
        {
            return _sg2.readOp!"+"(_sg1.readOp(buf));
        }


      private:
        Sg1 _sg1;
        Sg2 _sg2;
    }


    return Adder!()(sg1, sg2);
}


///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr1 = [0, 1, 0, 1, 0, 1, 0, 1].repeatStream;
    auto arr2 = [0, 0, 1, 1, 0, 0, 1, 1].repeatStream;
    auto mx1 = arr1.adder(arr2);
    static assert(isInfinite!(typeof(mx1)));
    static assert(isInputStream!(typeof(mx1)));

    int[] buf1 = new int[16];
    assert(mx1.read(buf1) == [0, 1, 1, 2, 0, 1, 1, 2, 0, 1, 1, 2, 0, 1, 1, 2]);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr1 = [0, 1, 0, 1, 0, 1, 0, 1].repeatStream;
    auto buf1 = arr1.adder(arr1).adder(arr1).read(new int[16]);
    auto buf2 = arr1.amplifier(3).read(new int[16]);

    assert(buf1 == buf2);
}


/**
積分器です。
積分するサンプル量が大きい場合の使用に適しています。
*/
auto accumulator(E)(size_t integN)
{
    static struct Accumulator
    {
        E[] write(E[] buf)
        {
            while(buf.length){
                immutable n = min(_integN - _cnt, buf.length);
                auto ptr = buf.ptr;
                const end = buf.ptr + n;
                auto val = _buffer.back;
                while(ptr != end){
                    val += *ptr;
                    ++ptr;
                }

                _cnt += n;
                _buffer.back = val;
                buf = buf[n .. $];
                if(_cnt == _integN){
                    _buffer ~= cast(E)0;
                    _cnt = 0;
                    ++_avaN;
                }
            }

            return buf;
        }


        enum bool fill = false;
        bool flush() { return false; }


        auto opSlice(){ return _buffer[].take(_avaN); }

        E front() const @property { return _buffer.front; }
        void popFront() { _buffer.removeFront(); --_avaN; }
        bool empty() const @property { return _avaN == 0; }


      private:
        DList!E _buffer;
        size_t _cnt;
        size_t _integN;
        size_t _avaN;
    }


    return Accumulator(DList!E(cast(E)0), 0, integN, 0);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto acc = accumulator!int(4);
    static assert(isOutputStream!(typeof(acc), int));

    assert(acc.write([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]).empty);
    assert(equal(acc[], [0+1+2+3, 4+5+6+7]));

    acc.write([10, 11]);
    assert(equal(acc[], [0+1+2+3, 4+5+6+7, 8+9+10+11]));
}


/**
積分器です。
たとえば、連続する少数の個数のサンプルの和を取るような用途に適しています。
*/
auto accumulator(size_t N, Sg)(Sg sg, size_t bufSize = 1024 * 1024)
{
    alias E = Unqual!(ElementType!Sg);
    return accumulator(sg, new E[bufSize]);
}


/// ditto
auto accumulator(size_t N, Sg, E)(Sg sg, E[] buffer)
if(isInputStream!Sg && is(ElementType!Sg : E))
{
    static struct Accumulator()
    {
        auto front() const @property { return availables[0]; }
        void popFront() { consume(1); }
        bool empty() const @property { return _pos == _end; }

        bool fetch()
        {
            if(!this.empty) return false;
            auto p = _buffer.ptr + _buffer.length - _remN,
                 f = _buffer.ptr;
            const e = _buffer.ptr + _buffer.length;
            while(p != e) { *f = *p; ++f; ++p; }
            _pos = 0;
            _end = 0;

            while(this.empty && (!_sg.empty || !_sg.fetch())){
                auto buf = _sg.read(_buffer[_remN .. $]);
                immutable size_t len = (_remN + buf.length) / N;
                _end += len;

                auto pp = _buffer.ptr,
                     ff = _buffer.ptr;
                auto ee = _buffer.ptr + _end;

                while(pp != ee){
                    size_t s = 1;
                    if(pp != _buffer.ptr) { *pp = 0; s = 0; }

                    ff += s;
                    foreach(i; s .. N){
                        *pp += *ff;
                        ++ff;
                    }

                    ++pp;
                }
                _remN = (_remN + buf.length) - _end * N;
            }

            return this.empty;
        }


        T[] readOp(alias func, T)(T[] buf)
        {
            immutable minL = min(buf.length, _end - _pos);
          static if(is(typeof(mixin(`buf[]` ~ func ~ `= _buffer[]`))))
            mixin(`buf[0 .. minL] ` ~ func ~ "= _buffer[_pos .. _pos + minL];");
          else
          {
            auto rem_ptr = buf.ptr,
                 buf_ptr = () @trusted { return _buffer.ptr + _pos; }();
            const rem_end = () @trusted { return rem_ptr + minL; }();

            while(rem_ptr != rem_end){
                binaryFunExt!func(*rem_ptr, *buf_ptr);
                () @trusted { ++rem_ptr; ++buf_ptr; }();
            }
          }
            _pos += minL;
            return buf[0 .. minL];
        }


        auto readOp(alias func, E, size_t N)(SIMDArray!(E, N) buf)
        {
            auto b = readOp(buf.array);
            return buf[0 .. b.length];
        }


        T[] read(T)(T[] buf) { return readOp!""(buf); }

        //mixin(defaultStreamSIMDOperator);


        const(E)[] availables() const @property { return _buffer[_pos .. _end]; }
        void consume(size_t n)
        {
            while(n && (!this.empty || !this.fetch())){
                if(n <= _end - _pos){
                    _pos += n;
                    n = 0;
                }else{
                    n -= _end - _pos;
                    _pos = _end;
                }
            }
        }


      private:
        Sg _sg;
        E[] _buffer;
        size_t _pos;
        size_t _end;
        size_t _remN;
    }


    return Accumulator!()(sg, buffer, 0, 0, 0);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatStream;
    auto acc = accumulator!4(arr1, new int[14]);
    static assert(isBufferedInputStream!(typeof(acc)));

    int[] buf = new int[3];
    assert(!acc.empty || !acc.fetch());
    assert(acc.read(buf) == [0+1+2+3, 4+5+6+7, 8+9+0+1]);
    assert(!acc.empty || !acc.fetch());
    assert(acc.read(buf) == [2+3+4+5, 6+7+8+9, 0+1+2+3]);
}

/+ ベンチマーク, rangeの3倍程度の性能
unittest {
    static real[] vector;
    vector = new real[1024 * 1024];
    foreach(ref e; vector) e = 0;


    void funcStream()
    {
        alias sin128LutNCO = lutNCO!(std.math.sin, 128);

        auto mx = mixer(sin128LutNCO(6.5E6L, 1E-6L, 0),
                        sin128LutNCO(6.6E6L, 1E-6L, 0));

        mx.readOp!"*"(vector);
    }


    void funcRange()
    {
        alias sin128LutNCO = lutNCO!(std.math.sin, 128);

        auto mx = zip(sin128LutNCO(6.5E6L, 1E-6L, 0), sin128LutNCO(6.6E6L, 1E-6L, 0))
                 .map!"a[0]*a[1]";

        auto ptr = vector.ptr, end = ptr + vector.length;
        while(ptr != end){
            *ptr *= mx.front;
            mx.popFront();
            ++ptr;
        }
    }

    
    import std.datetime;
    import std.container;
    auto ts = benchmark!(funcStream, funcRange)(26);

    writefln("%(\n%s%)", ts[].map!"a.usecs");
}
+/


auto amplifier(Sg, F)(Sg sg, F gain)
{
    static struct Amplifier()
    {
        auto front() const @property { return _sg.front * _gain; }
        void popFront() { _sg.popFront(); }
        bool empty() const { return _sg.empty; }
        bool fetch() { return _sg.fetch(); }


        E[] readOp(string op, E)(E[] buf)
        if((op == "*" || op == "/") && isInplaceComputableStream!(Sg, op, E))
        {
            buf = _sg.readOp!op(buf);
            mixin("buf[]" ~ op ~ "= _gain;");

            return buf;
        }


        auto readOp(string op, E, size_t N)(SIMDArray!(E, N) buf)
        if((op == "*" || op == "/") && isInplaceComputableStream!(Sg, op, E))
        {
            buf = _sg.readOp!op(buf);
            mixin("buf" ~ op ~ "= _gain;");

            return buf;
        }


        E[] read(E)(E[] buf)
        {
            buf = _sg.read(buf);
            buf[] *= _gain;

            return buf;
        }


        auto read(E, size_t N)(SIMDArray!(E, N) buf)
        {
            buf = _sg.read(buf);
            buf *= _gain;
        }


        F gain() const @property pure nothrow @safe @nogc { return _gain; }
        void gain(F g) @property pure nothrow @safe @nogc { _gain = g; }


      private:
        Sg _sg;
        F _gain;
    }


    return Amplifier!()(sg, gain);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr4 = [0, 1, 2, 3].repeatStream,
         amped = arr4.amplifier(4);

    assert(amped.read(new int[4]) == [0, 4, 8, 12]);
    static assert(isInplaceComputableStream!(typeof(arr4)));
    static assert(isInplaceComputableStream!(typeof(amped), "*"));
    static assert(isInplaceComputableStream!(typeof(amped), "/"));

    auto arr = [3, 4, 1, 2];
    assert(amped.readOp!"*"(arr) == [0, 16, 8, 24]);
}


auto selector(Sg...)(Sg sgs)
{
    static struct Selector()
    {
        import std.string : format;


        auto front() const @property
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: return _sgs[%s].front;", i, i));
              default: assert(0);
            }
        }


        void popFront()
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: _sgs[%s].popFront();", i, i));
              default: assert(0);
            }
        }


        bool empty() const @property
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: return _sgs[%s].empty;", i, i));
              default: assert(0);
            }
        }


        bool fetch()
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: return _sgs[%s].fetch();", i, i));
              default: assert(0);
            }
        }


        E[] read(E)(E[] buf)
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: return _sgs[%s].read(buf);", i, i));
              default: assert(0);
            }
        }


        E[] readOp(alias op, E)(E[] buf)
        {
            switch(_selectIndex){
              foreach(i, E; Sg)
                mixin(format("case %s: return _sgs[%s].readOp!op(buf);", i, i));
              default: assert(0);
            }
        }


        //mixin(defaultStreamSIMDOperator);


        void select(size_t i)
        in{
            assert(i < Sg.length);
        }
        body{
            _selectIndex = i;
        }


        void select(size_t i)()
        {
            static assert(i < Sg.length);
            _selectIndex = i;
        }


      private:
        Sg _sgs;
        size_t _selectIndex;
    }


    return Selector!()(sgs, 0);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr1 = 0.repeatStream,
         arr2 = [0, 1].repeatStream,
         arr3 = [0, 1, 2].repeatStream,
         arr4 = [0, 1, 2, 3].repeatStream;

    auto slt = selector(arr1, arr2, arr3, arr4);
    assert(slt.read(new int[4]) == [0, 0, 0, 0]);
    slt.select(1); // or slt.select!1;
    assert(slt.read(new int[4]) == [0, 1, 0, 1]);
    slt.select(2); // or slt.select!2;
    assert(slt.read(new int[4]) == [0, 1, 2, 0]);
    slt.select(3); // or slt.select!3;
    assert(slt.read(new int[4]) == [0, 1, 2, 3]);
}


/**
FIRフィルタを構成します。

FIRフィルタの一般形は、z変換すれば次のような式で表すことができます。
H[z] = Σ(k[m]*z^(-m))

この関数には、各タップの係数`k[m]`を指定することで任意のFIRフィルタを構築することができます。
*/
auto firFilter(alias reduceFn = "a+b*c", Sg, E)(Sg sg, const E[] taps)
if(isInputStream!Sg)
{
    return firFilter!(reduceFn, Sg, Unqual!E)(sg, taps, new Unqual!E[](taps.length));
}


///
auto firFilter(alias reduceFn = "a+b*c", Sg, E)(Sg sg, const E[] tap, E[] buf)
if(isInputStream!Sg && is(E == Unqual!E))
in{
    assert(tap.length == buf.length);
}
body{
    static struct FIRFiltered()
    {
        E front() const @property @trusted
        {
            E a = 0;

            {
                auto p1 = _tap[$ - 1 .. $].ptr,
                     p2 = _buf[_idx .. $].ptr,
                     e2 = _buf[$ .. $].ptr;

                while(p2 != e2){
                    a = naryFun!reduceFn(a, *p2, *p1);
                    --p1;
                    ++p2;
                }
            }

            {
                auto p1 = _tap.ptr + _idx-1,
                     p2 = _buf[0 .. _idx].ptr,
                     e2 = _buf[_idx .. $].ptr;

                while(p2 != e2){
                    a = naryFun!reduceFn(a, *p2, *p1);
                    --p1;
                    ++p2;
                }
            }

            return a;
        }


        void popFront()
        {
            _buf[_idx] = _sg.front;
            ++_idx;
            _idx %= _buf.length;
            _sg.popFront();
        }

      static if(isInfinite!Sg)
        enum bool empty = false;
      else
        bool empty() const @property { return _sg.empty; }


        bool fetch() { return _sg.fetch(); }


        U[] readOp(alias op, U)(U[] buf)
        {
            auto p = buf.ptr,
                 e = buf[$ .. $].ptr;

            while(p != e && !this.empty){
                binaryFunExt!op(*p, this.front);
                this.popFront();
                () @trusted { ++p; }();
            }

            return () @trusted { return buf[0 .. p - buf.ptr]; }();
        }


        U[] read(U)(U[] buf)
        {
            return readOp!""(buf);
        }


        //mixin(defaultStreamSIMDOperator);


      private:
        Sg _sg;
        const(E)[] _tap;
        E[] _buf;
        size_t _idx;
    }


    return FIRFiltered!()(sg, tap, buf, 0);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr = [0, 1, 2, 3].repeatStream,
         flt1 = arr.firFilter([0, 1]);

    assert(flt1.read(new int[8]) == [0, 0, 0*1+1*0, 1, 2, 3, 0, 1]);

    auto flt2 = arr.firFilter([1, 2]);
    assert(flt2.read(new int[6]) == [0, 0, 0*2+1*1, 1*2+2*1, 2*2+3*1, 3*2+0*1]);
}


/*
IIRフィルタを構成します。

IIRフィルタの一般形は、z変換すれば次のような式で表すことができます。
H(z) = 1/Σ(k[m]*z^(-m))

この関数には、各タップの係数`k[m]`を指定することで任意のIIRフィルタを構築することができます。
*/
//auto iirFilter(alias reduceFn = "a+b*c", Sg, E)(Sg sg, const E[] taps)
//if(isInputStream!Sg)
//{
//    return iirFilter!(reduceFn, Sg, Unqual!E)(sg, taps, new Unqual!E()(taps.length));
//}

/////
//auto iirFilter(alias reduceFn = "a+b*c", Sg, E)(Sg sg, const E[] taps, E[] buf)
//if(isInputStream!Sg && is(E == Unqual!E))
//{

//}


/**
信号の絶対値の最大値を`limit`にするように線形に振幅を小さく、もしくは大きくします。
*/
auto normalizer(Sg, E)(Sg sg, E limit)
if(isFloatingPoint!E)
{
    static struct Normalizer()
    {
        E front() @property
        {
            auto f = _sg.front,
                 a = abs(f);

            if(f == 0) return 0;

            if(a > _max){
                _max = a;

                return _lim;
            }

            return f / _max * _lim;
        }


        auto empty() const @property { return _sg.empty; }
        void popFront() { _sg.popFront(); }

        bool fetch() { return _sg.fetch(); }


        U[] read(U)(U[] buf)
        {
            buf = _sg.read(buf);

            auto p = buf.ptr,
                 e = buf[$ .. $].ptr;

            while(p != e){
                immutable v = abs(*p);
                if(v == 0)
                    *p = 0;
                else{
                    if(v > _max)
                        _max = v;

                    *p *= _lim / _max;
                }

                () @trusted { ++p; }();
            }

            return buf;
        }


        U[] readOp(alias op : "", U)(U[] buf)
        {
            return this.read(buf);
        }


        E[] readOp(alias op, E)(E[] buf)
        {
            auto p = buf.ptr,
                 e = buf[$ .. $].ptr;

            while(p != e && !this.empty){
                binaryFunExt!op(*p, this.front);
                this.popFront();
                () @trusted { ++p; }();
            }

            return buf;
        }

        //mixin(defaultStreamSIMDOperator);


      private:
        Sg _sg;
        E _lim;
        E _max;
    }

    return Normalizer!()(sg, limit, 0);
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr = [0, 1, -2, 3].repeatStream,
         nlz = arr.normalizer(1.5);

    assert(equal!approxEqual(nlz.read(new float[8]), [0, 1.5, -1.5, 1.5, 0, 0.5, -1.0, 1.5]));
}



/**
信号をマッピングします
*/
auto mapper(alias fn, Sg)(Sg sg, ElementType!Sg[] buf = null, size_t bufSize = 1024)
if(isInputStream!Sg && is(typeof({sg.read(buf);})))
{
    if(buf is null)
        buf.length = bufSize;

    static struct Result
    {
        alias E = ElementType!Sg;

        auto front() @property { return unaryFun!fn(_sg.front); }
        bool empty() const @property { return _sg.empty; }
        void popFront() { _sg.popFront(); }

        bool fetch() { return _sg.fetch(); }

        U[] readOp(alias op, U)(U[] outbuf)
        {
            if(_buf.length < outbuf.length)
                _buf.length = outbuf.length;

            auto ib = _buf[0 .. outbuf.length];
            ib = _sg.read(ib);

            auto p = ib.ptr,
                 e = ib[$ .. $].ptr,
                 q = outbuf.ptr;

            while(p != e){
                binaryFunExt!op(*q, unaryFun!fn(*p));
                () @trusted { ++p; ++q; }();
            }

            return outbuf[0 .. ib.length];
        }


        U[] read(U)(U[] buf)
        {
            return readOp!""(buf);
        }

        //mixin(defaultStreamSIMDOperator);


      private:
        Sg _sg;
        E[] _buf;
    }

    return Result(sg, buf);
}


/**

*/
auto arrayMapper(Sg, E)(Sg sg, in E[] arr, size_t[] buf = null, size_t bufSize = 1024)
if(isInputStream!Sg && is(ElementType!Sg : size_t))
{
    if(buf is null)
        buf.length = bufSize;

    static struct Result
    {
        auto front() @property { return _arr[_sg.front]; }
        bool empty() const @property { return _sg.empty; }
        void popFront() { _sg.popFront(); }

        bool fetch() { return _sg.fetch(); }

        U[] readOp(alias op, U)(U[] outbuf)
        {
            if(_buf.length < outbuf.length)
                _buf.length = outbuf.length;

            auto ib = _buf[0 .. outbuf.length];
            ib = _sg.read(ib);

            auto p = ib.ptr,
                 e = ib[$ .. $].ptr,
                 q = outbuf.ptr;

            while(p != e){
                binaryFunExt!op(*q, _arr[*p]);
                () @trusted { ++p; ++q; }();
            }

            return outbuf[0 .. ib.length];
        }


        U[] read(U)(U[] buf)
        {
            return readOp!""(buf);
        }


        //mixin(defaultStreamSIMDOperator);


      private:
        Sg _sg;
        const(E)[] _arr;
        size_t[] _buf;
    }

    return Result(sg, arr, buf);
}
