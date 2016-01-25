module carbon.actor;

import core.thread;
import core.atomic;

import std.concurrency;
import std.traits;

import carbon.traits;


/**
Actorが有するイベントハンドラを示すためのUDAです．
*/
enum ThreadEvent;


struct ThreadEventMethod(Params...)
{
    alias Parameters = Params;
    string identifier;
}


/**
Tがもつ，すべてのActorイベントハンドラをThreadEventMethod型にして返します．
*/
template ThreadEventMethods(T)
{
    import std.meta : AliasSeq;
    import std.traits : Parameters;

    template ThreadEventMethodsImpl(Members...)
    {
      static if(Members.length == 0)
        alias ThreadEventMethodsImpl = AliasSeq!();
      else
      {
        mixin(`alias method = T.` ~ Members[0] ~ ";");

        static if(hasUDA!(method, ThreadEvent))
          alias ThreadEventMethodsImpl = AliasSeq!(ThreadEventMethod!(Parameters!method)(Members[0]), ThreadEventMethodsImpl!(Members[1 .. $]));
        else
          alias ThreadEventMethodsImpl = ThreadEventMethodsImpl!(Members[1 .. $]);
      }
    }

    alias ThreadEventMethods = ThreadEventMethodsImpl!(__traits(allMembers, T));
}

///
unittest
{
    static struct TestActor1 { @ThreadEvent void foo(string) {} }

    static assert(ThreadEventMethods!TestActor1.length == 1);
    static assert(ThreadEventMethods!TestActor1[0].identifier == "foo");
    static assert(is(ThreadEventMethods!TestActor1[0].Parameters[0] == string));


    static struct TestActor2 { void foo(string) {} }

    static assert(ThreadEventMethods!TestActor2.length == 0);


    static struct TestActor3
    {
        @ThreadEvent
        void foo() {}

        @ThreadEvent
        void bar(string) {}

        void hoge(int) {}
    }


    static assert(ThreadEventMethods!TestActor3.length == 2);
}


/**
型Tがアクターかどうかチェックします．
*/
enum bool isActor(T) = (ThreadEventMethods!T.length > 0) && 
is(typeof((T t){
    if(t.isEnd) {}
}));


/**
型Tが，onUpdateを持つアクターかどうかチェックします．
*/
enum bool isIncessantActor(T) = isActor!T && is(typeof((T t){
    Duration dur = t.maxInterval;
    t.onUpdate();
}));


/**
型Tが，onResurrectionを持つアクターかどうかチェックします．
*/
enum bool isPhoenixActor(T) = isActor!T && is(typeof((T t){
    Exception ex;
    t.onResurrection(ex);

    Error err;
    t.onResurrection(err);
}));


private
struct ActorEventMedia(string identifier, Params...)
{
    Params values;
}


/**
runActorおよびrunPhoenixActorの返り値です．
*/
struct ActorConnection(A)
if(isActor!A)
{
    mixin(generateMethods);

    bool isDestroyed() const @property { return atomicLoad(*_isDestroyed); }

  private:
    Tid _tid;
    shared(bool)* _isDestroyed;

  static:
    string generateMethods()
    {
        import std.array;
        import std.format;

        auto app = appender!string;

        foreach(m; ThreadEventMethods!A)
            app.formattedWrite(q{
                void %1$s(Parameters!(A.%1$s) params)
                {
                    ActorEventMedia!("%1$s", Parameters!(A.%1$s)) media;
                    media.values = params;
                    _tid.send(media);
                }
            }, m.identifier);

        return app.data;
    }
}


/**
アクターAを別スレッドで起動し，ActorConnectionを返します．
*/
ActorConnection!A runActor(A, Params...)(Params params)
{
    shared(bool)* destroyedFlag = new shared bool;
    return ActorConnection!A(spawn(&(runActorImpl!(A, Params)), destroyedFlag, params), destroyedFlag);
}


///
unittest
{
    import core.atomic;
    // write a test of runActor

    static
    final synchronized class SharedCounter
    {
        this() {}

        int count;

        void inc() { atomicOp!"+="(count, 1); }
        int value() { return count; }
    }


    static struct TestActor
    {
        this(shared(SharedCounter) counter) { this.counter = counter; }

        @ThreadEvent void inc() { counter.inc(); }
        bool isEnd() { return counter.value > 2; }

        shared(SharedCounter) counter;
    }

    auto scnt = new shared SharedCounter();
    auto con = runActor!TestActor(scnt);
    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt.value == 1);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt.value == 2);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt.value == 3);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt.value == 3);
}


