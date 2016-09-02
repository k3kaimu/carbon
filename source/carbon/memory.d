module carbon.memory;

import carbon.functional;

import core.exception;
import core.stdc.stdlib;
import core.memory;

import std.algorithm;
import std.conv;
import std.stdio;
import std.exception;
import std.range;
import std.traits;
import std.typecons;


void fastPODCopy(R1, R2)(R1 src, R2 dst)
if(isInputRange!R1 && isInputRange!R2 && hasAssignableElements!R2)
{
    alias E1 = ElementType!R1;
    alias E2 = ElementType!R2;

  static if(isArray!R1 && is(Unqual!R1 == Unqual!R2))
  {
    dst[] = src[];
  }
  else static if(isArray!R1 && isArray!R2 && E1.sizeof == E2.sizeof)
  {
    auto ub1 = cast(ubyte[])src;
    auto ub2 = cast(ubyte[])dst;
    ub2[] = ub1[];
  }
  else
  {
    import std.algorithm : copy;
    copy(src, dst);
  }
}


void callAllPostblit(T)(ref T obj)
if(is(T == struct))
{
    foreach(ref e; obj.tupleof)
        callAllPostblit(e);

    static if(is(typeof(obj.__postblit())))
        obj.__postblit();
}


void callAllPostblit(T)(ref T obj)
if(!is(T == struct))
{}


void callAllDtor(T)(ref T obj)
if(is(T == struct))
{
    static if(is(typeof(obj.__dtor())))
        obj.__dtor();

    foreach(ref e; obj.tupleof)
        callAllDtor(e);
}


void callAllDtor(T)(ref T obj)
if(!is(T == struct))
{}



// copy from core.exception
extern (C) void onOutOfMemoryError(void* pretend_sideffect = null) @nogc @trusted pure nothrow /* dmd @@@BUG11461@@@ */
{
    // NOTE: Since an out of memory condition exists, no allocation must occur
    //       while generating this object.
    throw cast(OutOfMemoryError) cast(void*) typeid(OutOfMemoryError).init;
}


private
E[] uninitializedCHeapArray(E)(size_t n) @trusted nothrow
{
    if(n){
        auto p = cast(E*)core.stdc.stdlib.malloc(n * E.sizeof);
        if(p is null)
            onOutOfMemoryError();

      static if(hasIndirections!E)
      {
        core.stdc.string.memset(p, 0, n * E.sizeof);
        GC.addRange(p, n * E.sizeof);
      }

        return p[0 .. n];
    }else
        return null;
}


private
void destroyCHeapArray(E)(ref E[] arr) nothrow @nogc
{
    static if(hasElaborateDestructor!E)
        foreach(ref e; arr)
            callAllDtor(e);

    static if(hasIndirections!E)
        GC.removeRange(arr.ptr);

    assumeTrusted!(core.stdc.stdlib.free)(arr.ptr);
    arr = null;
}


private
void reallocCHeapArray(E)(ref E[] arr, size_t n)
{
    if(n <= arr.length)     // n == 0 なら常に return される
        return;

    immutable oldLen = arr.length;

  static if(hasIndirections!T)
  {
    auto newarr = uninitializedCHeapArray!E(n);
    assumeTrusted!(core.stdc.string.memcpy)(newarr.ptr, arr.ptr, E.sizeof * oldLen);
    assumeTrusted!(core.stdc.string.memset)(assumeTrusted!"a+b"(newarr.ptr + oldLen), 0, (n - oldLen) * E.sizeof);
    GC.addRange(newarr.ptr, n * E.sizeof);
    GC.removeRange(arr.ptr);
    assumeTrusted!(core.stdc.stdlib.free)(arr.ptr);

    arr = newarr;
  }
  else
  {
    void* p = assumeTrusted!(core.stdc.stdlib.realloc)(arr.ptr, n * E.sizeof);
    if(p is null)
        onOutOfMemoryError();

    arr = assumeTrusted!((a, b) => (cast(E*)a)[0 .. b])(p, n);
  }
}


auto onGCMemory(T)(T obj)
{
    static struct Result {
        alias _val this;
        ref inout(T) _val() inout pure nothrow @safe @property { return *_v; }
        T* _v;
    }

    Result res = Result(new T);
    *res._v = obj;
    return res;
}

unittest
{
    auto r = [1, 2, 3, 4, 5].map!"a+2".onGCMemory;

    static void popN(R)(R r, size_t n)
    {
        foreach(i; 0 .. n) r.popFront();
    }

    assert(equal(r.save, [3, 4, 5, 6, 7]));
    popN(r, 2);
    assert(equal(r.save, [5, 6, 7]));
}



/**
*/
struct UninitializedTemporaryBuffer(T)
{
    import core.stdc.stdlib;

