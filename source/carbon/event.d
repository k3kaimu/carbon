module carbon.event;

import std.algorithm,
       std.variant,
       std.traits,
       std.signals;

version(unittest) import std.stdio;

/**

*/
struct FiredContext
{
    Variant sender;
    string file;
    size_t line;
    string funcName;
    string prettyFuncName;
}


/**

*/
interface StrongConnectedSlotTag {}


private
final class SignalImpl(T...)
{
    void connect(string name, Class)(Class obj)
    if(hasMember!(Class, name) && (is(Class == class) || is(Class == interface)))
    {
        MixedInSignal.connect(mixin(`&obj.` ~ name));
    }


    void disconnect(string name, Class)(Class obj)
    if(hasMember!(Class, name) && (is(Class == class) || is(Class == interface)))
    {
        MixedInSignal.disconnect(mixin(`&obj.` ~ name));
    }


    SlotTag strongConnect(Callable)(Callable func)
    if(is(typeof((T args) { func(args); })))
    {
        static final class SlotImpl : SlotTag
        {
            override
            void dg(T args){ _f(args); }

            override
            bool opEquals(Object rhs)
            {
                if(auto o = cast(SlotImpl)rhs)
                    return this._f == o._f;
                else
                    return false;
            }

          private:
            Callable _f;
        }

        auto slot = new SlotImpl;
        slot._f = func;
        _slotSet[slot] = true;

        this.connect!"dg"(slot);
        return slot;
    }


    void disconnect(ref SlotTag tag)
    {
        _slotSet.remove(tag);
        destroy(tag);
        tag = null;
    }


    void strongDisconnect(ref SlotTag tag)
    {
        this.disconnect(tag);
        tag = null;
    }


    void emitImpl(T args)
    {
        MixedInSignal.emit(args);
    }


  private
  {
    mixin Signal!(T) MixedInSignal;
  }


    interface SlotTag : StrongConnectedSlotTag
    {
        void dg(T);
    }

  private:
    bool[SlotTag] _slotSet;
}



/**

*/
final class EventManager(T...)
{
    this()
    {
        _noarg = new SignalImpl!();
        _simple = new SignalImpl!T;
        _withContext = new SignalImpl!(FiredContext, T);
    }


    void disable()
    {
        _disabled = true;
    }


    void enable()
    {
        _disabled = false;
    }


    void connect(string name, Class)(Class obj)
    if(hasMember!(Class, name) && (is(Class == class) || is(Class == interface)))
    {
      static if(is(typeof((FiredContext ctx, T args){ mixin(`obj.` ~ name ~ `(ctx, args);`); })))
        _withContext.connect!name(obj);
      else static if(is(typeof((T args){ mixin(`obj.` ~ name ~ `(args);`); })))
        _simple.connect!name(obj);
      else
        _noarg.connect!name(obj);
    }


    void disconnect(string name, Class)(Class obj)
    if(hasMember!(Class, name) && (is(Class == class) || is(Class == interface)))
    {
      static if(is(typeof((FiredContext ctx, T args){ mixin(`obj.` ~ name ~ `(ctx, args);`); })))
        _withContext.disconnect!name(obj);
      else static if(is(typeof((T args){ mixin(`obj.` ~ name ~ `(args);`); })))
        _simple.disconnect!name(obj);
      else
        _noarg.disconnect!name(obj);
    }


    StrongConnectedSlotTag strongConnect(Callable)(Callable func)
    {
      static if(is(typeof((FiredContext ctx, T args){ func(ctx, args); })))
        return _withContext.strongConnect(func);
      else static if(is(typeof((T args){ func(args); })))
        return _simple.strongConnect(func);
      else
        return _noarg.strongConnect(func);
    }


    void strongDisconnect(ref StrongConnectedSlotTag slotTag)
    {
        if(auto s1 = cast(_withContext.SlotTag)slotTag){
            _withContext.strongDisconnect(s1);
            slotTag = null;
        }
        else if(auto s2 = cast(_simple.SlotTag)slotTag){
            _simple.strongDisconnect(s2);
            slotTag = null;
        }
        else if(auto s3 = cast(_noarg.SlotTag)slotTag){
            _noarg.strongDisconnect(s3);
            slotTag = null;
        }
    }


