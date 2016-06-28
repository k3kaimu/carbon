module carbon.utils;

import std.algorithm;
import std.container;
import std.traits;
import std.stdio;


string toLiteral(string str)
{
    import std.string : format;

    return format("%s", [str])[1 .. $-1];
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    assert("123".toLiteral == `"123"`);
    assert("12\"3".toLiteral == `"12\"3"`);
}


struct Cache(AA)
if(isAssociativeArray!AA)
{
    alias KeyType = typeof(AA.init.keys[0]);
    alias ValueType = typeof(AA.init.values[0]);

    ValueType opCall(KeyType key, lazy ValueType value)
    {
        if(auto p = key in _aa)
            return *p;
        else{
            ValueType v = value();
            _aa[key] = v;
            return v;
        }
    }

  private:
    AA _aa;
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    Cache!(int[string]) c;
    assert(c("foo", 1) == 1);
    assert(c("bar", 2) == 2);
    assert(c("foo", 3) == 1);
    assert(c("bar", 4) == 2);
}


auto maybeModified(K, V)(V[K] aa)
{
    static struct Result()
    {
        this(V[K] aa)
        {
            _keys = typeof(_keys)(aa.byKey);

            _aa = aa;
        }


        int opApply(int delegate(K, ref V) dg)
        {
            foreach(k; _keys)
                if(k in _aa)
                    if(auto res = dg(k, _aa[k]))
                        return res;

            return 0;
        }

      private:
        Array!K _keys;
        V[K] _aa;
    }

    return Result!()(aa);
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto aa = ["a": 1, "b": 2, "c": 3];

    foreach(k, ref v; aa.maybeModified){
        aa[k ~ k] = v;
    }

    assert(aa.length == 6);
}


auto maybeModified(E)(E[] arr)
{
    static struct Result()
    {
        this(E[] arr)
        {
            _dup = Array!E(arr);
        }


        int opApply(int delegate(E) dg)
        {
            foreach(e; _dup)
                if(auto res = dg(e))
                    return res;

            return 0;
        }

      private:
        Array!E _dup;
    }


    return Result!()(arr);
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto arr = [1, 2, 3];

    foreach(v; arr.maybeModified){
        arr ~= v;
    }

    assert(arr.length == 6);
    assert(arr == [1, 2, 3, 1, 2, 3]);
}


/*
struct ShiftRegistor(E, bool isRingBuffer = true, bool containPointer = false)
{



  private:
    static if(containPointer)
        alias C = E*;
    else
        alias C = E;

    C[] _buffer;
}


struct ShiftRegistor(E, size_t N, bool isRingBuffer = true, bool containPointer = false)
{

}


struct ParallelShiftRegistor(E, size_t P, bool isRingBuffer = true, bool containPointer = false)
{

}


struct ParallelShiftRegistor(E, size_t P, bool isRingBuffer = true, bool containPointer = false)
*/