    @disable
    this(this);


    this(size_t n) @trusted
    {
        slice = uninitializedCHeapArray!T(n);
    }


    ~this() @trusted
    {
        destroyCHeapArray(slice);
    }


    T[] slice;
    alias slice this;
}


/**
Defines a reference-counted object containing a $(D T) value as
payload. $(D RefCountedNoGC) keeps track of all references of an object,
and when the reference count goes down to zero, frees the underlying
store. $(D RefCountedNoGC) uses $(D malloc) and $(D free) for operation.

$(D RefCountedNoGC) is unsafe and should be used with care. No references
to the payload should be escaped outside the $(D RefCountedNoGC) object.

The $(D autoInit) option makes the object ensure the store is
automatically initialized. Leaving $(D autoInit ==
RefCountedAutoInitialize.yes) (the default option) is convenient but
has the cost of a test whenever the payload is accessed. If $(D
autoInit == RefCountedAutoInitialize.no), user code must call either
$(D refCountedStore.isInitialized) or $(D refCountedStore.ensureInitialized)
before attempting to access the payload. Not doing so results in null
pointer dereference.

Example:
----
// A pair of an $(D int) and a $(D size_t) - the latter being the
// reference count - will be dynamically allocated
auto rc1 = RefCountedNoGC!int(5);
assert(rc1 == 5);
// No more allocation, add just one extra reference count
auto rc2 = rc1;
// Reference semantics
rc2 = 42;
assert(rc1 == 42);
// the pair will be freed when rc1 and rc2 go out of scope
----
 */
struct RefCountedNoGC(T, RefCountedAutoInitialize autoInit =
        RefCountedAutoInitialize.yes)
if (!is(T == class))
{
    /// $(D RefCountedNoGC) storage implementation.
    struct RefCountedStore
    {
        private struct Impl
        {
            T _payload;
            size_t _count;
        }

        private Impl* _store;

        private void initialize(A...)(auto ref A args)
        {
            import core.memory : GC;
            import core.stdc.stdlib : malloc;
            import std.conv : emplace;
            import std.exception : enforce;

            _store = cast(Impl*)malloc(Impl.sizeof);
            if(!_store)
                onOutOfMemoryError();

            static if (hasIndirections!T)
                GC.addRange(&_store._payload, T.sizeof);
            emplace(&_store._payload, args);
            _store._count = 1;
        }

        /**
           Returns $(D true) if and only if the underlying store has been
           allocated and initialized.
        */
        @property nothrow @safe @nogc
        bool isInitialized() const
        {
            return _store !is null;
        }

        /**
           Returns underlying reference count if it is allocated and initialized
           (a positive integer), and $(D 0) otherwise.
        */
        @property nothrow @safe @nogc
        size_t refCount() const
        {
            return isInitialized ? _store._count : 0;
        }

        /**
           Makes sure the payload was properly initialized. Such a
           call is typically inserted before using the payload.
        */
        void ensureInitialized()
        {
            if (!isInitialized) initialize();
        }

    }
    RefCountedStore _refCounted;

    /// Returns storage implementation struct.
    @property nothrow @safe
    ref inout(RefCountedStore) refCountedStore() inout
    {
        return _refCounted;
    }

/**
Constructor that initializes the payload.

Postcondition: $(D refCountedStore.isInitialized)
 */
    this(A...)(auto ref A args) if (A.length > 0)
    {
        _refCounted.initialize(args);
    }

/**
Constructor that tracks the reference count appropriately. If $(D
!refCountedStore.isInitialized), does nothing.
 */
    this(this)
    {
        if (!_refCounted.isInitialized) return;
        ++_refCounted._store._count;
    }

/**
Destructor that tracks the reference count appropriately. If $(D
!refCountedStore.isInitialized), does nothing. When the reference count goes
down to zero, calls $(D destroy) agaist the payload and calls $(D free)
to deallocate the corresponding resource.
 */
    ~this()
    {
        if (!_refCounted.isInitialized) return;
        assert(_refCounted._store._count > 0);
        if (--_refCounted._store._count)
            return;
        // Done, deallocate
        static if(hasElaborateDestructor!T)
            callAllDtor(_refCounted._store._payload);

        static if (hasIndirections!T)
        {
            import core.memory : GC;
            GC.removeRange(&_refCounted._store._payload);
        }
        import core.stdc.stdlib : free;
        free(_refCounted._store);
        _refCounted._store = null;
    }

/**
Assignment operators
 */
    void opAssign(typeof(this) rhs)
    {
        import std.algorithm : swap;

        swap(_refCounted._store, rhs._refCounted._store);
    }

/// Ditto
    void opAssign(T rhs)
    {
        import std.algorithm : move;

        static if (autoInit == RefCountedAutoInitialize.yes)
        {
            _refCounted.ensureInitialized();
        }
        else
        {
            assert(_refCounted.isInitialized);
        }
        move(rhs, _refCounted._store._payload);
    }

    //version to have a single properly ddoc'ed function (w/ correct sig)
    version(StdDdoc)
    {
        /**
        Returns a reference to the payload. If (autoInit ==
        RefCountedAutoInitialize.yes), calls $(D
        refCountedStore.ensureInitialized). Otherwise, just issues $(D
        assert(refCountedStore.isInitialized)). Used with $(D alias
        refCountedPayload this;), so callers can just use the $(D RefCountedNoGC)
        object as a $(D T).

        $(BLUE The first overload exists only if $(D autoInit == RefCountedAutoInitialize.yes).)
        So if $(D autoInit == RefCountedAutoInitialize.no)
        or called for a constant or immutable object, then
        $(D refCountedPayload) will also be qualified as safe and nothrow
        (but will still assert if not initialized).
         */
        @property
        ref T refCountedPayload();

        /// ditto
        @property nothrow @safe
        ref inout(T) refCountedPayload() inout;
    }
    else
    {
        static if (autoInit == RefCountedAutoInitialize.yes)
        {
            //Can't use inout here because of potential mutation
            @property
            ref T refCountedPayload()
            {
                _refCounted.ensureInitialized();
                return _refCounted._store._payload;
            }
        }

        @property nothrow @safe
        ref inout(T) refCountedPayload() inout
        {
            assert(_refCounted.isInitialized, "Attempted to access an uninitialized payload.");
            return _refCounted._store._payload;
        }
    }

/**
Returns a reference to the payload. If (autoInit ==
RefCountedAutoInitialize.yes), calls $(D
refCountedStore.ensureInitialized). Otherwise, just issues $(D
assert(refCountedStore.isInitialized)).
 */
    alias refCountedPayload this;
}


