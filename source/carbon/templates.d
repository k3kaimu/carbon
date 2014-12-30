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
このモジュールは、様々なtemplateを提供します。
*/

module carbon.templates;

import std.algorithm;
import std.regex;
import std.traits;
import std.typetuple;


/**
あるテンプレートが、テンプレート版レンジかどうか判定します。

Example:
-------
alias head = tmplt.front;   // 先頭要素
alias tail = tmplt.tail!(); // 残り
-------
*/
enum isTemplateRange(alias tmplt) = is(typeof({
  static if(!tmplt.empty){
    alias head = tmplt.front;
    alias tail = tmplt.tail!();
  }
}));

unittest
{
    template number(size_t a, size_t b)
    if(a <= b)
    {
      static if(a == b)
        enum bool empty = true;
      else
      {
        enum bool empty = false;

        enum front = a;

        template tail()
        {
            alias tail = number!(a+1, b);
        }
      }
    }

    static assert(isTemplateRange!(number!(0, 10)));
    static assert(isTemplateRange!(number!(10, 10)));
}


/**
タプルをテンプレート版レンジにします。
*/
template ToTRange(T...)
{
  static if(T.length == 0)
    enum empty = true;
  else
  {
    enum empty = false;

    static if(is(typeof({ alias f = T[0]; })))
      alias front = T[0];
    else
      enum front = T[0];

    alias tail() = ToTRange!(T[1 .. $]);
  }
}


/**
テンプレート版レンジからタプルを作ります。
*/
template ToTuple(alias TR)
{
  static if(TR.empty)
    alias ToTuple = TypeTuple!();
  else
    alias ToTuple = TypeTuple!(TR.front, ToTuple!(TR.tail!()));
}


/**
2つのTemplateRangeが等しいかどうか検証します。
*/
template isEquals(alias pred, alias A, alias B)
if(isTemplateRange!A && isTemplateRange!B)
{
  static if(A.empty)
    enum bool isEquals = B.empty;
  else static if(B.empty)
    enum bool isEquals = false;
  else
    enum bool isEquals = pred!(A.front, B.front) && isEquals!(pred, A.tail!(), B.tail!());
}


/// ditto
template isEqualTypes(alias A, alias B)
if(isTemplateRange!A && isTemplateRange!B)
{
    enum pred(A, B) = is(A == B);
    enum bool isEqualTypes = isEquals!(pred, A, B);
}


/// ditto
template isEqualValues(alias A, alias B)
if(isTemplateRange!A && isTemplateRange!B)
{
    enum pred(alias A, alias B) = A == B;
    enum bool isEqualValues = isEquals!(pred, A, B);
}


///
unittest
{
    enum predT(A, B) = is(A == B);
    alias Ts1 = ToTRange!(int, int, long);
    alias Ts2 = ToTRange!(int, int, long);

    static assert(isEquals!(predT, Ts1, Ts2));
    static assert(isEqualTypes!(Ts1, Ts2));

    enum predV(alias A, alias B) = A == B;
    alias Vs1 = ToTRange!(1, 2, 3);
    alias Vs2 = ToTRange!(1, 2, 3);

    static assert(isEquals!(predV, Vs1, Vs2));
    static assert(isEqualValues!(Vs1, Vs2));
}


/**
テンプレート版レンジでの$(D_CODE std.range.iota)です。
*/
template TRIota(size_t a, size_t b)
if(a <= b)
{
  static if(a == b)
    enum empty = true;
  else
  {
    enum empty = false;
    enum front = a;
    alias tail() = TRIota!(a+1, b);
  }
}

///
unittest
{
    alias Is = TRIota!(0, 10);
    alias Rs = ToTRange!(0, 1, 2, 3, 4, 5, 6, 7, 8, 9);

    static assert(isEqualValues!(Is, Rs));
}


/**
テンプレート版レンジでの、$(D_CODE std.algorithm.map)に相当します。
*/
template TRMap(alias tmpl, alias TR)
if(isTemplateRange!TR)
{
  static if(TR.empty)
    enum empty = true;
  else
  {
    enum empty = false;
    alias front = tmpl!(TR.front);
    alias tail() = TRMap!(tmpl, TR.tail!());
  }
}

///
unittest
{
    alias Ts = TypeTuple!(int, long, char);
    alias ToConstArray(T) = const(T)[];
    alias Result = ToTuple!(TRMap!(ToConstArray, ToTRange!Ts));

    static assert(is(Result
                      == TypeTuple!(const(int)[],
                                    const(long)[],
                                    const(char)[])));
}

/+
template TRReduce(alias tmpl, alias TR)
if(isTemplateRange!TR && !TR.empty)
{
  static if(TR.empty)
    alias Reduce = TypeTuple!();
  else
    alias Reduce = Reduce!(tmpl, TR.front, TR.tail!());
}


template Reduce(alias tmpl, alias Ini, alias TR)
{
  static if(TR.empty)
    alias Reduce = Ini;
  else
    alias Reduce = Reduce!(tmpl, tmpl!(Ini, TR.front), TR.tail!());
}


/**
永遠とタプルを返すようなテンプレートレンジを返します。
*/
template Repeat(T...)
{
    enum empty = false;
    alias front = T;
    alias tail() = Repeat!T;
}


///
template RepeatN(size_t N, T...)
{
  static if(N == 0)
    enum empty = true;
  else
  {
    enum empty = false;
    alias front = T;
    alias tail() = Repeat!(N-1, T);
  }
}


/**
Template RangeのZipバージョンです
*/
template Zip(alias TR1, alias TR2)
if(isTemplateRange!TR1 && isTemplateRange!TR2)
{
  static if(TR1.empty)
    alias Zip = TR2;
  else static if(TR2.empty)
    alias Zip = TR1;
  else
  {
    enum empty = false;
    alias front = TypeTuple!(TR1.front, TR2.front);
    alias tail() = Zip!(TR1.tail!(), TR2.tail!());
  }
}


