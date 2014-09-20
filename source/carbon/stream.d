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
       carbon.functional;

import std.algorithm,
       std.container,
       std.file,
       std.functional,
       std.math,
       std.range,
       std.stdio,
       std.traits;


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
enum bool isInputStream(T) = is(typeof((T t){
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
        rem = s.read(rem);
    
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
enum bool isInplaceComputableStream(T) = isInputStream!T &&
    is(typeof((T t){
        alias E = Unqual!(ElementType!T);
        E[] buf = t.readOp!""(new E[1024]);   // as read(buf)

      static if(is(typeof(E.init + E.init) == E)){
        buf = t.readOp!"+"(buf);        // OK, `a += b`
        buf = t.readOp!"a+b"(buf);      // OK, `a = a + b`

        buf = t.readOp!(naryFun!"a+b")(buf);
      }
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
enum bool fillBufferOp(alias op, S, E)(ref S s, E[] buffer)
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
/*
auto ref A binaryFunExt(alias func, A, B)(auto ref A a, auto ref B b)
if(is(typeof(func) == string) && is(typeof(a = binaryFun!func(a, forward!b))))
{
    a = binaryFun!func(a, forward!b);
    return a;
}
*/

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

        E[] readOp(alias func)(E[] buf)
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

        E[] read(E[] buf) { return readOp!""(buf); }
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
        PreciseComplexNCO save() const @property { return this; }
        creal opIndex(size_t i) const @property { return std.math.expi(_theta + i * _dt2PI * _freq); }
        struct OpDollar{} enum OpDollar opDollar = OpDollar();
        PreciseComplexNCO opSlice() const { return this; }
        PreciseComplexNCO opSlice(size_t i, OpDollar) const { PreciseComplexNCO dst = this; dst._theta += i * _dt2PI * _freq; return dst; }
        auto opSlice(size_t i, size_t j) const { return this[i .. $].take(j - i); }

        enum closed = false;
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


        creal[] read(creal[] buf){ return readOp!""(buf); }

      @property
      {
        real freq() const pure nothrow @safe @nogc { return _freq; }
        void freq(real f) pure nothrow @safe @nogc { _freq = f; }

        real deltaT() const pure nothrow @safe @nogc { return _dt2PI / 2 / PI; }
        void deltaT(real dt) pure nothrow @safe @nogc { _dt2PI = dt * 2 * PI; }
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

この局部発振器は周波数の動的な制御が可能であり、信号のドップラーシフトの追尾に最適です。
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

        real freq() const @property { return _freq; }
        void freq(real f) @property { _freq = f; }
        real deltaT() const @property { return _deltaT; }
        void deltaT(real t) @property { _deltaT = t; }

        enum bool closed = false;
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


        E[] read(E[] buf) @safe { return readOp!""(buf); }

      private:
        real _phase;
        real _freq;
        real _deltaT;
    }


    LutNCO!() lutNCO(real freq, real deltaT, real theta = 0) pure nothrow @safe @nogc
    {
        return LutNCO!()(theta, freq, deltaT);
    }
}


///
unittest{
    auto sig1 = lutNCO!(std.math.expi, 4)(1, 0.25, 0);
    static assert(isInputStream!(typeof(sig1)));
    static assert(isInplaceComputableStream!(typeof(sig1)));
    static assert(is(ElementType!(typeof(sig1)) == creal));

    assert(equal!((a, b) => approxEqual(a.re, b.re) && approxEqual(a.im, b.im))
        (sig1[0 .. 1024], preciseComplexNCO(1, 0.25, 0)[0 .. 1024]));

    sig1 = lutNCO!(std.math.expi, 4)(1000, 10.0L^^-6, std.math.E);
    auto buf = sig1[0 .. 1024].array;
    assert(sig1.readOp!"-"(buf).length == buf.length);
    assert(equal!"a == 0"(buf, buf));
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
        RepeatStream!() save() const { return this; }
        const(E) opIndex(size_t i) const { return _arr[_pos % $]; }
        RepeatStream!() opSlice(){ return this; }
        struct OpDollar{} enum opDollar = OpDollar();
        RepeatStream!() opSlice(size_t i, OpDollar){ typeof(return) dst; dst._pos = (_pos + i) % _arr.length; return dst; }
        auto opSlice(size_t i, size_t j){ return this[i .. $].take(j - i); }


        enum bool closed =  false;
        bool fetch() { return false; }

        U[] readOp(alias op, U)(U[] buf)
        {
            auto rem = buf;
            while(rem.length){
                auto minL = min(rem.length, _arr.length - _pos);

              static if(is(typeof(mixin(`rem[]` ~ func ~ `=_arr[]`))))
                mixin(`rem[0 .. minL] `~ func ~ "= _arr[_pos .. _pos + minL];");
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


/**
一度に巨大なファイルを読み込むことに特化したバッファ持ち入力ストリームです。
*/
auto rawFileStream(T)(string filename, size_t bufferSize = 1024 * 1024)
if(is(Unqual!T == T))
{
    static struct RawFileStream()
    {
        private void refill()
        {
            _pos = 0;
            immutable beforeSize = _buffer.length;
            _buffer = _file.rawRead(_buffer);
            if(_buffer.length != beforeSize)
                _file.detach();
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
        if(isAssignable!(E, T))
        { return readOp!""(buf); }


        /// ditto
        alias closed = empty;


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


    auto dst = RawFileStream!()(new T[bufferSize], 0,File(filename));
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
    assert(sig1.closed && sig1.empty);
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
    assert(sig1.closed && sig1.empty);
}


/**
二つの信号の積を返します。
２つ目の信号は演算による理想信号でなければいけません。
*/
auto mixer(Sg1, Sg2)(Sg1 sg1, Sg2 sg2)
if(isInputStream!Sg1 && isInputStream!Sg2 && isInfinite!Sg2)
{
    static struct Mixer()
    {
        auto ref front() const @property { return _sg1.front * _sg2.front; }

      static if(isInfinite!Sg1)
        enum bool empty = false;
      else
        bool empty() const @property { return _sg1.empty; }

        void popFront() { _sg1.popFront(); _sg2.popFront(); }

        bool closed() const @property { return _sg1.closed; }
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
            auto buf1 = _sg1.read(buf);
            return _sg2.readOp!"*"(buf1);  // always, return buf1
        }


        E[] readOp(alias op, E)(E[] buf)
        if(op == "*" || op == "/")
        {
            auto buf1 = _sg1.readOp!op(buf);
            return _sg2.readOp!op(buf1);
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


auto accumulator(size_t N, Sg, E)(Sg sg, E[] buffer)
if(isInputStream!Sg && is(ElementType!Sg : E))
{
    static struct Accumulator()
    {
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


        T[] read(T)(T[] buf) { return readOp!""(buf); }


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