auto toRefCounted(T)(T obj)
{
    return RefCountedNoGC!T(obj);
}


@nogc unittest
{
    auto r = only(1, 2, 3, 4, 5).map!"a+2".toRefCounted;

    static void popN(R)(R r, size_t n)
    {
        foreach(i; 0 .. n) r.popFront();
    }

    assert(equal(r.save, only(3, 4, 5, 6, 7)));
    popN(r, 2);
    assert(equal(r.save, only(5, 6, 7)));
}


__EOF__


struct UniqueArray(E, bool bMini = false)
{
    private static
    size_t allocateSize(size_t n) pure nothrow @safe @nogc
    {
      static if(bMini)
        return n;
      else
        return 1 << (core.bitop.bsr(n) + 1);
    }


    /**
    */
    this(size_t n) nothrow @trusted
    {
        immutable elemN = allocateSize(n);

        auto arr = uninitializedCHeapArray!(Unqual!(E))(elemN);
        foreach(ref e; arr)
            .emplace(&e);

        _array = cast(E[])arr;
        _s = 0;
        _e = n;
    }


  static if(is(typeof((Unqual!E v){ E x = v; })))
  {
    this(bool b)(UniqueArray!(Unqual!E, b) unique) @trusted
    {
        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }


    void opAssign(bool b)(UniqueArray!(const(E), b) unique) @trusted
    {
        //.destroy(this);
        callAllDtor(this);

        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }
  }


  static if(is(typeof((const E v){ E x = v; })))
  {
    this(bool b)(UniqueArray!(const(E), b) unique) @trusted
    {
        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }


    void opAssign(bool b)(UniqueArray!(const(E), b) unique) @trusted
    {
        //.destroy(this);
        callAllDtor(this);

        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }
  }


  static if(is(typeof((immutable E v){ E x = v; })))
  {
    this(bool b)(UniqueArray!(immutable(E), b) unique) @trusted
    {
        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }


    void opAssign(bool b)(UniqueArray!(immutable(E), b) unique) @trusted
    {
        //.destroy(this);
        callAllDtor(this);

        _array = cast(E[])unique._array;
        _s = unique._s;
        _e = unique._e;

        unique._array = null;
    }
  }


    ~this()
    {
        if(_array !is null){
          static if(hasElaborateDestructor!E)
            foreach(ref e; _array)
                callAllDtor(e);
                //.destroy(e);

          static if(hasIndirections!E)
            GC.removeRange(_array.ptr);

            core.stdc.stdlib.free(cast(void*)_array.ptr);
            _array = null;
        }
    }