    void disconnect(ref StrongConnectedSlotTag slotTag)
    {
        this.strongDisconnect(slotTag);
        slotTag = null;
    }


    void emit()(T args, string file = __FILE__, size_t line = __LINE__,
                string func = __FUNCTION__, string preFunc = __PRETTY_FUNCTION__)
    {
        emit(null, args, file, line, func, preFunc);
    }


    void emit(S)(S sender, T args, string file = __FILE__, size_t line = __LINE__,
                                 string func = __FUNCTION__, string preFunc = __PRETTY_FUNCTION__)
    {
        FiredContext ctx;
        ctx.sender = sender;
        ctx.file = file;
        ctx.line = line;
        ctx.funcName = func;
        ctx.prettyFuncName = preFunc;

        emit(ctx, args);
    }


    void emit()(FiredContext ctx, T args)
    {
        if(!_disabled){
            _noarg.emit();
            _simple.emit(args);
            _withContext.emit(ctx, args);
        }
    }


  private:
    bool _disabled;
    SignalImpl!() _noarg;
    SignalImpl!T _simple;
    SignalImpl!(FiredContext, T) _withContext;
}


///
unittest
{
    auto event = new EventManager!int();

    int sum;
    auto tag1 = event.strongConnect((int a){ sum += a; });

    event.emit(12);
    assert(sum == 12);

    auto tag2 = event.strongConnect(() { sum += 2; });

    event.emit(4);
    assert(sum == 18);  // add 2 + 4

    event.disconnect(tag1);
    event.emit(12);
    assert(sum == 20);  // only add 2

    event.disconnect(tag2);
    event.emit(5);
    assert(sum == 20);
}


unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto event = new EventManager!bool();

    bool bCalled = false;
    auto tag = event.strongConnect(delegate(FiredContext ctx, bool b){
        assert(b);
        assert(ctx.sender == null);
        bCalled = true;
    });

    event.emit(true);
    assert(bCalled);

    bCalled = false;
    event.disable();
    event.emit(true);
    assert(!bCalled);

    event.enable();
    event.emit(true);
    assert(bCalled);

    bCalled = false;
    event.disconnect(tag);
    event.emit(true);
    assert(!bCalled);
    assert(tag is null);
}


/**

*/
class SeqEventManager(size_t N, T...)
{
    this()
    {
        foreach(i; 0 .. N)
            _signals[i] = new EventManager!T;
    }


    EventManager!T opIndex(size_t i)
    in{
        assert(i < N);
    }
    body{
        return _signals[i];
    }


    void disable()
    {
        _disable = true;
    }


    void enable()
    {
        _disable = false;
    }


    void emit()(auto ref T args, string file = __FILE__, size_t line = __LINE__,
                                     string func = __FUNCTION__, string preFunc = __PRETTY_FUNCTION__)
    {
        emit(null, forward!args, file, line, func, preFunc);
    }


    void emit(S)(S sender, auto ref T args, string file = __FILE__, size_t line = __LINE__,
                                     string func = __FUNCTION__, string preFunc = __PRETTY_FUNCTION__)
    {
        FiredContext ctx;
        ctx.sender = sender;
        ctx.file = file;
        ctx.line = line;
        ctx.funcName = func;
        ctx.prettyFuncName = preFunc;

        emit(ctx, forward!args);
    }


    void emit()(FiredContext ctx, auto ref T args)
    {
        if(!_disable){
            foreach(i, ref e; _signals)
                e.emit(ctx, forward!args);
        }
    }


  private:
    EventManager!T[N] _signals;
    bool _disable;
}

///
unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    auto event = new SeqEventManager!(3, bool);

    size_t cnt;
    size_t[3] ns;
    event[0].strongConnect(delegate(FiredContext ctx, bool b){
        assert(b);
        assert(ctx.sender == null);
        ns[0] = cnt;
        ++cnt;
    });

    event[1].strongConnect(delegate(FiredContext ctx, bool b){
        assert(b);
        assert(ctx.sender == null);
        ns[1] = cnt;
        ++cnt;
    });

    event[2].strongConnect(delegate(FiredContext ctx, bool b){
        assert(b);
        assert(ctx.sender == null);
        ns[2] = cnt;
        ++cnt;
    });

    event.emit(true);
    assert(cnt == 3);
    assert(ns[] == [0, 1, 2]);
}
