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


import std.algorithm,
       std.conv,
       std.range;


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
Maps a n-args function on either n ranges in parallel or on an n-tuple producing range.
Examples:
----
// With functions mapped on n ranges in parallel:
auto r1 = [1,2,3,4,5,6];
string s = "abcdefghijk";

auto tm1 = tmap!"std.range.repeat(a, b)"(s,r1); // [a], [b,b], [c,c,c], [d,d,d,d], ...
assert(equal(flatten(tm1), "abbcccddddeeeeeffffff")); // Note the use of flatten

auto tm2 = tmap!"a%2 == 0 ? b : '_'"(r1,s); // alternate between a char from s and '_'
assert(equal(tm2, "_b_d_f"));

auto tm3 = tmap!"a%2==0 ? b : c"(r1,s,flatten(tm1)); // ternary function mapped on three ranges in parallel
assert(equal(tm3, "abbdcf"));

string e = "";
assert(tmap!"a"(r1, s, e).empty); // e is empty -> tmap also
----

Examples:
----
// With functions mapped on a tuple-producing range:

auto tf = tfilter!"a%2"(r1, s); // keeps the odd elements from r1, produces 2-tuples (1,'a'),(3,'c'),(5,'e')
string foo(int a, dchar b) { return to!(string)(array(std.range.repeat(b, a)));}
auto tm4 = tmap!foo(tf); // maps a standard binary function on a 2-tuple range
assert(equal(tm4, ["a","ccc","eeeee"][]));

auto r2 = [1,2,3][];
// combinations(r2,r2) is equivalent to [(1,1),(1,2),(1,3),(2,1),(2,2),(2,3),(3,1),(3,2),(3,3)][]
auto combs = tmap!"a*b"(combinations(r2,r2));
assert(equal(combs, [1,2,3,2,4,6,3,6,9][]));