    // can copy
  static if(is(typeof((E v){ E x = v; })))
  {
    this(this)
    {
        immutable elemN = (_s == 0 && _e == _array.length) ? _array.length : allocateSize(this.length);

        auto newarr = uninitializedCHeapArray!(Unqual!E)(elemN);
        assumeTrusted!((p){
            foreach(i, ref e; this.view)
                emplace(p + i, e);
        })(newarr.ptr);

        _array = cast(E[])newarr;
        _e -= _s;
        _s = 0;
    }


    void opAssign(typeof(this) unique)
    {
        swap(this, unique);
    }
  }
  else{
    @disable this(this);
    @disable void opAssign(typeof(this) unique);
  }


    size_t length() const pure nothrow @safe @nogc @property
    {
        return _e - _s;
    }


    size_t capacity() const pure nothrow @safe @nogc @property
    {
        return _array.length - _e;
    }


    size_t reserve(size_t n) @nogc
    {
        if(_array is null){
            auto newArr = typeof(this)(n);
            this._array = newArr._array;
            this._s = newArr._s;
            this._e = newArr._e;
            newArr._array = null;

            return this.capacity;
        }
        else if(n <= _array.length - _s)
            return this.capacity;
        else{
            immutable newElemN = allocateSize(n);
            immutable newAllocN = newElemN * E.sizeof;

            auto p = cast(Unqual!E*)core.stdc.stdlib.malloc(newAllocN);
            if(!p)
                onOutOfMemoryError();

            core.stdc.string.memcpy(p, _array.ptr + _s, this.length * E.sizeof);

          static if(hasIndirections!E)
          {
            core.stdc.string.memset(p + this.length, 0, (newElemN - this.length) * E.sizeof);
            GC.addRange(p, newAllocN);
            GC.removeRange(_array.ptr);
          }

            core.stdc.stdlib.free(cast(Unqual!E*)_array.ptr);
            _array = (cast(E*)p)[0 .. newElemN];
            _e -= _s;
            _s = 0;

            return this.capacity;
        }
    }


    E[] view() pure nothrow @safe @nogc
    {
        return _array;
    }


  private:
    E[] _array ;
    size_t _s, _e;
}


unittest{
    UniqueArray!int arr;

    auto rc = RefCountedNoGC!(UniqueArray!int)(3);
}


struct RefCountedArrayImpl(E)
{
    this(size_t n) nothrow @trusted @nogc
    {
        _refCnt = uninitializedCHeapArray!size_t(1).ptr;
        *_refCnt = 1;
        _array = newCHeapArray!E(n);
    }


    bool isInitialized() const pure nothrow @safe @nogc @property
    {
        return _refCnt !is null;
    }


    size_t refCount() const pure nothrow @safe @nogc @property
    {
        return isInitialized ? *_refCnt : 0;
    }


    this(this) pure nothrow @safe @nogc
    {
        if(isInitialized)
            ++*_refCnt;
    }


  static if(is(typeof(() @safe { E e; })))
  {
    ~this() @trusted
    { dtorImpl(); }
  }
  else
  {
    ~this()
    { dtorImpl(); }
  }


    void dtorImpl()
    {
        if(isInitialized){
            --*_refCnt;
            if(refCount == 0){
                size_t[] dummy = _refCnt[0 .. 1];

                dummy.destroyCHeapArray();   // nothrow
                _refCnt = null;

                _array.destroyCHeapArray();  // maybe throw
            }
        }
    }


    void reallocate(size_t n)
    {
        _array.reallocCHeapArray(n);
    }


  private:
    size_t* _refCnt;
    E[] _array;
}


/**
Cヒープ上に配列を作成し、その配列を参照カウント方式で管理します。
配列への追加は、スライスと同様にCopy On Write方式で管理されます。
つまり、複数のオブジェクトが一つの配列を参照している場合に配列への要素の追加を行うと、必ず配列は新たに確保されます。
*/
struct RefCountedArray(E)
{
    alias Impl = RefCountedArrayImpl;


    /**
    大きさを指定して配列を作成します。
    */
    this(size_t n)
    {
        _impl = Impl!E(allocateSize!E(n));
        _s = 0;
        _e = n;
    }


    /**
    保持している参照を解除します。
    よって、参照カウントは一つ減ります。
    */
    void release()
    {
        _impl = Impl!E.init;
        _s = 0;
        _e = 0;
    }


    /**
    */
    void clear()
    {
        if(_impl.refCount == 1){
            _s = 0;
            _e = 0;
        }else
            release();
    }


    /**
    */
    size_t capacity() const pure nothrow @safe @nogc @property
    {
        if(_impl.refCount == 1)
            return _impl._array.length - _s;
        else
            return 0;
    }


