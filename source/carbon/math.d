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
このモジュールは、標準ライブラリstd.mathの拡張です。
*/
module carbon.math;

import std.math;
import std.traits;


real toDeg(real rad) pure nothrow @safe
{
    return rad / PI * 180;
}


real toRad(real deg) pure nothrow @safe
{
    return deg / 180 * PI;
}


bool isPowOf2(I)(I n)
if(is(typeof(n && (n & (n-1)) == 0 )))
{
    return n && (n & (n-1)) == 0;
}

unittest{
    assert(!0.isPowOf2);
    assert( 1.isPowOf2);
    assert( 2.isPowOf2);
    assert( 4.isPowOf2);
    assert(!6.isPowOf2);
    assert( 8.isPowOf2);
    assert(!9.isPowOf2);
    assert(!10.isPowOf2);
}
