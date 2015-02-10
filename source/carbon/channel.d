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
このモジュールでは、$(D_CODE std.concurrency)とは違うスレッド間通信を提供します。

このモジュールで提供するスレッド間通信は指定した型のみを送受信できるようなものです。
送受信ともに非同期に行われます。
*/
module carbon.channel;

import carbon.templates;

import std.typetuple;

import lock_free.dlist;


/**
スレッド間通信を提供します。
たとえば、スレッド間でデータを転送する場合に使用します。
*/
shared struct Channel(T...)
{
    static shared(Channel!T) opCall()
    {
        typeof(return) dst;
        foreach(i, E; T)
            dst._chs[i] = new shared AtomicDList!E();

        return dst;
    }


    shared(Sender) sender() @property
    {
        return shared(Sender)(this);
    }


    shared(Receiver) reciever() @property
    {
        return shared(Receiver)(this);
    }


    static shared struct Sender
    {
        void put(U)(U v)
        if(is(U : shared(U)) && isOneOfT!(CastOffShared!U, T))
        {
            _ch.put(v);
        }


      private:
        shared(Channel!T) _ch;
    }


    static shared struct Receiver
    {
        shared(U)* pop(U)() @property
        if(isOneOfT!(U, T))
        {
            return _ch.pop!U;
        }


        shared(AtomicDList!U) queue(U)() @property
        if(isOneOfT!(U, T))
        {
            return _ch.queue!U;
        }

      private:
        shared(Channel!T) _ch;
    }


    void put(U)(U v)
    if(is(U : shared(U)) && isOneOfT!(CastOffShared!U, T))
    {
        foreach(i, E; T){
          static if(is(U == E))
            _chs[i].pushBack(v);
        }
    }


    shared(U)* pop(U)() @property
    if(isOneOfT!(U, T))
    {
        foreach(i, E; T){
          static if(is(U == E))
            return _chs[i].popFront();
        }

        assert(0);
    }


    shared(AtomicDList!U) queue(U)() @property
    if(isOneOfT!(U, T))
    {
        foreach(i, E; T){
          static if(is(U == E))
            return _chs[i];
        }

        assert(0);
    }


  private:
    AtomicDLists _chs;

    alias AtomicDLists = ToTuple!(TRMap!(AtomicDList, ToTRange!T));

    template isOneOfT(A, T...){
      static if(T.length == 0)
        enum bool isOneOfT = false;
      else
        enum bool isOneOfT = is(A == T[0]) || isOneOfT!(A, T[1 .. $]);
    }


    template CastOffShared(T)
    {
      static if(is(T == shared(U), U))
        alias CastOffShared = U;
      else
        alias CastOffShared = T;
    }
}


shared struct NChannel(size_t N, T...)
{
    static shared(NChannel!(N, T)) opCall()
    {
        typeof(return) dst;

        foreach(i, E; T){
            foreach(j; 0 .. N)
                _chs[i][j] = new shared AtomicDList!E;
        }

        return dst;
    }


    shared(Node!i) node(size_t i)() @property
    {
        return shared(Node!i)(this);
    }


    static shared struct Node(size_t i)
    if(i < N)
    {
        void put(size_t j, U)(U v)
        if(is(U : shared(U)) && isOneOfT!(CastOffShared!U, T) && i != j)
        {
            _ch.put!j(v);
        }


        shared(U)* pop(U)() @property
        if(isOneOfT!(U, T))
        {
            return _ch.pop!i();
        }


        shared(AtomicDList!U) queue(U)() @property
        if(isOneOfT!(U, T))
        {
            return _ch.queue!(i, U)();
        }


      private:
        shared(NChannel!(N, T)) _ch;
    }


    void put(size_t i, U)(U v)
    if(is(U : shared(U)) && isOneOfT!(CastOffShared!U, T) && isOneOfT!(U, T))
    {
        foreach(j, E; T){
          static if(is(U == E))
            _chs[j][i].pushBack(v);
        }
    }


    shared(U)* pop(size_t i, U)(shared U v)
    if(isOneOfT!(U, T))
    {
        foreach(j, E; T){
          static if(is(U == E))
            return _chs[j][i].popFront();
        }
        assert(0);
    }


    shared(AtomicDList!U) queue(size_t i, U)() @property
    if(isOneOfT!(U, T))
    {
        foreach(j, E; T){
          static if(is(U == E))
            return _chs[j][i];
        }
    }

  private:
    AtomicDLists _chs;

    alias AtomicDListN(T) = AtomicDList!T[N];
    alias AtomicDLists = ToTuple!(TRMap!(AtomicDListN, ToTRange!T));

    alias isOneOfT = Channel!(int).isOneOfT;
}


/**
*/
shared(Channel!T) channel(T...)() @property
{
    return shared(Channel!T)();
}


///
shared(NChannel!(N, T)) nchannel(size_t N, T...)() @property
{
    return shared(NChannel!(N, T))();
}

///
unittest{
    import std.concurrency;
    import std.conv;

    auto ch1 = channel!(int, long, string);
    auto ch2 = channel!(int, long, string);

    static void spawnFuncSender(shared ch1.Sender s)
    {
        foreach(i; 0 .. 100){
            s.put(cast(int)i);
            s.put(i + (long.max >> 1) + 1);
            s.put(to!string(i));
        }
    }


    static void spawnFuncMiddle(shared ch1.Receiver r,
                                shared ch2.Sender s)
    {
        foreach(i; 0 .. 100){
            foreach(E; TypeTuple!(int, long, string))
            {
                while(r.queue!E.empty){}
                s.put!E(*r.pop!E);
            }
        }
    }

    spawn(&spawnFuncSender, ch1.sender);
    spawn(&spawnFuncMiddle, ch1.reciever,
                            ch2.sender);

    foreach(i; 0 .. 100){
        foreach(E; TypeTuple!(int, long, string))
        {
            while(ch2.queue!E.empty){}

          static if(is(E == int))
            assert(*ch2.pop!E == i);
          else static if(is(E == long))
            assert(*ch2.pop!E == i + (long.max >> 1) + 1);
          else
            assert(*ch2.pop!E == i.to!string);
        }
    }
}