    /**
    */
    size_t reserve(size_t n)
    {
        if(n <= this.length)
            goto Lreturn;

        if(!_impl.isInitialized)
            this = typeof(this)(n);
        else if(_impl.refCount == 1 && _impl._array.length < n + _s){
            immutable bool doesMoveToFront = (_s * 2 >= allocateSize!E(n) - _impl._array.length);

            if(!doesMoveToFront || _impl._array.length < n)
                _impl.reallocate(allocateSize!E(n));

            if(doesMoveToFront){
                foreach(i; 0 .. this.length){
                  static if(is(E == struct) && !__traits(isPOD, E))
                    _impl._array[i] = std.algorithm.move(_impl._array[_s + i]);
                  else
                    _impl._array[i] = _impl._array[_s + i];
                }

                _e -= _s;
                _s = 0;
            }
        }
        else if(_impl.refCount != 1){
            auto newarr = typeof(this)(n);
            newarr._impl._array[0 .. this.length] = this._impl._array[_s .. _e];
            this = newarr;
        }

      Lreturn:
        return this.capacity;
    }


    /**
    */
    bool isNull() const pure nothrow @safe @nogc @property
    {
        return !_impl.isInitialized;
    }


    /**
    代入演算子です。
    このオブジェクトに&(D null)を代入すると、$(D release)を呼び出したことと等価になります。
    */
    void opAssign(typeof(null))
    {
        release();
    }


    /// array, range primitives
    ref inout(E) front() inout pure nothrow @safe @nogc @property
    {
        return _impl._array[_s];
    }


    /// ditto
    ref inout(E) back() inout pure nothrow @safe @nogc @property
    {
        return _impl._array[_e-1];
    }


    /// ditto
    bool empty() const pure nothrow @safe @nogc @property
    {
        return !_impl.isInitialized || _s == _e;
    }


    /// ditto
    void popFront()
    {
        ++_s;

        if(this.empty)
            this.clear();
    }


    /// ditto
    void popBack()
    {
        --_e;

        if(this.empty)
            this.clear();
    }


    /// ditto
    auto save() @property
    {
        return this;
    }


    /// ditto
    ref inout(E) opIndex(size_t i) inout pure nothrow @safe @nogc
    in{
        assert(i < this.length);
    }
    body{
        return _impl._array[_s + i];
    }


    /// ditto
    auto opSlice()
    {
        return this;
    }


    /// ditto
    size_t length() const pure nothrow @safe @nogc @property
    {
        return _e - _s;
    }


    /// ditto
    alias opDollar = length;


    /// ditto
    void length(size_t n) @property
    {
        reserve(n);
        _e = _s + n;
    }


    /// ditto
    RefCountedArray!E dup() @property
    {
        auto dst = typeof(return)(this.length);
        dst._impl._array[0 .. this.length] = this._impl._array[_s .. _e];
        return dst;
    }


  static if(is(const(E) : E))
  {
    /// ditto
    RefCountedArray!E dup() const @property
    {
        auto dst = typeof(return)(this.length);
        dst._impl._array[0 .. this.length] = this._impl._array[_s .. _e];
        return dst;
    }
  }


    /// ditto
    inout(E)[] view() inout pure nothrow @safe @nogc @property
    {
        return _impl._array[_s .. _e];
    }


    /// ditto
    auto opSlice(size_t i, size_t j)
    in{
        immutable len = this.length;
        assert(i <= len);
        assert(j <= len);
        assert(i <= j);
    }
    body{
        auto dst = this;
        dst._s += i;
        dst._e = dst._s + (j - i);
        return dst;
    }


    /// ditto
    void opOpAssign(string op : "~")(E v)
    {
        this.length = this.length + 1;
        this.back = v;
    }


    /// ditto
    typeof(this) opBinary(string op : "~")(E v)
    {
        if(_impl.refCount == 1 && this.capacity != this.length){
            auto dst = this;
            dst._e += 1;
            dst.back = v;
            return dst;
        }
        else{
            auto dst = this;
            dst ~= v;
            return dst;
        }
    }


    /// ditto
    typeof(this) opBinaryRight(string op : "~")(E v)
    {
        if(_impl.refCount == 1 && _s >= 1){
            auto dst = this;
            dst._s -= 1;
            dst.front = v;
            return dst;
        }
        else{
            typeof(this) dst;
            dst.reserve(1 + this.length);
            dst ~= v;
            dst ~= this.view;
            return dst;
        }
    }


    /// ditto
    void opOpAssign(string op : "~")(E[] arr)
    {
        immutable oldLen = this.length;
        this.length = oldLen + arr.length;
        this._impl._array[oldLen .. this.length] = arr[0 .. $];
    }


    /// ditto
    typeof(this) opBinary(string op : "~")(E[] arr)
    {
        immutable len = arr.length;
        if(_impl.refCount <= 1 && this.capacity >= this.length + len){
            auto dst = this;
            dst._e += len;
            dst._impl._array[this._e .. dst._e] = arr[0 .. $];
            return dst;
        }
        else{
            auto dst = this;
            dst ~= arr;
            return dst;
        }
    }