auto r3 = [1, 2, 3];
//first element of [0] expresses r3 is used as range, but second element expresses "abcd" is not used as range.
auto ss = tmap!("b[a]", [0])(r3, "abcd");
assert(equal(ss, ['b', 'c', 'd'][]));
----
*/
template tmap(fun...)
if(fun.length >= 1)
{
    // (RangeIndex!TF)[i] is true, if T[i] is input-range
    template RangeIndexTF(T...)
    {
        static if(T.length == 0)
            alias TypeTuple!() RangeIndexTF;
        else
        {
            static if(isInputRange!(T[0]))
                alias TypeTuple!(true, RangeIndexTF!(T[1..$])) RangeIndexTF;
            else
                alias TypeTuple!(false, RangeIndexTF!(T[1..$])) RangeIndexTF;
        }
    }


    auto tmap(T...)(T args)
    if(T.length > 1 || (T.length == 1 && !__traits(compiles, ElementType!(T[0]).Types)))
    {
        static if(is(typeof(TMap!(staticMap!(Unqual, T))(args))))
            return TMap!(staticMap!(Unqual, T))(args);
        else
            return map!(staticMap!(adaptTuple, staticMap!(naryFun, fun)))(knit(args));
    }


    // for tuple range
    auto tmap(T)(T args)
    if(__traits(compiles, ElementType!T.Types))
    {
        return map!(Prepare!(fun, ElementType!T.Types))(args);
    }


    struct TMap(T...)
    {
        Tuple!(T) _input;
        
        static if(fun.length == 1)
        {
            alias naryFun!(TypeTuple!(fun)[0]) _fun;
            alias RangeIndexTF!T IndexOfRangeTypeTF;
        }
        else
        {
            //if typeof(fun[$-1]) is Integral[]
            static if(isArray!(typeof(fun[$-1]))
                && is(ElementType!(typeof(fun[$-1])) : long)
                && !isSomeChar!(ElementType!(typeof(fun[$-1]))))
            {
                static if(fun.length == 2)
                    alias naryFun!(fun[0]) _fun;
                else
                    alias adjoin!(staticMap!(naryFun, fun[0..$-1])) _fun;
                
                template IndexOfRangeTypeTFImpl(size_t idx, Result...){
                    static if(idx == fun[$-1].length)
                        alias TypeTuple!(Result, TypeNuple!(false, T.length - Result.length)) IndexOfRangeTypeTFImpl;
                    else{
                        static if(fun[$-1][idx] == Result.length)
                            alias IndexOfRangeTypeTFImpl!(idx+1, Result, true) IndexOfRangeTypeTFImpl;
                        else static if(fun[$-1][idx] > Result.length)
                            alias IndexOfRangeTypeTFImpl!(idx, Result, false) IndexOfRangeTypeTFImpl;
                        else
                            static assert(0, "tfilter Error : select array is invalid. select array must be sorted.");
                    }
                }
            
                alias IndexOfRangeTypeTFImpl!(0) IndexOfRangeTypeTF;
            }
            else
            {
                alias adjoin!(staticMap!(naryFun, fun)) _fun;
                alias RangeIndexTF!T IndexOfRangeTypeTF;
            }
        }
        
        
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
        
        static assert(__traits(compiles, _fun(ETS.init)));

        
        this(T input)
        {
            _input = Tuple!T(input);
            
            static if(allSatisfy!(isBidirectionalRange, RangesTypes) && allSatisfy!(hasLength, RangesTypes))
            {
                auto size = this.length;
                
                foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange){
                        static if(hasSlicing!(T[i]))
                            _input[i] = _input[i][0..size];
                        else
                            popBackN(_input[i], _input[i].length - size);
                    }
                }
            }
        }
        
        static if(allSatisfy!(isBidirectionalRange, RangesTypes) && allSatisfy!(hasLength, RangesTypes))
        {
            @property auto ref back()
            {
                return _fun(_back().field);
            }
            
            private Tuple!ETS _back(){
                Tuple!ETS result;
                
                foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        result[i] = _input[i].back;
                    else
                        result[i] = _input[i];
                }
                
                return result;
            }
            
            void popBack()
            {
                 foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        _input[i].popBack();
                }
            }
        }
        
        static if(allSatisfy!(isInfinite, RangesTypes))
        {
            enum bool empty = false;
        }
        else
        {
            @property bool empty()
            {
                 foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange){
                        if(_input[i].empty)
                            return true;
                    }
                }
                return false;
            }
        }
        
        void popFront()
        {
            foreach(i, isRange; IndexOfRangeTypeTF){
                static if(isRange){
                    _input[i].popFront();
                }
            }
        }
        
        @property auto ref front()
        {
            return _fun(_front().field);
        }
        
        private Tuple!ETS _front(){
            Tuple!(ETS) result;
            
            foreach(i, isRange; IndexOfRangeTypeTF){
                static if(isRange)
                    result[i] = _input[i].front;
                else
                    result[i] = _input[i];
            }
            
            return result;
        }
        
        static if(allSatisfy!(isRandomAccessRange, RangesTypes))
        {
            auto ref opIndex(size_t index)
            {
                return _fun(_opIndex(index).field);
            }
            
            private Tuple!ETS _opIndex(size_t idx){
                Tuple!ETS result;
                
                foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        result[i] = _input[i][idx];
                    else
                        result[i] = _input[i];
                }
                
                return result;
            }
        }
        
        static if(allSatisfy!(hasLength, RangesTypes))
        {
            @property auto length()
            {
                alias CommonType!(staticMap!(_lengthType, RangesTypes)) LT;
                LT m = LT.max;
                foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        m = min(m, _input[i].length);
                }
                return m;
            }

            alias length opDollar;
        }
        
        static if(allSatisfy!(hasSlicing, RangesTypes))
        {
            auto opSlice(size_t idx1, size_t idx2)
            {
                return typeof(this)(_opSlice(idx1, idx2).field);
            }
            
            auto _opSlice(size_t idx1, size_t idx2){
                Tuple!T result;
                
                 foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        result[i] = _input[i][idx1..idx2];
                    else
                        result[i] = _input[i];
                }
                
                return result;
            }
        }
        
        static if(allSatisfy!(isForwardRange, RangesTypes))
        {
            @property auto save()
            {
                auto result = this;
                
                 foreach(i, isRange; IndexOfRangeTypeTF){
                    static if(isRange)
                        result._input[i] = result._input[i].save;
                }
                
                return result;
            }
        }
        
    }
    
    template _lengthType(T){
        alias typeof(T.init.length) _lengthType;
    }
}