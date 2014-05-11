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
このモジュールは、標準ライブラリのstd.algorithmを強化します。
*/
module carbon.algorithm;

import carbon.functional,
       carbon.range,
       carbon.templates;


import std.algorithm,
       std.conv,
       std.functional,
       std.range,
       std.string,
       std.traits;

debug import std.stdio;

ElementType!R sum(R)(R range)
if(isInputRange!R)
{
    return reduce!"a + b"(to!(ElementType!R)(0), range);
}


ElementType!R product(R)(R range)
if(isInputRange!R)
{
    return reduce!"a * b"(to!(ElementType!R)(1), range);
}


ElementType!R maxOf(R)(R range)
if(isInputRange!R)
{
    return reduce!(std.algorithm.max)((ElementType!R).min, range);
}


ElementType!R minOf(R)(R range)
if(isInputRange!R)
{
    return reduce!(std.algorithm.min)((ElementType!R).max, range);
}


unittest
{
    auto r1 = [1, 2, 3, 4, 5];

    assert(sum(r1) == 15);
    assert(product(r1) == 120);
    assert(maxOf(r1) == 5);
    assert(minOf(r1) == 1);

    r1 = r1[$ .. $];
    assert(sum(r1) == 0);
    assert(product(r1) == 1);
    assert(maxOf(r1) == typeof(r1[0]).min);
    assert(minOf(r1) == typeof(r1[0]).max);
}



/**
tmap
*/
template tmap(fun...)
if(fun.length >= 1)
{
    auto tmap(T...)(T args)
    if(T.length > 1 || (T.length == 1 && !__traits(compiles, ElementType!(T[0]).Types)))
    {
        auto dst = TMap!(false, staticMap!(Unqual, T))(args);

        return dst;
    }


    // for tuple range
    auto tmap(T)(T args)
    if(__traits(compiles, ElementType!T.Types))
    {
        return map!(adaptTuple!(fun, ElementType!T.Types))(args);
    }


    struct TMap(bool asB, T...)
    {
      private:
        T _input;

      static if(isArray!(typeof(fun[$-1]))
                && is(ElementType!(typeof(fun[$-1])) : long)
                && !isSomeString!(typeof(fun[$-1])))
      {
        alias _funWithoutArray = fun[0 .. $-1];

        alias IndexOfRangeTypeTF = IndexOfRangeTypeTFImpl!(0, fun[$-1]);

        template IndexOfRangeTypeTFImpl(size_t index, alias array)
        {
          static if(index == T.length)
            alias IndexOfRangeTypeTFImpl = TypeTuple!();
          else static if(array.length == 0)
            alias IndexOfRangeTypeTFImpl = TypeTuple!(false, IndexOfRangeTypeTFImpl!(index + 1, array));
          else static if(index == array[0])
            alias IndexOfRangeTypeTFImpl = TypeTuple!(true, IndexOfRangeTypeTFImpl!(index + 1, array[1 .. $]));
          else static if(index < array[0])
            alias IndexOfRangeTypeTFImpl = TypeTuple!(false, IndexOfRangeTypeTFImpl!(index + 1, array));
          else static if(index > array[0])
            alias IndexOfRangeTypeTFImpl = TypeTuple!(false, IndexOfRangeTypeTFImpl!(index, array[1 .. $]));
          else
            static assert(0);
        }
      }
      else
      {
        alias _funWithoutArray = fun;

        alias IndexOfRangeTypeTF = IndexOfRangeTypeTFImpl!T;

        template IndexOfRangeTypeTFImpl(T...)
        {
            static if(T.length == 0)
                alias IndexOfRangeTypeTFImpl = TypeTuple!();
            else
                alias IndexOfRangeTypeTFImpl = TypeTuple!(isInputRange!(T[0]), IndexOfRangeTypeTFImpl!(T[1..$]));
        }
      }

      static if(_funWithoutArray.length == 1)
        alias _fun = naryFun!(TypeTuple!(_funWithoutArray)[0]);
      else
        alias _fun = adjoin!(staticMap!(naryFun, _funWithoutArray));

        template RangesTypesImpl(size_t n){
            static if(n < T.length){
                static if(IndexOfRangeTypeTF[n])
                    alias TypeTuple!(T[n], RangesTypesImpl!(n+1)) RangesTypesImpl;
                else
                    alias RangesTypesImpl!(n+1) RangesTypesImpl;
            }else
                alias TypeTuple!() RangesTypesImpl;
        }
        
        alias RangesTypesImpl!(0) RangesTypes;
        alias staticMap!(ElementType, RangesTypes) ElementTypeOfRanges;
        alias ETSImpl!(0) ETS;      //_fun args type
        
        template ETSImpl(size_t n){
            static if(n < T.length){
                static if(IndexOfRangeTypeTF[n])
                    alias TypeTuple!(ElementType!(T[n]), ETSImpl!(n+1)) ETSImpl;
                else
                    alias TypeTuple!(T[n], ETSImpl!(n+1)) ETSImpl;
            }else
                alias TypeTuple!() ETSImpl;
        }


        static assert(is(typeof(_fun(ETS.init))));


        static string expandMacro(string a, string b)
        {
            string dst;
            foreach(i, isRange; IndexOfRangeTypeTF)
            {
              static if(isRange)
              {
                if(a)
                    dst ~= format(a, i);
              }
              else
              {
                if(b)
                    dst ~= format(b, i);
              }
            }
            return dst;
        }

      public:

      static if(asB && allSatisfy!(isBidirectionalRange, RangesTypes) && allSatisfy!(hasLength, RangesTypes))
      {
        @property
        auto ref back()
        {
            return mixin("_fun(" ~ expandMacro("_input[%1$s].back,", "_input[%1$s],") ~ ")");
        }


        void popBack()
        {
            mixin(expandMacro("_input[%1$s].popBack();\n", null));
        }
      }
        
        static if(allSatisfy!(isInfinite, RangesTypes))
        {
            enum bool empty = false;
        }
        else
        {
            @property
            bool empty()
            {
                mixin(expandMacro("if(_input[%1$s].empty) return true;\n", null));
                return false;
            }
        }


        void popFront()
        {
            mixin(expandMacro("_input[%1$s].popFront();\n", null));
        }


        @property
        auto ref front()
        {
            return mixin("_fun(" ~ expandMacro("_input[%1$s].front,", "_input[%1$s],") ~ ")");
        }


      static if(allSatisfy!(isRandomAccessRange, RangesTypes))
      {
        auto ref opIndex(size_t index)
        {
            return mixin("_fun(" ~ expandMacro("_input[%1$s][index],", "_input[%1$s],") ~ ")");
        }
      }
        
        static if(allSatisfy!(hasLength, RangesTypes))
        {
            @property auto length()
            {
                mixin("alias LT = CommonType!(" ~ expandMacro("typeof(_input[%1$s].length),", null) ~ ");");

                LT m = LT.max;

                mixin(expandMacro("m = min(m, _input[%1$s].length);\n", null));
                return m;
            }

            alias length opDollar;
        }
        
        static if(allSatisfy!(hasSlicing, RangesTypes))
        {
            auto opSlice(size_t idx1, size_t idx2)
            {
                return mixin("TMap!(asB, T)(" ~ expandMacro("_input[%1$s][idx1 .. idx2],", "_input[%1$s],") ~ ")");
            }
        }
        
        static if(allSatisfy!(isForwardRange, RangesTypes))
        {
            @property auto save()
            {
                return mixin("TMap!(asB, T)(" ~ expandMacro("_input[%1$s].save,", "_input[%1$s],") ~ ")");
            }
        }


      static if(allSatisfy!(isBidirectionalRange, RangesTypes) && allSatisfy!(hasLength, RangesTypes))
      {
        TMap!(true, T) asBidirectional() @property
        {
            auto dst = TMap!(true, T)(this._input);

            immutable size = dst.length;

            mixin(expandMacro(q{
                static if(hasSlicing!(T[%1$s]))
                  dst._input[%1$s] = dst._input[%1$s][0 .. size];
                else
                  dst._input[%1$s].popBackN(dst._input[%1$s].length - size);
              }, null));

            return dst;
        }
      }
    }
}