//
private
void runActorImpl(A, Params...)(shared(bool)* destroyedFlag, Params params)
if(isActor!A)
{
    scope(exit)
        atomicStore(*destroyedFlag, true);

  static if(is(A == class))
    A obj = new A(params);
  else static if(is(A == struct))
    A obj = A(params);
  else static assert(0);

  static if(isIncessantActor!A)
  {
    immutable Duration timeoutDur = obj.maxInterval;

    while(!obj.isEnd)
    {
        mixin(`receiveTimeout(timeoutDur, ` ~ generateActorHandles!A() ~ `);`);
        t.onUpdate();
    }
  }
  else
  {
    while(!obj.isEnd)
    {
        mixin(`receive(` ~ generateActorHandles!A() ~ `);`);
    }
  }


  static if(is(typeof((){ obj.onDestroy(); })))
    obj.onDestroy();
}


/**
runActorと同様に，アクターAを別スレッドで起動しますが，Aで例外が飛んだ場合，ただちに復帰します．
*/
ActorConnection!A runPhoenixActor(A, Params...)(Params params)
{
    shared(bool)* destroyedFlag = new shared bool;
    return ActorConnection!A(spawn(&(runPhoenixActorImpl!(A, Params)), destroyedFlag, params), destroyedFlag);
}


///
unittest
{
    import core.atomic;
    // write a test of runActor

    static
    final synchronized class SharedCounter
    {
        this() {}

        int count;

        void inc() { atomicOp!"+="(count, 1); }
        int value() { return count; }
    }


    static struct TestActor
    {
        import std.exception;

        this(shared(SharedCounter) c1, shared(SharedCounter) c2) { this.c1 = c1; this.c2 = c2; }

        @ThreadEvent void inc() { c1.inc(); enforce(false); }
        bool isEnd() { return c1.value > 2; }
        void onResurrection(Throwable) { c2.inc(); }

        shared(SharedCounter) c1, c2;
    }

    auto scnt1 = new shared SharedCounter(),
         scnt2 = new shared SharedCounter();
    auto con = runPhoenixActor!TestActor(scnt1, scnt2);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt1.value == 1);
    assert(scnt2.value == 1);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt1.value == 2);
    assert(scnt2.value == 2);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt1.value == 3);
    assert(scnt2.value == 3);

    con.inc();
    Thread.sleep(dur!"msecs"(100));
    assert(scnt1.value == 3);
    assert(scnt2.value > 0);
}



//
private
void runPhoenixActorImpl(A, Params...)(shared(bool)* destroyedFlag, Params params)
if(isPhoenixActor!A)
{
    scope(exit)
        atomicStore(*destroyedFlag, true);

  static if(is(A == class))
    A obj = new A(params);
  else static if(is(A == struct))
    A obj = A(params);
  else static assert(0);

  static if(isIncessantActor!A)
  {
    immutable Duration timeoutDur = obj.maxInterval;

    while(1)
    {
        try{
            if(obj.isEnd) break;

            mixin(`receiveTimeout(timeoutDur, ` ~ generateActorHandles!A() ~ `);`);
            obj.onUpdate();
        }
        catch(Error err) obj.onResurrection(err);
        catch(Exception err) obj.onResurrection(err);
    }
  }
  else
  {
    while(1)
    {
        try{
            if(obj.isEnd) break;

            mixin(`receive(` ~ generateActorHandles!A() ~ `);`);
        }
        catch(Error err) obj.onResurrection(err);
        catch(Exception err) obj.onResurrection(err);
    }
  }

  static if(is(typeof((){ obj.onDestroy(); })))
    obj.onDestroy();
}


private
string generateActorHandles(A)()
{
    import std.array;
    import std.format;

    auto app = appender!string;

    foreach(m; ThreadEventMethods!A)
        app.formattedWrite(q{(ActorEventMedia!("%1$s", Parameters!(A.%1$s)) params) { obj.%1$s(params.values); },}, m.identifier);

    return app.data;
}
