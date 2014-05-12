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
このモジュールは、標準ライブラリのstd.traitsを強化します。
*/

module carbon.traits;

import carbon.templates;

import std.traits,
       std.typetuple;


struct FuncAttr 
{
  static:
    /*
    proxy std.traits.functionAttributes
    */
    private template hasFA(FunctionAttribute fa, func...)
    if(func.length == 1 && isCallable!func)
    {
        enum bool hasFA = !!(functionAttributes!func & fa);
    }


    /**
    true if func is pure
    */
    template isPure(func...)
    if(func.length == 1 && isCallable!func)
    {
        enum isPure = hasFA!(FunctionAttribute.pure_, func);
    }

    unittest
    {
        void foo() pure {}
        void bar() {}

        static assert(isPure!foo);
        static assert(!isPure!bar);

        static void hoge() pure {}
        static void hage() {}

        static assert(isPure!hoge);
        static assert(!isPure!hage);
    }


    /**
    true if func is nothrow
    */
    template isNothrow(func...)
    if(func.length == 1 && isCallable!func)
    {
        enum isNothrow = hasFA!(FunctionAttribute.nothrow_, func);
    }


    /**
    true if func is ref
    */
    template isRef(func...)
    if(func.length == 1 && isCallable!func)
    {
        enum isNothrow = hasFA!(FunctionAttribute.ref_, func);
    }


    /**
    true if func is property
    */
    template isProperty(func...)
    if(func.length == 1 && isCallable!func)
    {
        enum isNothrow = hasFA!(FunctionAttribute.property_, func);
    }


    /**
    true if func is trusted
    */
    template isTrusted(func...)
    if(func.length == 1 && isCallable!func)
    {
        enum isNothrow = hasFA!(FunctionAttribute.trusted, func);
    }
}


/**
This template return arity of a function.

Example:
---
template Generator0(size_t N)
{
    alias TypeNuple!(int, N) Generator0;
}

alias argumentInfo!(( (a, b, c) => a), Generator0) Result0;

static assert(Result0.arity == 3);
static assert(Result0.endN == 3);
static assert(is(Result0.ParameterTypeTuple == Generator0!3));
static assert(is(Result0.ReturnType == int));


template Generator1(size_t N)
{
    alias TypeTuple!(int, ushort, long, double*, uint, real[])[N] Generator1;
}

static assert(Result1.arity == 1);
static assert(Result1.endN == 3);
static assert(is(Result1.ParameterTypeTuple == double*));
static assert(is(Result1.ReturnType == double*));
---

Authors: Kazuki Komatsu(k3_kaimu)
*/
template argumentInfo(alias templateFun, alias ParamGenRange)
if(isTemplateRange!ParamGenRange && !ParamGenRange.empty)
{
    template checkArity(alias pgr)
    {
        static if(!pgr.empty)
        {
            static if(is(typeof(templateFun(pgr.front.init))))
                alias checkArity = pgr.front;
            else
                alias checkArity = checkArity!(pgr.tail!());
        }
        else
            static assert(0, "arity Error : " ~ templateFun.stringof);
    }


    alias ParameterTypeTuple = TypeTuple!(checkArity!(ParamGenRange));
    enum size_t arity = ParameterTypeTuple.length;
    alias ReturnType = typeof(templateFun(ParameterTypeTuple.init));
}

unittest 
{
    template Generator0(T...)
    {
        enum bool empty = false;

        alias front = T;

        template tail()
        {
            alias tail = Generator0!(T, int);
        }
    }

    alias argumentInfo!(( (a, b, c) => a), Generator0!()) Result0;

    static assert(Result0.arity == 3);
    static assert(is(Result0.ParameterTypeTuple == TypeTuple!(int, int, int)));
    static assert(is(Result0.ReturnType == int));


    template Generator1(size_t idx)
    {
        enum bool empty = idx >= 6;

      static if(!empty)
      {
        alias front = TypeTuple!(int, ushort, long, double*, uint, real[])[idx];

        template tail()
        {
            alias tail = Generator1!(idx+1);
        }
      }
    }

    alias argumentInfo!(((double* a) => a), Generator1!0) Result1;

    static assert(Result1.arity == 1);
    static assert(is(Result1.ParameterTypeTuple[0] == double*));
    static assert(is(Result1.ReturnType == double*));
}