    /// ditto
    typeof(this) opBinaryRight(string op : "~")(E[] arr)
    {
        immutable len = arr.length;
        if(_impl.refCount == 1 && _s >= len){
            auto dst = this;
            dst._s -= len;
            dst._impl._array[dst._s .. this._s] = arr[0 .. $];
            return dst;
        }
        else{
            typeof(this) dst;
            dst.reserve(len + this.length);
            dst ~= arr;
            dst ~= this.view;
            return dst;
        }
    }


    /// ditto
    void opOpAssign(string op : "~")(typeof(this) src)
    {
        this ~= src.view;
    }


    /// ditto
    typeof(this) opBinary(string op : "~")(typeof(this) src)
    {
        return this ~ src.view;
    }


    /// ditto
    void opOpAssign(string op : "~", R)(R range)
    if(isInputRange!R && is(ElementType!R : E) && !isInfinite!R)
    {
      static if(hasLength!R)
      {
        immutable oldLen = this.length,
                  rangeLen = range.length;
        this.length = oldLen + rangeLen;

        foreach(i; 0 .. rangeLen){
            assert(!range.empty);
            _impl._array[_s + oldLen + i] = range.front;
            range.popFront();
        }
      }
      else
      {
        if(_impl.isInitialized)
            this = this.dup;
        else
            this = typeof(this)(0);

        assert(this._impl.refCount == 1);
        assert(this._s == 0);

        while(!range.empty){
            immutable remN = this._impl._array.length - _e;

            size_t cnt;
            foreach(i; 0 .. remN){
                if(range.empty)
                    break;

                this._impl._array[_e + i] = range.front;
                ++cnt;
                range.popFront();
            }
            _e += cnt;

            if(cnt == remN && !range.empty)
                reserve(_e + 1);
        }
      }
    }


    /// ditto
    typeof(this) opBinary(string op : "~", R)(R range)
    if(isInputRange!R && is(ElementType!R : E) && !isInfinite!R)
    {
      static if(hasLength!R)
      {
        immutable len = range.length;
        if(_impl.refCount <= 1 && this.capacity >= this.length + len){
            auto dst = this;
            dst._e += len;
            foreach(i; 0 .. len){
                dst._impl._array[this._e + i] = range.front;
                range.popFront();
            }
            return dst;
        }
      }
      
        auto dst = this;
        dst ~= range;
        return this ~ dst;
    }


    /// ditto
    typeof(this) opBinaryRight(string op : "~", R)(R range)
    if(isInputRange!R && is(ElementType!R : E) && !isInfinite!R && !is(typeof(range.opBinary!"~"(this))))
    {
      static if(hasLength!R)
      {
        immutable len = range.length;
        if(_impl.refCount <= 1 && _s >= len){
            auto dst = this;
            dst._s -= len;
            foreach(i; 0 .. len){
                dst._impl._array[dst._s + i] = range.front;
                range.popFront();
            }
            return dst;
        }

        typeof(this) dst;
        dst.reserve(this.length + len);
        dst ~= range;
        dst ~= this.view;
        return dst;
      }
      else
      {
        typeof(this) dst;
        dst ~= range;
        return this ~ dst;
      }
    }


    /// ditto
    int opCmp(R)(auto ref R r)
    if(isForwardRange!R && is(typeof(r.front < this.front)))
    {
        return std.algorithm.cmp(this.view, r.save);
    }


    /// ditto
    bool opEquals(R)(auto ref R r)
    if(isForwardRange!R && is(typeof(r.front == this.front)))
    {
        return std.algorithm.equal(this.view, r.save);
    }


  private:
    Impl!E _impl;
    size_t _s, _e;
}


