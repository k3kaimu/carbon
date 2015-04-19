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
このモジュールは、標準ライブラリのstd.functionalを強化します。
*/

module carbon.functional;

import std.algorithm,
       std.array,
       std.format,
       std.functional,
       std.range,
       std.string,
       std.traits,
       std.typecons;

/**
このテンプレートは、$(M std.functional.unaryFun)や$(M std.functional.binaryFun)を一般化し、
N個の引数を取れるようにしたものです。
$(M unaryFun)や$(M binaryFun)のように文字列に対して作用する場合は、その文字列で表される関数となります。
対して、文字列以外を$(M naryFun)に適用した場合には、その対象へのaliasとなります。

文字列による形式には、現在のところアルファベット及び数字に対応しています。
*/
template naryFun(alias fun, int N = -1)
if(is(typeof(fun) == string))
{
    auto ref naryFunAlphabet(T...)(auto ref T args)
    {
        static assert(T.length <= 26);
        mixin(createAliasAlphabet(T.length));
        return mixin(fun);
    }


    auto ref naryFunNumber(T...)(auto ref T args)
    {
        mixin(createAliasNumber(T.length));
        return mixin(fun);
    }


    auto ref naryFun(T...)(auto ref T args)
    if(!(N >= 0) || T.length == N)
    {
      static if(is(typeof({naryFunNumber(forward!args);})))
        return naryFunNumber(forward!args);
      else
        return naryFunAlphabet(forward!args);
    }


    string createAliasAlphabet(size_t nparam)
    {
        auto app = appender!string();
        foreach(i; 0 .. nparam)
            app.formattedWrite("alias %s = args[%s];\n", cast(char)(i + 'a'), i);
        return app.data;
    }


    string createAliasNumber(size_t nparam)
    {
        auto app = appender!string();
        foreach(i; 0 .. nparam)
            app.formattedWrite("alias _%1$s = args[%1$s];\n", i);
        return app.data;
    }
}

/// ditto
template naryFun(alias fun, int N = -1)
if(!is(typeof(fun) == string))
{
    auto ref naryFun(T...)(auto ref T args)
    if(!(N >= 0) || T.length == N)
    {
        return fun(forward!args);
    }
}

///
unittest
{
    alias test1 = naryFun!"a";
    assert(test1(1) == 1);
    assert(test1(test1(2.0)) == 2.0);
    static assert(is(typeof({test1(1, 1);})));  // OK
                                                // 最初の引数を返す関数だから。
                                                // 2つ目の引数は使用されない。

    static assert(!is(typeof({test1();})));     // NG


    alias test1_1 = naryFun!("a", 1);       // 引数の数を1つとする
    assert(test1_1(1) == 1);
    assert(test1_1(test1(2.0)) == 2.0);
    static assert(!is(typeof({test1_1(1, 1);})));  // NG


    alias test1_2 = naryFun!("a", 2);       // 引数の数を2つとする
    assert(test1_2(1, 1) == 1);
    assert(test1_2(test1_2(2.0, 2), 1) == 2.0);
    static assert(!is(typeof({test1_2(1);})));  // NG


    alias test2 = naryFun!"b";
    assert(test2(1, 2) == 2);
    assert(test2(test2(1, "2"), test2(3.0, '4')) == '4');
    static assert(!is(typeof({test2();})));
    static assert(!is(typeof({test2(1);})));
    static assert(is(typeof({test2(1, 1, 2.2);})));


    // アルファベット
    alias test3 = naryFun!"a + b + c";
    assert(test3(1, 2, 3) == 6);

    import std.bigint;
    assert(test3(BigInt(1), 2, 3) == BigInt(6));


    // 数字
    alias test4 = naryFun!"_0 + _1 + _2 + _3";
    assert(test4(1, 2, 3, 4) == 10);
}


/**
ある関数funcの引数に、タプルを適用できるようにします。
*/
template adaptTuple(alias func, T...)
{
    auto _toRvalue(X)(ref X a)
    {
        return a;
    }


    string _toRvalueNargs(size_t N)
    {
        return format("return func(%(_toRvalue(arg.field[%s])%|,%));", iota(N));
    }


  static if(T.length > 0)
  {
    auto ref adaptTuple(X)(ref X arg)
    if(is(Unqual!X : Tuple!U, U...) && is(typeof({Tuple!T a = Unqual!X.init;})))
    {
        return func(arg.field);
    }

    auto ref adaptTuple(X)(X arg)
    if(is(Unqual!X : Tuple!U, U...) && is(typeof({Tuple!T a = Unqual!X.init;})))
    {
        mixin(_toRvalueNargs(T.length));
    }
  }
  else
  {
    auto ref adaptTuple(X)(ref X arg)
    if(is(Unqual!X == Tuple!U, U...))
    {
        return func(arg.field);
    }


    auto ref adaptTuple(X)(X arg)
    if(is(Unqual!X == Tuple!U, U...))
    {
        mixin(_toRvalueNargs(X.field.length));
    }
  }
}

///
unittest
{
    static ref int func1(ref int a, float b, byte c)
    {
        return a;
    }

    alias adpt1 = adaptTuple!func1;
    auto t = tuple(4, 1.1f, cast(byte)2);
    assert(&adpt1(t) == &(t.field[0]));

    // NG; adpt1の引数がlvalueじゃない(std.forwardのような転送)
    static assert(!is(typeof({adpt1(tuple(4, 1.1f, cast(byte)2));})));

    // naryFun & 事前に型指定あり
    alias adpt2 = adaptTuple!(naryFun!"a", int, float, byte);
    assert(&adpt2(t) == &(t.field[0])); // forward性
    assert(adpt2(tuple(4, 1.1f, cast(byte)2)) == t.field[0]);

    // NG; stringはfloatへ暗黙変換不可能
    static assert(!is(typeof({adpt2(tuple(1, "foo", cast(byte)2));})));

    // OK; realはfloatへ暗黙変換可能
    static assert(is(typeof({adpt2(tuple(1, 1.1L, cast(byte)2));})));
    assert(adpt2(tuple(1, 1.1L, cast(byte)2)) == 1);

    const ct = t;
    static assert(is(typeof(adpt2(ct)) == const));

    immutable it = t;
    static assert(is(typeof(adpt2(it)) == immutable));

    shared st = t;
    static assert(is(typeof(adpt2(st)) == shared));


    assert(adaptTuple!(naryFun!"a")(tuple(1, 2, 3)) == 1);
    assert(adaptTuple!(naryFun!"a", int)(tuple(1)) == 1);
}


/**
関数を信頼関数にします
*/
auto ref assumeTrusted(alias fn, T...)(auto ref T args) @trusted
{
    return naryFun!fn(forward!args);
}


/**

*/
auto ref observe(alias fn, T)(auto ref T v)
{
    fn(forward!v);
    return (forward!v)[0];
}

///
unittest
{
    int b;
    observe!((a){ b = a; })(12);
    assert(b == 12);
}
