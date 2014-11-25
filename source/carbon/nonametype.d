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
このモジュールではstd.typecons.Tupleとは違った無名型を構築します。
*/
module carbon.nonametype;


auto refT(alias var)()
{
    static struct RefT
    {
        auto ref get() pure nothrow @safe @nogc @property { return a; }
        alias get this;
    }

    return RefT();
}


auto refP(T)(T* p)
{
    static struct RefP
    {
        auto ref get() pure nothrow @safe @nogc inout @property { return *_p; }
        alias get this;
        private T* _p;
    }

    return RefP(p);
}
