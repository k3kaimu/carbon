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
このモジュールは、標準ライブラリのstd.rangeを強化します。
*/

module carbon.range;


import std.algorithm,
       std.array,
       std.functional,
       std.range,
       std.string,
       std.traits,
       std.typecons;

debug import std.stdio;

import carbon.functional,
       carbon.templates,
       carbon.traits;


/**
true if isInputRange!R is true and isInputRange!R is false.
*/
enum isSimpleRange(R, alias I = isInputRange) = 
    I!(R) && !I!(ElementType!R);


/**
true if both isInputRange!R and isInputRange!R are true.
*/
enum isRangeOfRanges(R, alias I = isInputRange) = 
    I!(R) && I!(ElementType!R);



/**
あるレンジのN個の連続する要素のリストを返します。

Example:
----
auto r1 = [0, 1, 2, 3, 4, 5];
auto s = segment!2(r1);
assert(equal(s, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4), tuple(4, 5)][]));
assert(s.length == 5);         // .length
// back/popBack:
assert(equal(retro(s), retro([tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4), tuple(4, 5)][])));
assert(s[3] == tuple(3, 4));    // opIndex
s[3] = tuple(0, 0);             // opIndexAssign not ref opIndex
assert(s[2] == tuple(2, 0));    // it affects its neighbors.
assert(s[4] == tuple(0, 5));
assert(r1 == [0, 1, 2, 0, 0, 5][]); // affects r1 back (no .dup internally)


auto st = ["a","b","c","d","e","f"];
auto s2 = segment!3(st);
assert(s2.front == tuple("a","b","c"));


auto r1 = [0,1,2,3,4,5]; // regenerates r1
auto s3 = segment!1(r1);
assert(equal(s3, [tuple(0), tuple(1), tuple(2), tuple(3), tuple(4), tuple(5)][]));
auto r2 = map!"a*a"(r1);
auto s4 = segment!2(r2); // On a forward range
assert(equal(s4, [tuple(0,1), tuple(1,4), tuple(4,9), tuple(9,16), tuple(16,25)][]));


int[] e;
auto s5 = segment!2(e);
assert(s5.empty);
----

Authors: Komatsu Kazuki
*/
template SegmentType(size_t N, R)
if(isInputRange!(Unqual!R) && N > 0)
{
    alias typeof(segment!N(R.init)) SegmentType;
}


///ditto
template segment(size_t N : 1, Range)
if(isInputRange!(Unqual!Range))
{
    Segment segment(Range range)
    {
        return Segment(range);
    }

    alias Unqual!Range R;
    alias ElementType!Range E;

    struct Segment{
    private:
        R _range;

    public:
        this(R range)
        {
            _range = range;
        }


      static if(isInfinite!R)
        enum bool e = false;
      else
        @property bool empty()
        {
            return _range.empty;
        }
        
        
        void popFront()
        {
            _range.popFront();
        }
      static if(isBidirectionalRange!R)
        void popBack()
        {
            _range.popBack();
        }
        
        
      static if(isForwardRange!R)
        @property typeof(this) save()
        {
            typeof(this) dst = this;
            dst._range = dst._range.save;
            return dst;
        }
      
      static if(hasLength!R)
      {
        @property size_t length()
        {
            return _range.length;
        }

        alias length opDollar;
      }
      
      static if(hasSlicing!R)
      {
        Segment opSlice()
        {
          static if(isForwardRange!R)
            return save;
          else
            return typeof(this)(_range);
        }


        auto opSlice(size_t i, size_t j)
        {
            return segment!1(_range[i .. j]);
        }
      }
      
      
        @property Tuple!E front()
        {
            return tuple(_range.front);
        }
        
      static if(isBidirectionalRange!R)
        @property Tuple!E back()
        {
            return tuple(_range.back);
        }
      
      static if(isRandomAccessRange!R)
        Tuple!E opIndex(size_t i)
        {
            return tuple(_range[i]);
        }

      static if(hasAssignableElements!R || hasSwappableElements!R || hasLvalueElements!R)
      {
        @property void front(Tuple!E e)
        {
            _range.front = e[0];
        }

        
        static if(isBidirectionalRange!R)
        {
          @property void back(Tuple!E e)
          {
              _range.back = e[0];
          }
        }
        
        static if(isRandomAccessRange!R)
        {
          void opIndexAssign(Tuple!E e, size_t i)
          {
              _range[i] = e[0];
          }
        }
      }
    
    }
}


unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto a = [0, 1, 2, 3, 4];
    auto sg = segment!1(a);

    assert(equal(sg, [tuple(0), tuple(1), tuple(2), tuple(3), tuple(4)]));
    assert(equal(sg.retro, [tuple(0), tuple(1), tuple(2), tuple(3), tuple(4)].retro));

    sg.front = tuple(3);
    assert(equal(sg, [tuple(3), tuple(1), tuple(2), tuple(3), tuple(4)]));

    sg[3] = tuple(2);
    assert(equal(sg, [tuple(3), tuple(1), tuple(2), tuple(2), tuple(4)]));

    assert(sg.length == 5);

    sg.back = tuple(8);
    assert(equal(sg, [tuple(3), tuple(1), tuple(2), tuple(2), tuple(8)]));
    assert(sg[$-1] == tuple(8));

    assert(equal(sg[2..4], [tuple(2), tuple(2)]));

    auto sv = sg.save;
    sv.popFront();
    assert(equal(sg, [tuple(3), tuple(1), tuple(2), tuple(2), tuple(8)]));
    assert(equal(sv, [tuple(1), tuple(2), tuple(2), tuple(8)]));

    auto sl = sv[];
    sv.popFront();
    assert(equal(sl, [tuple(1), tuple(2), tuple(2), tuple(8)]));
    assert(equal(sv, [tuple(2), tuple(2), tuple(8)]));
}