/*nothrow @safe @nogc*/ unittest{
    auto arr1 = RefCountedArray!int(0);
    static assert(isInputRange!(typeof(arr1)));
    static assert(isForwardRange!(typeof(arr1)));
    static assert(isRandomAccessRange!(typeof(arr1)));
    static assert(hasLength!(typeof(arr1)));
    static assert(hasSlicing!(typeof(arr1)));

    assert(arr1.length == 0);
    assert(equal(arr1, cast(int[])[]));
    assert(!arr1.isNull);

    arr1 ~= 1;
    assert(arr1.length == 1);
    assert(equal(arr1, only(1)));
    assert(!arr1.isNull);

    arr1 ~= only(2, 3);
    assert(arr1.length == 3);
    assert(equal(arr1, only(1, 2, 3)));
    assert(!arr1.isNull);

    arr1 ~= arr1;
    assert(arr1.length == 6);
    assert(equal(arr1, only(1, 2, 3, 1, 2, 3)));
    assert(!arr1.isNull);

    arr1 = arr1[2 .. $-1];
    assert(arr1.length == 3);
    assert(equal(arr1, only(3, 1, 2)));
    assert(!arr1.isNull);

    arr1 = arr1.dup;
    assert(arr1.length == 3);
    assert(equal(arr1, only(3, 1, 2)));
    assert(!arr1.isNull);

    arr1 = null;
    assert(arr1.isNull);

    arr1 ~= only(1, 2, 3, 4);
    assert(arr1.length == 4);
    assert(equal(arr1, only(1, 2, 3, 4)));
    assert(!arr1.isNull);

    assert(equal(arr1, arr1.retro.retro));

    {
        auto arr2 = arr1.retro;
        foreach_reverse(e; arr1){
            assert(e == arr2.front);
            arr2.popFront();
        }
    }


    static assert(isForwardRange!(typeof(only(1, 2, 3))));


    arr1.release();
    arr1 ~= only(1, 2, 3);
    assert(arr1 < only(2));
    assert(arr1 < only(1, 2, 3, 4));
    assert(arr1 < only(1, 2, 4));

    assert(arr1 <= arr1);

    assert(arr1 >= arr1);
    assert(arr1 == arr1);

    assert(arr1 > only(1));
    assert(arr1 > only(1, 2));
    assert(arr1 > only(1, 2, 2));
    assert(arr1 > only(1, 2, 2, 4));

    assert(arr1 == only(1, 2, 3));
    assert(arr1 != only(1, 2, 3, 4));


    // length, capacity, reserve test
    assert(arr1.length == 3);
    assert(arr1._impl.refCount == 1);
    assert(arr1.capacity == 4);
    foreach(i; 0 .. arr1.capacity - arr1.length)
        arr1 ~= i;

    assert(arr1.length == 4);
    assert(arr1.capacity - arr1.length == 0);

    foreach(i; 0 .. 3)
        arr1.popFront();

    assert(arr1.length == 1);
    assert(arr1.capacity - arr1.length == 0);

    arr1.reserve(arr1.length + 1);  //  all elements moved to front.
    assert(arr1._s == 0);
    assert(arr1._e == arr1.length);
    assert(arr1.capacity - arr1.length == 3);
}


unittest{
    import std.typecons;

    auto arr = RefCountedArray!(RefCountedNoGC!int)(0);
    assert(arr.length == 0);

    arr ~= RefCountedNoGC!int(1);
    assert(arr.length == 1);
    assert(arr.front == 1);
    assert(arr.front.refCountedStore.refCount == 1);

    auto e = arr.front;
    assert(arr.front.refCountedStore.refCount == 2);
    assert(e.refCountedStore.refCount == 2);
    arr.popFront();
    arr.release();
    assert(e.refCountedStore.refCount == 1);

    arr ~= RefCountedNoGC!int(1);
    e = arr.front;
    assert(arr.front.refCountedStore.refCount == 2);
    assert(e.refCountedStore.refCount == 2);

    arr[0] = RefCountedNoGC!int(2);
    assert(arr.front.refCountedStore.refCount == 1);
    assert(e.refCountedStore.refCount == 1);

    auto arr2 = arr.dup;
    assert(arr.front.refCountedStore.refCount == 2);
    assert(e.refCountedStore.refCount == 1);
}


/+
unittest{
    static void func(T)()
    {
        T a;

        a ~= 1;
        foreach(i; 0 .. 15)
            a ~= a;

        T b;
        foreach(e; a[0 .. 1024 * 32])
            b ~= e;
    }

    static void funcAppender()
    {
        import std.array;
        auto b = appender!(int[])();
        foreach(e; recurrence!"a[n-1]+a[n-2]"(1, 1).take(32 * 1024))
            b ~= e;
    }


    import std.datetime;
    import std.container;
    auto ts = benchmark!(func!(int[]),
                         func!(RefCountedArray!int),
                         func!(Array!int),
                         funcAppender)(100);

    writeln(ts);


    RefCountedArray!int b;
    foreach(e; recurrence!"a[n-1]+a[n-2]"(1, 1).take(1024))
            b ~= e;
}+/


/**
Cヒープ上に配列を作成します。
この配列は、必ずオブジェクト一つに対してユニークな配列を割り当てます。
つまり、ほとんどの場面で配列の確保とコピーが生じます。
この方式は、C++のSTL std::vectorと同じです。
*/
struct UniqueArray(E)
{
    /**
    */
    this(size_t n) nothrow @safe @nogc
    {
        immutable allocLen = allocateSize(n);

        _array = newCHeapArray!E(allocLen);
        _s = 0;
        _e = n;
    }


