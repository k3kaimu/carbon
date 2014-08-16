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
あるテンプレートが、テンプレートレンジかどうか判定します。

Example:
-------
alias head = tmplt.front!();
alias tail = tmplt.tail!();
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

unittest
{
    static assert(is(TypeNuple!(int, 2) == TypeTuple!(int, int)));
    static assert(is(TypeNuple!(long, 3) == TypeTuple!(long, long, long)));
}


/**
自身を返します
*/
template Identity(alias A)
{
    alias Identity = A;
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