///ditto
template segment(size_t N, Range)
if (isInputRange!(Unqual!Range) 
&& (isForwardRange!(Unqual!Range) ? (!isBidirectionalRange!(Unqual!Range)
                                      && !isRandomAccessRange!(Unqual!Range)) : true))
{
    Segment segment(Range range)
    {
        return Segment(range);
    }

    alias Unqual!Range R;
    alias ElementType!R E;

    enum assE = isForwardRange!R && (hasAssignableElements!R || hasLvalueElements!R || hasSwappableElements!R);

    struct Segment{
    private:
        R _range;
        E[] _front;

      static if(assE)
        R _assignRange;

    public:
        this(R range)
        {
            _range = range;

          static if(assE)
            _assignRange = _range.save;

            for(int i = 0; i < N && !_range.empty; ++i, _range.popFront())
                _front ~= _range.front;
        }


        void popFront()
        {
            if(_range.empty)
                _front = _front[1..$];
            else{
                _front = _front[1..$];
                _front ~= _range.front;
                _range.popFront();
              static if(assE)
                _assignRange.popFront();
            }
        }

        @property
        Tuple!(TypeNuple!(E, N)) front()
        {
            return (cast(typeof(return)[])(cast(ubyte[])_front))[0];
        }


      static if(assE)
        @property void front(Tuple!(TypeNuple!(E, N)) e)
        {
            R _tmpRange = _assignRange.save;

            _front = [e.field];

            for(int i = 0; i < N; ++i, _tmpRange.popFront)
                _tmpRange.front = _front[i];
        }


      static if(isForwardRange!R) {
        @property Segment save()
        {
            Segment dst = this;
            dst._range = dst._range.save;

          static if(assE)
            dst._assignRange = dst._assignRange.save;

            return dst;
        }
      }

      static if(isInfinite!R)
        enum bool empty = false;        
      else
        @property
        bool empty()
        {
            return _front.length != N;
        }
        

      static if(hasLength!R){
        @property
        size_t length()
        {
          return _range.length + !this.empty;
        }

        alias length opDollar;
      }

      static if(hasSlicing!R)
      {
          Segment opSlice()
          {
            static if(isInputRange!R)
              return this;
            else
              return save;
          }

          auto opSlice(size_t i, size_t j)
          {
              return segment!N(_assignRange[i..j + (N-1)]);
          }
      }
    }
}


unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange
    {
        int _front, _end;
        @property int front(){return _front;}
        void popFront(){_front += 1;}
        @property bool empty(){return _front == _end;}
        @property TRange save(){return this;}
        @property size_t length(){return _end - _front;}
        alias length opDollar;
    }

    auto tr = TRange(0, 5);
    auto sg2 = segment!2(tr);
    assert(equal(sg2, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    auto sg2sv = sg2.save;
    sg2sv.popFront();
    assert(equal(sg2, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sg2sv, [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    assert(sg2.length == 4);

    auto sg3 = segment!3(tr);
    assert(equal(sg3, [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)]));
    assert(sg3.length == 3);

    auto sg4 = segment!4(tr);
    assert(equal(sg4, [tuple(0, 1, 2, 3), tuple(1, 2, 3, 4)]));
    assert(sg4.length == 2);

    auto sg5 = segment!5(tr);
    assert(equal(sg5, [tuple(0, 1, 2, 3, 4)]));
    assert(sg5.length == 1);

    auto sg6 = segment!6(tr);
    assert(sg6.empty);
    assert(sg6.length == 0);

    auto tremp = TRange(0, 0);
    assert(tremp.empty);
    assert(segment!2(tremp).empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange
    {
        int _front, _end;
        @property int front(){return _front;}
        void popFront(){_front += 1;}
        @property bool empty(){return _front == _end;}
        @property TRange save(){return this;}
        @property size_t length(){return _end - _front;}
        alias length opDollar;
    }

    auto tr = TRange(0, 5);
    auto sg2 = segment!2(tr);
    assert(equal(sg2, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    assert(sg2.length == 4);

    auto sg3 = segment!3(tr);
    assert(equal(sg3, [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)]));
    assert(sg3.length == 3);

    auto sg4 = segment!4(tr);
    assert(equal(sg4, [tuple(0, 1, 2, 3), tuple(1, 2, 3, 4)]));
    assert(sg4.length == 2);

    auto sg5 = segment!5(tr);
    assert(equal(sg5, [tuple(0, 1, 2, 3, 4)]));
    assert(sg5.length == 1);

    auto sg6 = segment!6(tr);
    assert(sg6.empty);
    assert(sg6.length == 0);

    auto tremp = TRange(0, 0);
    assert(tremp.empty);
    assert(segment!2(tremp).empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange
    {
        int[] a;
        @property ref int front(){return a.front;}
        @property bool empty(){return a.empty;}
        void popFront(){a.popFront;}
        @property TRange save(){return TRange(a.save);}
        @property size_t length(){return a.length;}
        alias length opDollar;
        TRange opSlice(size_t i, size_t j){return TRange(a[i..j]);}
    }


    int[] a = [0, 1, 2, 3, 4];
    auto r = TRange(a);
    auto sg = segment!2(r);
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sg[2..4], [tuple(2, 3), tuple(3, 4)]));

    sg.front = tuple(3, 2);
    assert(equal(sg, [tuple(3, 2), tuple(2, 2), tuple(2, 3), tuple(3, 4)]));

    assert(sg.length == 4);
    sg.popFront();
    assert(sg.length == 3);
    sg.popFront();
    assert(sg.length == 2);
    sg.popFront();
    assert(sg.length == 1);
    sg.popFront();
    assert(sg.length == 0);
    assert(sg.empty);

    a = [0, 1, 2, 3, 4];
    r = TRange(a);
    auto sg3 = segment!3(r);
    assert(equal(sg3, [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)]));
    sg3.front = tuple(2, 3, 1);
    assert(equal(sg3, [tuple(2, 3, 1), tuple(3, 1, 3), tuple(1, 3, 4)]));

    auto sl3 = sg3[];
    sl3.popFront();
    assert(equal(sg3, [tuple(2, 3, 1), tuple(3, 1, 3), tuple(1, 3, 4)]));
    assert(equal(sl3, [tuple(3, 1, 3), tuple(1, 3, 4)]));

    auto sv3 = sg3.save;
    sv3.popFront();
    assert(equal(sg3, [tuple(2, 3, 1), tuple(3, 1, 3), tuple(1, 3, 4)]));
    assert(equal(sv3, [tuple(3, 1, 3), tuple(1, 3, 4)]));

    assert(sg3.length == 3);
    sg3.popFront();
    assert(sg3.length == 2);
    sg3.popFront();
    assert(sg3.length == 1);
    sg3.popFront();
    assert(sg3.length == 0);
    assert(sg3.empty);
}


///ditto
template segment(size_t N, Range)
if(isRandomAccessRange!(Unqual!Range)
&& isBidirectionalRange!(Unqual!Range)
&& hasLength!(Unqual!Range))
{
    Segment segment(Range range)
    {
        return Segment(range);
    }


    alias Unqual!Range R;
    alias ElementType!R E;
    
    struct Segment{
      private:
        R _range;
        size_t _fidx;
        size_t _bidx;
        E[] _front;
        E[] _back;

        void reConstruct()
        {
            if(!empty){
                _front.length = 0;
                _back.length = 0;
                foreach(i; 0..N)
                {
                    _front ~= _range[_fidx + i];
                    _back ~= _range[_bidx + i];
                }
            }
        }


      public:
        this(R range)
        {
            _range = range;
            _fidx = 0;
            _bidx = _range.length - N;

            reConstruct();
        }

        
        @property bool empty() const
        {
            return (cast(int)_bidx - cast(int)_fidx) < 0;
        }

        
        void popFront()
        {
            ++_fidx;
            if(!empty){
                _front = _front[1..$];
                _front ~= _range[_fidx + (N - 1)];
            }
        }


        void popBack()
        {
            --_bidx;
            if(!empty){
                _back = _back[0..$-1];
                _back = [_range[_bidx]] ~ _back;
            }
        }
        
        
        @property Segment save()
        {
            Segment dst = cast(Segment)this;
            dst._range = dst._range.save;
            dst._front = dst._front.dup;
            dst._back = dst._back.dup;
            return dst;
        }
      

        @property size_t length() const
        {
            return _bidx - _fidx + 1;
        }


        alias length opDollar;
      

        auto opSlice()
        {
            return save;
        }


        Segment opSlice(size_t i, size_t j)
        {
            Segment dst = this.save;
            dst._fidx += i;
            dst._bidx -= this.length - j;

            dst.reConstruct();
            return dst;
        }
      

        @property Tuple!(TypeNuple!(E, N)) front()
        {
            return (cast(typeof(return)[])cast(ubyte[])_front)[0];
        }


        @property Tuple!(TypeNuple!(E, N)) back()
        {
            return (cast(typeof(return)[])cast(ubyte[])_back)[0];
        }


        Tuple!(TypeNuple!(E, N)) opIndex(size_t i)
        {
            if(i == 0)
                return this.front;
            else if(i == this.length - 1)
                return this.back;
            else
            {
                E[N] dst;
                foreach(j; 0 .. N)
                    dst[j] = _range[_fidx + i + j];
                return (cast(typeof(return)[])(cast(ubyte[])(dst[])))[0];
            }
        }


      static if(hasSwappableElements!R || hasLvalueElements!R || hasAssignableElements!R)
      {
        @property void front(Tuple!(TypeNuple!(E, N)) e)
        {
            E[] eSlice = [e.field];

            foreach(i; 0 .. N)
                _range[i + _fidx] = eSlice[i];
            
            reConstruct();
        }


        @property void back(Tuple!(TypeNuple!(E, N)) e)
        {
            E[] eSlice = [e.field];

            foreach(i; 0..N)
                _range[i + _bidx] = eSlice[i];

            reConstruct();
        }


        void opIndexAssign(Tuple!(TypeNuple!(E, N)) e, size_t i)
        {
            E[] eSlice = [e.field];

            foreach(j; 0..N)
                _range[_fidx + i + j] = eSlice[j];

            reConstruct();
        }
      }
    }
}


unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto r1 = [0,1,2,3,4,5];
    auto s = segment!2(r1);
    assert(equal(s, [tuple(0,1), tuple(1,2), tuple(2,3), tuple(3,4), tuple(4,5)][]));
    assert(s.length == 5);         // .length
    // back/popBack:
    assert(equal(retro(s), retro([tuple(0,1), tuple(1,2), tuple(2,3), tuple(3,4), tuple(4,5)][])));
    assert(s[3] == tuple(3,4));    // opIndex
    s[3] = tuple(0,0);             // opIndexAssign
    assert(s[2] == tuple(2,0));    // it affects its neighbors.
    assert(s[4] == tuple(0,5));
    assert(r1 == [0,1,2,0,0,5][]); // affects r1 back (no .dup internally)

    s = segment!2(r1);
    s.front = tuple(2, 0);
    assert(s[0] == tuple(2, 0));

    s.back = tuple(100, 500);
    assert(s[s.length - 1] == tuple(100, 500));

    auto sl = s[];
    assert(equal(sl, s));
    sl.popFront();
    sl.popBack();
    assert(equal(sl, s[1 .. s.length - 1]));
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto st = ["a","b","c","d","e","f"];
    auto s2 = segment!3(st);
    assert(s2.front == tuple("a","b","c"));
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto r1 = [0,1,2,3,4,5]; // regenerates r1
    auto s3 = segment!1(r1);
    assert(equal(s3, [tuple(0), tuple(1), tuple(2), tuple(3), tuple(4), tuple(5)][]));
    assert(equal(s3.retro, [tuple(0), tuple(1), tuple(2), tuple(3), tuple(4), tuple(5)].retro));
    auto r2 = map!"a*a"(r1);
    auto s4 = segment!2(r2); // On a forward range
    auto s4_2 = segment!2(r2);
    assert(equal(s4_2, [tuple(0,1), tuple(1,4), tuple(4,9), tuple(9,16), tuple(16,25)][]));
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    int[] e;
    auto s5 = segment!2(e);
    assert(s5.empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto ri = iota(0, 5);
    auto sg = segment!2(ri);
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sg.retro, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)].retro));
    assert(sg[0] == tuple(0, 1));
    assert(sg[1] == tuple(1, 2));
    assert(sg[2] == tuple(2, 3));
    assert(sg[3] == tuple(3, 4));
    assert(sg.length == 4);
}

