module carbon.utils;

import std.traits;


string toLiteral(string str)
{
    import std.string : format;

    return format("%s", [str])[1 .. $-1];
}

unittest
{
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
