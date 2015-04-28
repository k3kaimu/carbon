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
このモジュールではstd.typecons.Tupleとは違った無名型を構築します。
*/
module carbon.nonametype;


auto refT(alias var)() @safe
{
    static struct RefT
    {
        auto ref get() pure nothrow @safe @nogc @property { return a; }
        alias get this;
    }

    return RefT();
}


auto refP(T)(T* p) @safe
{
    static struct RefP
    {
        auto ref get() pure nothrow @safe @nogc inout @property { return *_p; }
        alias get this;
        private T* _p;
    }

    return RefP(p);
}


auto scopeRef(string str = "system", T)(ref T v)
if(str == "system" || str == "trusted")
{
    mixin(`return () @` ~ str ~ ` { return refP(&v); }();`);
}


@safe
unittest {
    int a;
    auto p = a.scopeRef!"trusted";
    assert(p == 0);

    p = 12;
    assert(a == 12);

    auto q = p;
    ++q;
    assert(a == p && a == 13);
}


class AssumeImplemented(C) : C
if(is(C == class))
{
    import std.functional : forward;

    this(T...)(auto ref T args)
    {
        super(forward!args);
    }
}


abstract class AssumeAbstract(C) : C
if(is(C == class))
{
    import std.functional : forward;

    this(T...)(auto ref T args)
    {
        super(forward!args);
    }
}


class Override(C, string method)
if(is(FuncType == function) && (is(C == class) || is(C == interface)))
{
    import std.functional : forward;

    this(T...)(auto ref T args)
    {
        super(forward!args);
    }


    mixin("override " ~ method);
}

unittest
{
    class C { int foo() { return 1; } }
    auto d = new Override!(C, "int foo(){ return 2; }")();
    assert(d.foo() == 2);
}


class Implement(C, string fields) : C
if(is(C == class) || is(C == interface))
{
    import std.functional : forward;

    this(T...)(auto ref T args)
    {
        super(forward!args);
    }


    mixin(fields);
}