/**

*/
template Take(alias TR, size_t N)
if(isTemplateRange!TR)
{
  static if(TR1.empty || N == 0)
    enum empty = true;
  else
  {
    enum empty = false;
    alias front = TR1.front;
    alias tail() = Take!(TR1.tail!(), N-1);
  }
}
+/


/**
ある型や値をN個並べたタプルを返します
*/
template TypeNuple(A...)
if(A.length == 2 && is(typeof(A[1]) : size_t))
{
  static if(A[1] == 0)
    alias TypeNuple = TypeTuple!();
  else
    alias TypeNuple = TypeTuple!(A[0], TypeNuple!(A[0], A[1] - 1));
}

///
unittest
{
    static assert(is(TypeNuple!(int, 2) == TypeTuple!(int, int)));
    static assert(is(TypeNuple!(long, 3) == TypeTuple!(long, long, long)));
}


/**
自身を返します
*/
alias Identity(alias A) = A;
alias Identity(A) = A;  /// ditto

///
unittest
{
    static assert(is(int == Identity!int));
}


/**
大域変数を宣言定義初期化します。

Example:
--------
module foo;

import std.stdio;
import graphite.utils.logger;
import carbon.templates;

mixin defGlobalVariables!("logger", "logFile",
{
    auto file = File("foo.txt", "w");
    return tuple(.logger!(LogFormat.readable)(file), file);
});
--------
*/
mixin template defGlobalVariables(A...)
if(A.length >= 2 && is(typeof(A[$-1]())))
{
    private alias idstrs = A[0 .. $-1];

    import std.typecons;
  static if(idstrs.length == 1 && is(typeof(A[$-1]()) == Tuple!E, E...))
    private enum fn = (() => A[$-1]().tupleof[0]);
  else
    private alias fn = A[$-1];

    private string[2] makeCode()
    {
        import std.array, std.format, std.string;
        auto defs = appender!string();
        auto inis = appender!string();

      static if(idstrs.length >= 2)
      {
        foreach(i, e; idstrs){
            auto sp = e.split();

            if(sp.length >= 2)
                defs.formattedWrite("%s typeof(fn()[%s]) %s;\n", sp[0], i, sp[1]);
            else
                defs.formattedWrite("typeof(fn()[%s]) %s;\n", i, sp[0]);

            inis.formattedWrite("%s = inits[%s];\n", sp[$-1], i);
        }
      }
      else
      {
        auto sp = idstrs[0].split();
        if(sp.length >= 2)
            defs.formattedWrite("%s typeof(fn()) %s;\n", sp[0], sp[1]);
        else
            defs.formattedWrite("typeof(fn()) %s;\n", sp[0]);

        inis.formattedWrite("%s = inits;\n", sp[$-1]);
      }

        return [defs.data, inis.data];
    }

    private enum defInitCode = makeCode();
    mixin(defInitCode[0]);

    static this()
    {
        auto inits = fn();
        mixin(defInitCode[1]);
    }
}


version(unittest)
{
  mixin defGlobalVariables!("foobarNhogehoge", "immutable foofoobogeNbar",
  (){
      return tuple(12, 13);
  });

  mixin defGlobalVariables!("myonmyonNFoo",
  (){
      return tuple(2);
  });

  mixin defGlobalVariables!("momimomiNFoo",
  (){
    return 3;
  });

  unittest{
    assert(foobarNhogehoge == 12);
    assert(foofoobogeNbar == 13);
    static assert(is(typeof(myonmyonNFoo) == int));
    assert(myonmyonNFoo == 2);
    static assert(is(typeof(momimomiNFoo) == int));
    assert(momimomiNFoo == 3);
  }
}


/**
式を埋め込み可能な文字列リテラルを構築します
*/
template Lstr(alias str)
if(isSomeString!(typeof(str)))
{
    import std.array, std.algorithm;
    enum string Lstr = `(){ import std.format; import std.array; auto app = appender!string();` ~ generate(str) ~ ` return app.data ;}()`;

    string generate(string s)
    {
        if(s.empty) return ``;

        auto swF = s.findSplit("%[");
        if(swF[1].empty) return `app ~= "` ~ s ~ `";`;

        auto swE = swF[2].findSplit("%]");
        if(swE[1].empty) return  `app ~= "` ~ s ~ `";`;

        if(swE[0].empty) return `app ~= "` ~ swF[0] ~ `";`;

        return `app ~= "` ~ swF[0] ~ `"; app.formattedWrite("%s", ` ~ swE[0] ~ `);` ~ generate(swE[2]);
    }
}

///
unittest{
    {
        int a = 12, b = 13;

        assert(mixin(Lstr!"aaaa") == "aaaa");

        // %[ から %] までがDの任意の式を表す。
        assert(mixin(Lstr!`foo%[a+b%]bar%[a+10%]%[a%]`) == "foo25bar2212");
    }

    {
        int a = 12;
        string b = "3";
        auto t = tuple(a, b);
        string str = mixin(Lstr!`Element1 : %[t[0]%], Element2 : %[t[1]%]`);
        assert(str == `Element1 : 12, Element2 : 3`);
    }

    {
        int a = 12;
        assert(mixin(Lstr!`foo%[a%]`) == "foo12");
        assert(mixin(Lstr!`foo%[a%`) == `foo%[a%`);
        assert(mixin(Lstr!`foo%[a`) == `foo%[a`);
        assert(mixin(Lstr!`foo%[%]`) == `foo`);
        assert(mixin(Lstr!`foo%[`) == `foo%[`);
        assert(mixin(Lstr!`foo%`) == `foo%`);
    }
}
