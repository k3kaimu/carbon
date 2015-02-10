module graphite.events.eventutils;

import std.algorithm,
       phobosx.signal,  //
       std.variant;


public import phobosx.signal : RestrictedSignal;


struct FiredContext
{
    Variant sender;
    string file;
    size_t line;
    string funcName;
    string prettyFuncName;
}


struct EventManager(T...)
{
    ref RestrictedSignal!(FiredContext, T) signalImpl() @property { return _signalImpl; }
    private Signal!(FiredContext, T) _signalImpl;
    alias signalImpl this;

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


  private:
    void emit()(FiredContext ctx, auto ref T args)
    {
        if(!_disable){
            _signalImpl.emit(ctx, forward!args);
        }
    }


    bool _disable;
}

unittest
{
    auto event = EventManager!bool();

    bool bCalled = false;
    event.strongConnect(delegate(FiredContext ctx, bool b){
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
}


struct SeqEventManager(size_t N, T...)
{
    ref RestrictedSignal!(FiredContext, T) opIndex(size_t i)
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


  private:
    void emit()(FiredContext ctx, auto ref T args)
    {
        if(!_disable){
            foreach(i, ref e; _signals)
                e.emit(ctx, forward!args);
        }
    }


  private:
    Signal!(FiredContext, T)[N] _signals;
    bool _disable;
}

unittest
{
    SeqEventManager!(3, bool) event;

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