/// ditto
unittest
{
    debug scope(failure) writefln("Unittest Failure :%s(%s) ", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto r1 = [1,2,3,4,5,6];
    auto s = "abcdefghijk".dup;
    auto tm1 = tmap!" std.range.repeat(a, b)"(s, r1); // [a], [b,b], [c,c,c], [d,d,d,d], ...
    alias typeof(tm1) TM1;
    assert(equal(concat(tm1), "abbcccddddeeeeeffffff")); // Note the use of flatten
    auto tm2 = tmap!"a%2 == 0 ? b : '_'"(r1, s);
    assert(equal(tm2, "_b_d_f"));

    auto tm3 = tmap!"a%2==0 ? b : c"(r1, s, concat(tm1));
    assert(equal(tm3, "abbdcf"));

    string e = "";
    assert(tmap!"a"(r1, s, e).empty); // e is empty -> tmap also

    //auto tf = tfilter!"a%2"(r1, s); // keeps the odd elements from r1, produces 2-tuples (1,'a'),(3,'c'),(5,'e')
    //auto tm4 = tmap!"to!(string)(array(std.range.repeat(b,a)))"(tf); // maps a standard binary function on a 2-tuple range
    //assert(equal(tm4, ["a","ccc","eeeee"][]));

    auto r3 = [1, 2, 3];
    //first element of [0] expresses r3 is used as range, but second element expresses "abcd" is not used as range.
    auto ss = tmap!("b[a]", [0])(r3, "abcd");
    assert(equal(ss, ['b', 'c', 'd'][]));
    assert(ss.length == 3);

    static assert(isForwardRange!(typeof(ss)));
    static assert(!isBidirectionalRange!(typeof(ss)));
    static assert(!isRandomAccessRange!(typeof(ss)));

    auto ss_b = ss.asBidirectional;
    static assert(isBidirectionalRange!(typeof(ss_b)));
    static assert(isRandomAccessRange!(typeof(ss_b)));
    assert(equal(ss_b.retro, ['d', 'c', 'b']));

    ///multi function and range-choose test
    auto tm5 = tmap!("b[a]", "b[a-1]", [0])(r3, "abcd");
    assert(equal(tm5, [tuple('b', 'a'), tuple('c', 'b'), tuple('d', 'c')][]));
}