///ditto
template segment(size_t N, Range)
if(isRandomAccessRange!(Unqual!Range)
&& !isBidirectionalRange!(Unqual!Range)
&& isInfinite!(Unqual!Range))
{
    Segment segment(Range range)
    {
        return Segment(range);
    }


    alias Unqual!Range R;
    alias ElementType!R E;
    
    struct Segment{
      private:
        R _range;
        size_t _fidx;
        E[] _front;

        void reConstruct()
        {
            if(!empty){
                _front.length = 0;
                foreach(i; 0..N)
                    _front ~= _range[_fidx + i];
            }
        }

      public:
        this(R range)
        {
            _range = range;
            _fidx = 0;

            reConstruct();
        }

        
        enum bool empty = false;

        
        void popFront()
        {
            ++_fidx;
            if(!empty){
                _front = _front[1..$];
                _front ~= _range[_fidx + (N - 1)];
            }
        }
        
        
        @property Segment save()
        {
            Segment dst = this;
            dst._range = dst._range.save;
            return dst;
        }
      

      @property Tuple!(TypeNuple!(E, N)) front()
      {
          return (cast(typeof(return)[])(cast(ubyte[])_front))[0];
      }


      Tuple!(TypeNuple!(E, N)) opIndex(size_t i)
      {
          if(i == 0)
              return this.front;
          else
          {
              E[] dst;
              foreach(j; 0 .. N)
                  dst ~= _range[_fidx + i + j];
              return (cast(typeof(return)[])(cast(ubyte[])dst))[0];
          }
      }


      static if(hasSwappableElements!R || hasLvalueElements!R || hasAssignableElements!R)
      {
        @property void front(Tuple!(TypeNuple!(E, N)) e)
        {
            E[] eSlice = [e.field];

            foreach(i; 0 .. N)
                _range[i + _fidx] = eSlice[i];
            
            reConstruct();
        }


        void opIndexAssign(Tuple!(TypeNuple!(E, N)) e, size_t i)
        {
            E[] eSlice = [e.field];

            foreach(j; 0..N)
                _range[_fidx + i + j] = eSlice[j];

            reConstruct();
        }
      }
    }
}


unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange
    {
        int[] a, s;

        this(int[] r){
            a = r.save;
            s = r.save;
        }

        @property ref int front(){return a.front;}
        enum bool empty = false;
        void popFront(){a.popFront; if(a.empty)a = s;}
        @property typeof(this) save(){return this;}
        ref int opIndex(size_t i){return a[i%s.length];}
    }

    
    auto r = segment!2(TRange([0, 1, 2, 3, 4]));
    assert(equal(r.take(4), [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    auto sv = r.save;
    sv.popFront();
    assert(equal(r.take(4), [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sv.take(3), [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    assert(r[2] == tuple(2, 3));
    assert(r[0] == tuple(0, 1));

    r.front = tuple(100, 50);
    assert(equal(r.take(4), [tuple(100, 50), tuple(50, 2), tuple(2, 3), tuple(3, 4)]));

    r[1] = tuple(10, 20);
    assert(equal(r.take(4), [tuple(100, 10), tuple(10, 20), tuple(20, 3), tuple(3, 4)]));
}


///ditto
template segment(size_t N, Range)
if(isBidirectionalRange!(Unqual!Range)
&& (isRandomAccessRange!(Unqual!Range) ? (!hasLength!(Unqual!Range) && isInfinite!(Unqual!Range)) : true))
{
    Segment segment(Range range)
    {
        return Segment(range);
    }


    alias Unqual!Range R;
    alias ElementType!R E;
    enum assE = hasAssignableElements!R && hasLvalueElements!R && hasSwappableElements!R;


    struct Segment{
      private:
        R _fRange;
        R _bRange;
        E[] _front;
        E[] _back;

      static if(assE || isRandomAccessRange!R)
        R _assignRange;

      static if(assE || isRandomAccessRange!R)
        void reConstruct(){
            _front.length = 0;
            _back.length = 0;

            _fRange = _assignRange.save;
            _bRange = _assignRange.save;

            for(int i = 0; i < N && !_fRange.empty; ++i, _fRange.popFront())
                _front ~= _fRange.front();

            for(int i = 0; i < N && !_bRange.empty; ++i, _bRange.popBack())
                _back ~= _bRange.back();

            _back.reverse();
        }



      public:
        this(R range)
        {
            _fRange = range.save;
            _bRange = range.save;

          static if(assE || isRandomAccessRange!R)
            _assignRange = range.save;

            for(int i = 0; i < N && !_fRange.empty; ++i, _fRange.popFront())
                _front ~= _fRange.front();

            for(int i = 0; i < N && !_bRange.empty; ++i, _bRange.popBack())
                _back ~= _bRange.back();

            _back.reverse();
        }

        
      static if(isInfinite!R)
        enum bool empty = false;
      else
        @property bool empty()
        {
            return (_front.length < N) || (_back.length < N);
        }
        
        
        void popFront()
        {
            _front = _front[1..$];

            if(!_fRange.empty){
              _front ~= _fRange.front;

              _fRange.popFront();
              _bRange.popFront();
            }

          static if(assE || isRandomAccessRange!R)
            _assignRange.popFront();
        }


        void popBack()
        {
            _back = _back[0..$-1];

            if(!_bRange.empty){
              _back = [_bRange.back] ~ _back;

              _fRange.popBack();
              _bRange.popBack();
            }

          static if(assE || isRandomAccessRange!R)
            _assignRange.popBack();
        }
        
        
        @property Segment save()
        {
            Segment dst = this;
            dst._fRange = dst._fRange.save;
            dst._bRange = dst._bRange.save;

          static if(assE)
            dst._assignRange = dst._assignRange.save;

            return dst;
        }

      
      static if(hasLength!R)
      {
        @property size_t length()
        {
            return _fRange.length + ((_front.length == N && _back.length == N) ? 1 : 0);
        }


        alias length opDollar;
      }
      

      static if(hasSlicing!R)
      {
        Segment opSlice()
        {
            return save;
        }


        static if(assE || isRandomAccessRange!R)
          auto opSlice(size_t i, size_t j)
          {
              return segment!N(_assignRange[i..j + (N-1)]);
          }
        //else
      }
      

        @property Tuple!(TypeNuple!(E, N)) front()
        {
            return (cast(typeof(return)[])(cast(ubyte[])_front))[0];
        }

        
        @property Tuple!(TypeNuple!(E, N)) back()
        {
            return (cast(typeof(return)[])(cast(ubyte[])_back))[0];
        }


      static if(isRandomAccessRange!R)
        Tuple!(TypeNuple!(E, N)) opIndex(size_t i)
        {
            E[] dst;

            foreach(j; 0..N)
                dst ~= _assignRange[i + j];

            return (cast(typeof(return)[])(cast(ubyte[])dst))[0];
        }



      static if(assE)
      {
        @property void front(Tuple!(TypeNuple!(E, N)) e)
        {
            R _tmp = _assignRange.save;
            _front = [e.field];

            for(int i = 0; i < N; ++i, _tmp.popFront())
                _tmp.front = _front[i];

            reConstruct();
        }


        @property void back(Tuple!(TypeNuple!(E, N)) e)
        {
            R _tmp = _assignRange.save;
            _back = [e.field];

            for(int i = N-1; i >= 0; --i, _tmp.popBack())
                _tmp.back = _back[i];

            reConstruct();
        }

        static if(isRandomAccessRange!R)
        void opIndexAssign(Tuple!(TypeNuple!(E, N)) e, size_t i)
        {
            foreach(j; 0..N)
                _assignRange[i + j] = [e.field][j];

            reConstruct();
        }
      }
    }
}

unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange{
        int[] a;
        @property int front(){return a.front;}
        @property bool empty(){return a.empty;}
        void popFront(){a.popFront();}
        void popBack(){a.popBack();}
        @property int back(){return a.back();}
        @property TRange save(){return TRange(a.save);}
        @property size_t length(){return a.length;}
        alias length opDollar;
    }


    auto r = TRange([0, 1, 2, 3, 4]);
    auto sg = segment!2(r);
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sg.retro, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)].retro));
    assert(sg.length == 4);

    sg.popFront();
    assert(equal(sg, [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(sg.length == 3);
    assert(!sg.empty);

    auto sv = sg.save;
    sv.popFront();
    assert(equal(sg, [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sv, [tuple(2, 3), tuple(3, 4)]));
    assert(sg.length == 3);
    assert(sv.length == 2);
    assert(!sg.empty);
    assert(!sv.empty);

    sg.popFront();
    assert(equal(sg, [tuple(2, 3), tuple(3, 4)]));
    assert(sg.length == 2);
    assert(!sg.empty);

    sg.popFront();
    assert(equal(sg, [tuple(3, 4)]));
    assert(sg.length == 1);
    assert(!sg.empty);

    sg.popFront();
    assert(sg.length == 0);
    assert(sg.empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange{
        int[] a;
        @property ref int front(){return a.front;}
        @property bool empty(){return a.empty;}
        void popFront(){a.popFront();}
        void popBack(){a.popBack();}
        @property ref int back(){return a.back();}
        @property TRange save(){return TRange(a.save);}
        @property size_t length(){return a.length;}
        TRange opSlice(size_t i, size_t j){return TRange(a[i..j]);}
        alias length opDollar;
    }


    auto r = TRange([0, 1, 2, 3, 4]);
    auto sg = segment!2(r);
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(retro(sg), [tuple(3, 4), tuple(2, 3), tuple(1, 2), tuple(0, 1)]));
    assert(sg.length == 4);
    assert(equal(sg[2..4], [tuple(2, 3), tuple(3, 4)]));

    auto sgsv = sg.save;
    sgsv.popFront();
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sgsv, [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));

    auto sgsv2 = sg[];
    sgsv2.popFront();
    assert(equal(sg, [tuple(0, 1), tuple(1, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(sgsv2, [tuple(1, 2), tuple(2, 3), tuple(3, 4)]));


    sg.front = tuple(2, 2);
    assert(equal(sg, [tuple(2, 2), tuple(2, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(retro(sg), [tuple(3, 4), tuple(2, 3), tuple(2, 2), tuple(2, 2)]));

    sg.popFront();
    assert(equal(sg, [tuple(2, 2), tuple(2, 3), tuple(3, 4)]));
    assert(equal(retro(sg), [tuple(3, 4), tuple(2, 3), tuple(2, 2)]));
    assert(sg.length == 3);
    assert(!sg.empty);

    sg.popFront();
    assert(equal(sg, [tuple(2, 3), tuple(3, 4)]));
    assert(equal(retro(sg), [tuple(3, 4), tuple(2, 3)]));
    assert(sg.length == 2);
    assert(!sg.empty);

    sg.popFront();
    assert(equal(sg, [tuple(3, 4)]));
    assert(equal(retro(sg), [tuple(3, 4)]));
    assert(sg.length == 1);
    assert(!sg.empty);

    sg.front = tuple(2, 5);
    assert(equal(sg, [tuple(2, 5)]));
    assert(equal(retro(sg), [tuple(2, 5)]));
    assert(sg.length == 1);
    assert(!sg.empty);

    sg.front = tuple(2, 1);
    assert(equal(sg, [tuple(2, 1)]));
    assert(sg.length == 1);
    assert(!sg.empty);

    sg.popFront();
    assert(sg.length == 0);
    assert(sg.empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange{
        int[] a;
        @property ref int front(){return a.front;}
        @property bool empty(){return a.empty;}
        void popFront(){a.popFront();}
        void popBack(){a.popBack();}
        @property ref int back(){return a.back();}
        @property TRange save(){return TRange(a.save);}
        @property size_t length(){return a.length;}
        TRange opSlice(size_t i, size_t j){return TRange(a[i..j]);}
        alias length opDollar;
    }


    auto r = TRange([0, 1, 2, 3, 4]);
    auto sg = segment!3(r);
    assert(equal(sg, [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)]));
    assert(equal(retro(sg), [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)].retro));
    assert(sg.length == 3);
    assert(equal(sg[2..3], [tuple(2, 3, 4)]));

    sg.front = tuple(2, 2, 2);
    assert(equal(sg, [tuple(2, 2, 2), tuple(2, 2, 3), tuple(2, 3, 4)]));
    assert(equal(sg.retro, [tuple(2, 2, 2), tuple(2, 2, 3), tuple(2, 3, 4)].retro));

    sg.popFront();
    assert(equal(sg, [tuple(2, 2, 3), tuple(2, 3, 4)]));
    assert(equal(sg.retro, [tuple(2, 2, 3), tuple(2, 3, 4)].retro));
    assert(sg.length == 2);
    assert(!sg.empty);

    sg.back = tuple(4, 4, 4);
    assert(equal(sg, [tuple(2, 4, 4), tuple(4, 4, 4)]));
    assert(equal(sg.retro, [tuple(2, 4, 4), tuple(4, 4, 4)].retro));
    assert(sg.length == 2);
    assert(!sg.empty);

    sg.popFront();
    assert(equal(sg, [tuple(4, 4, 4)]));
    assert(equal(sg.retro, [tuple(4, 4, 4)].retro));
    assert(sg.length == 1);
    assert(!sg.empty);

    sg.popFront();
    assert(sg.length == 0);
    assert(sg.empty);
}
unittest
{
    //debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    struct TRange{
        size_t f, b;
        int[] s;

        this(int[] r){
            f = 0;
            s = r;
            b = s.length - 1;
        }

        @property ref int front(){return s[f];}
        enum bool empty = false;
        void popFront(){++f; if(f == s.length)f = 0;}
        void popBack(){b = (b == 0 ? s.length - 1 : b-1);}
        @property ref int back(){return s[b];}
        @property typeof(this) save(){return this;}
        auto opSlice(size_t i, size_t j){auto dst = this; dst.popFrontN(i); return dst.take(j - i);}
        ref int opIndex(size_t i){return s[(i+f)%s.length];}
    }

    alias TRange Range;
    static assert(isInputRange!TRange);

    auto r = TRange([0, 1, 2, 3, 4]);
    auto sg = segment!3(r);
    assert(equal(sg.take(3), [tuple(0, 1, 2), tuple(1, 2, 3), tuple(2, 3, 4)]));
    assert(equal(retro(sg).take(3), [tuple(2, 3, 4), tuple(1, 2, 3), tuple(0, 1, 2)]));
    assert(sg[2] == tuple(2, 3, 4));
    //assert(equal(sg[2..3], [tuple(2, 3, 4)]));

    sg.front = tuple(2, 2, 2); //[2, 2, 2, 3, 4]
    assert(equal(sg.take(3), [tuple(2, 2, 2), tuple(2, 2, 3), tuple(2, 3, 4)]));
    assert(equal(retro(sg).take(3), [tuple(2, 3, 4), tuple(2, 2, 3), tuple(2, 2, 2)]));

    sg.popFront();
    assert(equal(sg.take(3), [tuple(2, 2, 3), tuple(2, 3, 4), tuple(3, 4, 2)]));
    assert(equal(retro(sg).take(3), [tuple(2, 3, 4), tuple(2, 2, 3), tuple(2, 2, 2)]));
    assert(!sg.empty);

    sg[1] = tuple(3, 3, 3); //[2, 2, 3, 3, 3] 
    assert(equal(sg.take(3), [tuple(2, 3, 3), tuple(3, 3, 3), tuple(3, 3, 2)]));
    assert(equal(sg.retro.take(3), [tuple(3, 3, 3), tuple(2, 3, 3), tuple(2, 2, 3)]));
    assert(!sg.empty);

    sg.back = tuple(2, 3, 4);//[2, 2, 2, 3, 4]
    assert(equal(sg.take(3), [tuple(2, 2, 3), tuple(2, 3, 4), tuple(3, 4, 2)]));
    assert(equal(sg.retro.take(3), [tuple(2, 3, 4), tuple(2, 2, 3), tuple(2, 2, 2)]));
    assert(!sg.empty);

    sg.popBack();
    assert(equal(sg.take(3), [tuple(2, 2, 3), tuple(2, 3, 4), tuple(3, 4, 2)]));
    assert(equal(sg.retro.take(3), [tuple(2, 2, 3), tuple(2, 2, 2), tuple(4, 2, 2)]));
    assert(!sg.empty);
}


/**
concats elements
*/
auto concat(R)(R range) if (isRangeOfRanges!R)
{
    static struct Concat
    {
      private:
        R _range;
        alias ElementType!R ET0;
        alias ElementType!ET0 ET1;
        ET0 _subrange;

      static if(isRangeOfRanges!(R, isBidirectionalRange))
      {
        ET0 _backSubrange;
      }

      public:
      static if(isInfinite!R)
        enum bool empty = false;
      else
      {
        @property
        bool empty()
        {
            return _range.empty;
        }
      }


        @property
        auto ref front()
        {
            return _subrange.front;
        }


      static if(hasAssignableElements!ET0)
      {
        @property
        void front(ET1 v)
        {
            _subrange.front = v;
        }
      }


      /*
      static if(isRangeOfRange!(R, isForwardRange))
      {
        @property
        Concat save()
        {
            return this;
        }
      }
      */


        void popFront()
        {
            if (!_subrange.empty) _subrange.popFront;

            while(_subrange.empty && !_range.empty){
                _range.popFront;

                if (!_range.empty)
                    _subrange = _range.front;
            }
        }


      static if (isRangeOfRanges!(R, isBidirectionalRange))
      {
        @property
        auto ref back()
        {
            return _backSubrange.back;
        }


        static if(hasAssignableElements!ET0)
        {
            @property
            void back(ET1 v)
            {
                _backSubrange.back = v;
            }
        }


        void popBack()
        {
            if (!_backSubrange.empty) _backSubrange.popBack;

            while (_backSubrange.empty && !_range.empty) {
                _range.popBack;
                if (!_range.empty) _backSubrange = _range.back;
            }
        }


        auto retro() @property
        {
            static struct RetroConcat
            {
                auto ref front() @property
                {
                    return _r.back;
                }


                auto ref back() @property
                {
                    return _r.front;
                }


              static if(hasAssignableElements!ET0)
              {
                void front(ET1 v) @property
                {
                    _r.back = v;
                }


                void back(ET1 v) @property
                {
                    _r.front = v;
                }
              }


                void popFront()
                {
                    _r.popBack();
                }


                void popBack()
                {
                    _r.popFront();
                }


              static if(isInfinite!R)
                enum bool empty = false;
              else
                bool empty() @property
                {
                    return _r.empty;
                }


                // save..


                auto retro() @property
                {
                    return _r;
                }


              private:
                Concat _r;
            }


            return RetroConcat(this);
        }
      }
    }


    Concat dst = {_range : range};

    enum initMethod = 
    q{
        if (!dst._range.empty){
            %1$s = dst._range.%2$s;
            while (%1$s.empty && !dst._range.empty){
                dst._range.%3$s;

                if (!dst._range.empty)
                    %1$s = dst._range.%2$s;
            }
        }
    };

    mixin(format(initMethod, "dst._subrange", "front", "popFront"));

  static if (isRangeOfRanges!(R, isBidirectionalRange))
  {
    mixin(format(initMethod, "dst._backSubrange", "back", "popBack"));
  }

    return dst;
}

/// ditto
R concat(R)(R range)
if(isSimpleRange!R)
{
    return range;
}

///
unittest
{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    int[][] r1 = [[0, 1, 2, 3], [4, 5, 6], [7, 8], [9], []];
    auto c = concat(r1);
    assert(equal(c, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
    assert(equal(c.retro(), retro([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]))); // bidir range
    assert(equal(c.retro.retro, c));

    assert(equal(concat(c), c));

    auto r2 = [0, 1, 2, 3, 4, 5];
    assert(equal(r2.map!"[a, 2]".concat, [0, 2, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2]));
    assert(equal(r2[0 .. 4].map!(a => repeat(a, a)).concat, [1, 2, 2, 3, 3, 3]));
    assert(equal(r2[0 .. 3].repeat(2).map!(map!"a + 1").concat, [1, 2, 3, 1, 2, 3]));

    int[] emp;
    assert(emp.repeat(15).concat.empty);
    assert(emp.concat.empty);
}


///
auto flatten(size_t N = size_t.max, R)(R r)
if(isInputRange!R)
{
  static if(N > 0 && isRangeOfRanges!R)
    return r.concat.flatten!(N-1);
  else
    return r;
}

///
unittest
{
    auto d1 = [0, 1, 2, 3, 4, 5, 6, 7, 8];
    assert(equal(d1.flatten, d1));
    assert(equal(d1.flatten!0, d1));

    auto d2 = [[0, 1], [], [2, 3], [4, 5, 6, 7], [8]];
    assert(equal(d2.flatten, d1));
    assert(equal(d2.flatten!1, d1));
    assert(equal(d2.flatten!0, d2));

    auto d3 = [[[0, 1], [], [2, 3]], [[4, 5, 6, 7], [8]]];
    assert(equal(d3.flatten, d1));
    assert(equal(d3.flatten!0, d3));
    assert(equal(d3.flatten!1, d2));
    assert(equal(d3.flatten!2, d1));
}


/**
Haskell等の言語での$(D takeWhile)の実装です。
この実装では、predは任意個数の引数を取ることができます。
たとえば、2引数関数の場合、第一引数にはレンジの先頭の値が、第二引数にはレンジの次の値が格納されます。
*/
auto takeWhile(alias pred, R, T...)(R range, T args)
if(isInputRange!R)
{
    template Parameter(U...)
    {
        enum bool empty = false;
        alias front = U;
        alias tail() = Parameter!(ElementType!R, U);
    }

    alias _pred = naryFun!pred;
    enum arityN = argumentInfo!(_pred, Parameter!T).arity - T.length;

  static if(arityN <= 1)
    return TakeWhileResult!(_pred, arityN, R, T)(range, args);
  else
    return TakeWhileResult!(_pred, arityN, typeof(segment!arityN(range)), T)(segment!arityN(range), args);
}

private struct TakeWhileResult(alias _pred, size_t arityN, SegR, T...)
{
    @property
    bool empty()
    {
        if(_r.empty)
            return true;

        static if(arityN == 0)
            return !_pred(_subArgs);
        else static if(arityN == 1)
            return !_pred(_r.front, _subArgs);
        else
            return !_pred(_r.front.field, _subArgs);
    }


    @property
    auto front()
    {
      static if(arityN <= 1)
        return _r.front;
      else
        return _r.front.field[0];
    }


    void popFront()
    {
        _r.popFront();
    }


  static if(isForwardRange!(typeof(_r)))
  {
    @property
    auto save()
    {
        return TakeWhileResult!(_pred, arityN, typeof(_r.save), T)(_r.save, _subArgs);
    }
  }

  private:
    SegR _r;
    T _subArgs;
}

/// ditto
unittest
{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    int[] em;
    assert(takeWhile!"true"(em).empty);

    auto r1 = [1, 2, 3, 4, 3, 2, 1];
    auto tw1 = takeWhile!"a < b"(r1);
    assert(equal(tw1, [1, 2, 3]));

    auto tw2 = takeWhile!"a < b && b < c"(r1);
    assert(equal(tw2, [1, 2]));

    auto tw3 = takeWhile!"a == (b - c)"(r1, 1);
    assert(equal(tw3, [1, 2, 3]));

    auto tw4 = takeWhile!"true"(r1);
    assert(equal(tw4, r1));

    auto tw5 = takeWhile!"false"(r1);
    assert(tw5.empty);
}



/**
受け取ったレンジの要素をそれぞれ連続してn回繰り返すようなレンジを返します。
*/
auto resampling(R)(R range, size_t n)
{
    alias E = ElementType!R;

    static struct SamplerResult
    {
        E front() @property { return _f; }


        void popFront()
        {
            ++_cnt;
            if(_cnt == _n){
                if(!_r.empty){
                    _f = _r.front;
                    _r.popFront();
                    _cnt = 0;
                }
            }
        }


        bool empty() const
        {
            return (_n == 0) || (_cnt == _n && _r.empty);
        }


      private:
        size_t _cnt;
        size_t _n;
        R _r;
        E _f;
    }

    if(range.empty)
        return SamplerResult.init;

    auto f = range.front;
    range.popFront();

    return SamplerResult(0, n, range, f);
}

///
unittest
{
    debug scope(failure) writefln("unittest Failure :%s(%s)", __FILE__, __LINE__);
    debug scope(success) {writefln("Unittest Success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    import std.stdio;
    uint[] arr = [0, 1, 2];
    //writeln(arr.resampling(3));
    assert(arr.resampling(3).equal([0,0,0,1,1,1,2,2,2,]));

    assert(arr.resampling(0).empty);

    uint[] emp = [];
    assert(emp.resampling(3).empty);
}


/**
std.range.iotaを汎用的にしたものです．
*/
auto giota(alias add = "a + b", alias pred = "a == b", S, E, D)(S start, E end, D diff)
if(is(typeof((S s, E e, D d){ s = binaryFun!add(s, d); if(binaryFun!pred(s, e)){} })))
{
    static struct Iota
    {
        inout(S) front() inout @property { return _value; }
        bool empty() @property { return !!binaryFun!pred(_value, _end); }
        void popFront() { _value = binaryFun!add(_value, _diff); }

      private:
        S _value;
        E _end;
        D _diff;
    }


    return Iota(start, end, diff);
}


/// ditt
auto giotaInf(alias add = "a + b", S, D)(S start, D diff)
if(is(typeof((S s, D d){ s = binaryFun!add(s, d); })))
{
    static struct IotaInf
    {
        inout(S) front() inout @property { return _value; }
        enum bool empty = false;
        void popFront() { _value = binaryFun!add(_value, _diff); }

      private:
        S _value;
        D _diff;
    }


    return IotaInf(start, diff);
}


///
unittest
{
    import std.datetime;
    import core.time;

    auto ds1 = giota(Date(2004, 1, 1), Date(2005, 1, 1), days(1));
    assert(ds1.walkLength() == 366);


    auto ds2 = giotaInf(Date(2004, 1, 1), days(2));
    assert(ds2.front == Date(2004, 1, 1)); ds2.popFront();
    assert(ds2.front == Date(2004, 1, 3)); ds2.popFront();
    assert(ds2.front == Date(2004, 1, 5));
}


auto whenEmpty(alias func, R)(R range)
if(isInputRange!R && isCallable!func)
{
    static struct ResultRangeOfWhenEmpty
    {
        auto ref front() { return _r.front; }

      static if(isInfinite!R)
        enum bool empty = false;
      else
      {
        bool empty() @property { return _r.empty; }
      }


        void popFront()
        {
            _r.popFront();
            if(_r.empty){
                func();
            }
        }

      private:
        R _r;
    }


    ResultRangeOfWhenEmpty res;
    res._r = range;
    return res;
}

///
unittest
{
    {
        static auto arrA = [1, 2, 3];
        auto r = arrA.whenEmpty!((){ arrA = null; });
        assert(equal(r, arrA));
        assert(arrA is null);
    }
    {
        static auto arrB = [1, 2, 3];
        auto r = arrB.whenEmpty!((){ arrB = null; });
        //assert(equal(r, arr));
        r.popFront(); r.popFront();
        assert(arrB !is null);
        r.popFront();
        assert(arrB is null);
    }
}


auto whenEmpty(R, Fn)(R range, Fn fn)
if(isCallable!Fn)
{
    static struct ResultRangeOfWhenEmpty
    {
        auto ref front() { return _r.front; }

      static if(isInfinite!R)
        enum bool empty = false;
      else
      {
        bool empty() @property { return _r.empty; }
      }


        void popFront()
        {
            _r.popFront();
            if(_r.empty){
                _fn();
            }
        }

      private:
        R _r;
        Fn _fn;
    }


    ResultRangeOfWhenEmpty res;
    res._r = range;
    res._fn = fn;
    return res;
}

///
unittest
{
    {
        auto arr = [1, 2, 3];
        auto r = arr.whenEmpty((){ arr = null; });
        assert(equal(r, arr));
        assert(arr is null);
    }
    {
        auto arr = [1, 2, 3];
        auto r = arr.whenEmpty((){ arr = null; });
        //assert(equal(r, arr));
        r.popFront(); r.popFront();
        assert(arr !is null);
        r.popFront();
        assert(arr is null);
    }
}