    this(this)
    {
        if(_array.ptr !is null){
            immutable n = this.length;

            auto newarr = newCHeapArray!E(allocateSize(n));
            newarr[0 .. n] = _array[_s .. _e];
            _array = newarr;
            _s = 0;
            _e = n;
        }
    }


    ~this()
    {
        if(_array.ptr !is null){
            _array.destroyCHeapArray();
            _s = 0;
            _e = 0;
        }
    }


    /**
    */
    void release()
    {
        _array.destroyCHeapArray();
        _s = 0;
        _e = 0;
    }


    /**
    */
    void clear()
    {
      static if(is(E == struct) && !__traits(isPOD, E))
        foreach(ref e; _array[_s .. _e])
            e = E.init;

        _s = 0;
        _e = 0;
    }


    /**
    */
    size_t capacity() const pure nothrow @safe @nogc @property
    {
        return _array.length - _e;
    }


    /**
    */
    size_t reserve(size_t n)
    {
        if(n > this.length && _array.length < n + _s){
            if(_array.length < n)
                _array.reallocCHeapArray(allocateSize!E(n));

            if(_s != 0){
                foreach(i; 0 .. this.length)
                    _array[i] = _array[_s + i];

                _e -= _s;
                _s = 0;
            }
        }
    }


    bool isNull() const pure nothrow @safe @nogc @property
    {
        return _array is null;
    }


    void opAssign(typeof(null))
    {
        this.release();
    }


    /// array, range primitives
    ref inout(E) front() inout pure nothrow @safe @property @nogc
    {
        return _array[_s];
    }


    /// ditto
    ref inout(E) back() inout pure nothrow @safe @property @nogc
    {
        return _array[_e-1];
    }


    /// ditto
    ref inout(E) opIndex(size_t i) inout pure nothrow @safe @nogc
    {
        return _array[_s + i];
    }


    /// ditto
    bool empty() const pure nothrow @safe @nogc
    {
        return _array.ptr is null || _s == _e;
    }


    /// ditto
    void popFront()
    {
        _array[_s] = E.init;
        ++_s;
    }


    /// ditto
    void popBack()
    {
        _array[_e-1] = E.init;
        --_e;
    }


    /// ditto
    typeof(this) save() @property
    {
        return this;
    }


    /// ditto
    auto dup() const @property
    {
        return this;
    }


    /// ditto
    size_t length() const pure nothrow @safe @nogc @property
    {
        return _e - _s;
    }


    /// ditto
    alias opDollar = length;


    /// ditto
    void length(size_t n) @property
    {
        if(n < this.length){
            static if(is(E == struct) && !__traits(isPOD, E))
                foreach(ref e; _array[_s + n .. _e])
                    e = E.init;
        }else
            reserve(n);

        _e = _s + n;
    }


    /// ditto
    inout(E)[] view() inout pure nothrow @safe @nogc @property
    {
        return _array[_s .. _e];
    }


    /// ditto
    void opOpAssign(string op : "~")(E v)
    {
        this.length = this.length + 1;
        this.back = v;
    }


    /// ditto
    void opOpAssign(string op : "~")(E[] arr)
    {
        immutable oldLen = this.length;
        this.length = oldLen + arr.length;
        this._array[oldLen .. this.length] = arr[0 .. $];
    }


    /// ditto
    void opOpAssign(string op : "~")(typeof(this) src)
    {
        opOpAssign!"~"(src._array[src._s .. src._e]);
    }


    /// ditto
    void opOpAssign(string op : "~", R)(R range)
    if(isInputRange!R && is(ElementType!R : E) && !is(R : U[], U) && !isInfinite!R)
    {
      static if(hasLength!R)
      {
        immutable oldLen = this.length,
                  rangeLen = range.length;
        this.length = oldLen + rangeLen;

        foreach(i; 0 .. rangeLen){
            assert(!range.empty);
            _array[_s + oldLen + i] = range.front;
            range.popFront();
        }
      }
      else
      {
        this = this.dup;

        while(!range.empty){
            immutable remN = this._impl._array.length - _e;

            size_t cnt;
            foreach(i; 0 .. remN){
                if(range.empty)
                    break;

                this._impl._array[_e + i] = range.front;
                ++cnt;
                range.popFront();
            }
            _e += cnt;

            if(cnt == remN && !range.empty)
                reserve(_e + 1);
        }
      }
    }


    /// ditto
    int opCmp(R)(auto ref R r)
    if(isForwardRange!R && is(typeof(r.front < this.front)))
    {
        return std.algorithm.cmp(this.view, r.save);
    }


    /// ditto
    bool opEquals(R)(auto ref R r)
    if(isForwardRange!R && is(typeof(r.front == this.front)))
    {
        return std.algorithm.equal(this.view, r.save);
    }


  private:
    E[] _array;
    size_t _s, _e;
}