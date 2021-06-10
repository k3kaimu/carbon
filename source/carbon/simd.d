module carbon.simd;

import std.stdio;
import core.simd;
import carbon.math;
import std.math;

version(D_SIMD):

/**
*/
float dotProduct(in Vector!(float[4])[] a, in Vector!(float[4])[] b) pure nothrow @trusted @nogc
in{
    assert(a.length == b.length);
}
do{
    alias V = Vector!(float[4]);

    V sum;
    sum = 0;

    V* px = cast(V*)(a.ptr),
       ph = cast(V*)(b.ptr),
       qx = cast(V*)(px + a.length);

    while(px != qx)
    {
        sum += *px * *ph;
        ++px;
        ++ph;
    }

    V ones;
    ones.array = [1.0f, 1.0f, 1.0f, 1.0f];
    sum = cast(V)__simd(XMM.DPPS, sum, ones, 0b11111111);
    return sum.array[0];
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    Vector!(float[4])[4] a;
    Vector!(float[4])[4] b;

    float[] as = a[0].ptr[0 .. 16],
            bs = b[0].ptr[0 .. 16];

    float check = 0;
    foreach(i; 0 .. 16){
        as[i] = i;
        bs[i] = i+1;
        check += i * (i+1);
    }

    assert(isClose(check, dotProduct(a, b)));
}


/**
a[0] <- [x.re, x.im, y.re, y.im]
b[0] <- [z.re, z.im, w.re, w.im]

return: sum of (x*z + y*w)
*/
cfloat cpxDotProduct(in Vector!(float[4])[] a, in Vector!(float[4])[] b) pure nothrow @trusted @nogc
in{
    assert(a.length == b.length);
}
do{
    Vector!(float[4]) r, q;
    r = 0;
    q = 0;

    auto px = a.ptr,
         ph = b.ptr,
         qx = a.ptr + a.length;

    while(px != qx)
    {
        Vector!(float[4]) x = *px,
                          h = *ph;
        r += x * h;

        x = cast(Vector!(float[4]))__simd(XMM.SHUFPS, x, x, 0b10_11_00_01);

        q += x * h;

        ++px;
        ++ph;
    }

    Vector!(float[4]) sign, ones;
    sign.array = [1.0f, -1.0f, 1.0f, -1.0f];
    ones.array = [1.0f, 1.0f, 1.0f, 1.0f];

    r = cast(Vector!(float[4]))__simd(XMM.DPPS, r, sign, 0b11111111);
    q = cast(Vector!(float[4]))__simd(XMM.DPPS, q, ones, 0b11111111);

    return r.array[0] + q.array[0]*1i;
}

unittest
{
    scope(failure) {writefln("Unittest failure :%s(%s)", __FILE__, __LINE__); stdout.flush();}
    scope(success) {writefln("Unittest success :%s(%s)", __FILE__, __LINE__); stdout.flush();}

    Vector!(float[4])[4] a;
    Vector!(float[4])[4] b;

    cfloat[] as = (cast(cfloat*)a[0].ptr)[0 .. 8],
            bs = (cast(cfloat*)b[0].ptr)[0 .. 8];

    cfloat check = 0+0i;
    foreach(i; 0 .. 8){
        as[i] = i + (i+1)*1i;
        bs[i] = (i+1) + (i+2)*1i;
        check += as[i] * bs[i];
    }

    cfloat res = cpxDotProduct(a, b);
    assert(isClose(check.re, res.re));
    assert(isClose(check.im, res.im));
}


/**
*/
cfloat cpxDotProduct(FastComplexArray!(float, 4) a, FastComplexArray!(float, 4) b) pure nothrow @trusted @nogc
{
    Vector!(float[4]) pv = 0, qv = 0;
    size_t len = a.length;
    auto a_r_b = a.re.ptr,
         a_r_e = a_r_b + len,
         a_i_b = a.im.ptr,
         a_i_e = a_i_b + len,
         b_r_b = b.re.ptr,
         b_r_e = b_r_b + len,
         b_i_b = b.im.ptr,
         b_i_e = b_i_b + len;

    while(a_r_b != a_r_e){
        pv += (*a_r_b * *b_r_b) - (*a_i_b * *b_i_b);
        qv += (*a_i_b * *b_r_b) + (*a_r_b * *b_i_b);

        ++a_r_b;
        ++a_i_b;
        ++b_r_b;
        ++b_i_b;
    }


    Vector!(float[4]) ones;
    ones.array = [1.0f, 1.0f, 1.0f, 1.0f];

    pv = cast(Vector!(float[4]))__simd(XMM.DPPS, pv, ones, 0b11111111);
    qv = cast(Vector!(float[4]))__simd(XMM.DPPS, qv, ones, 0b11111111);

    return pv.array[0] + qv.array[0]*1i;
}


struct FastComplexArray(E = float, size_t N = 4)
{
    Vector!(E[N])[] re;
    Vector!(E[N])[] im;


    size_t length() const pure nothrow @safe @nogc @property
    {
        return re.length;
    }


    void opOpAssign(string op)(R r)
    if(op == "+" || op == "-")
    {
        iterate!(`*a `~op~`= b;`)(re, r);
    }


    void opOpAssign(string op)(R r)
    if(op == "*" || op == "/")
    {
        iterate!(`*a `~op~`= c; *b `~op~`= c;`)(re, im, r);
    }


    void opOpAssign(string op)(I r)
    if(op == "+" || op == "-")
    {
        iterate!(`*a `~op~`= b;`)(im, r);
    }


    void opOpAssign(string op)(I r)
    if(op == "*" || op == "/")
    {
        swap(re, im);
        iterate!(`*a `~op~`= d; *b `~op~`= c;`)(re, im, r, -r);
    }


    void opOpAssign(string op)(C r)
    if(op == "+" || op == "-")
    {
        iterate!(`*a `~op~`= c; *b `~op~`= d;`)(re, im, r.re, r.im);
    }


    void opOpAssign(string op)(C r)
    if(op == "*")
    {
        iterate!(`auto _temp = *a * c - *b * d; *b = *a * d + *b * c; *a = _temp;`)(re, im, r.re, r.im);
    }
}

/*
import core.bitop;
import std.traits;
import carbon.traits;
enum bool isSIMDArray(T) = is(T : SIMDArray!(E, N), E, size_t N);


struct SIMDArray(E, size_t N)
if(N > 0)
{
    private alias V = core.simd.Vector!(E[N]);


    enum N_log2 = core.bitop.bsr(N);
    alias ElementType = E;

    this(inout(V)[] vec, size_t size) inout
    {
        _arr = vec;
        _size = size;
    }


    this(V[] vec)
    {
        this(vec, vec.length * N);
    }


    this(size_t n)
    {
        immutable oldN = n;

        if(n % N != 0)
            n = n / N + 1;
        else
            n /= N;

        this(new V[n], oldN);
    }


    @property
    inout(ElementType)[] array() inout pure nothrow @nogc { return (cast(E[])_arr)[0 .. _size]; }


    @property
    inout(V)[] opSlice() inout pure nothrow @safe @nogc { return _arr; }

    @property
    inout(typeof(this)) opSlice(size_t i, size_t j) inout pure nothrow @safe @nogc
    in{
        assert(i == 0);
    }
    do {
        return typeof(return)(this._arr, j);
    }


    void opOpAssign(string op)(in SIMDArray!(E, N) rhs)
    if(is(typeof((V a, V b){ mixin(`a` ~ op ~ "=b"); })))
    in {
        assert(this.length == rhs.length);
    }
    do {
        mixin(`_arr[] ` ~ op ~ "= rhs._arr[];");
    }


    @property
    size_t length() const pure nothrow @safe @nogc
    {
        return _size;
    }


    ref ElementType opIndex(size_t i) pure nothrow @safe @nogc
    in {
        assert(i < _size);
    }
    do {
        enum size_t mask = (1 << N_log2) -1;

        return _arr[i >> N_log2].array[i & mask];
    }


    void storeEachResult(alias fn, T...)(in SIMDArray!(E, N) lhs, in SIMDArray!(E, N), rhs, T values)
    if(is(typeof(fn(lhs._arr[0], rhs._arr[0], values))))
    in {
        assert(this.length == lhs.length && this.length == rhs.length);
    }
    do {
        V* plhs = () @trusted { return lhs._arr.ptr; }(),
           prhs = () @trusted { return rhs._arr.ptr; }();

        foreach(i, ref e; _arr){
            e = fn(*plhs, *prhs, values);
            ++plhs; ++prhs;
        }
    }


    void storeEachResult(alias fn)(in SIMDArray!(E, N) arr, T values)
    if(is(typeof(fn(arr._arr[0], values))))
    in {
        assert(this.length == arr.length);
    }
    do {
        V* parr = () @trusted { return arr._arr.ptr; }();

        foreach(i, ref e; _arr){
            e = fn(*parr, values);
            ++parr;
        }
    }


    void storeEachResult(alias fn, T...)(T values)
    if(is(typeof(fn(values))))
    in {

    }
    do {
        foreach(ref e; _arr)
            e = fn(values);
    }


  private:
    V[] _arr;
    size_t _size;
}


alias SSEArray(E) = SIMDArray!(E, 16 / E.sizeof);
alias SSEImaginary(E) = SIMDImaginary!(E, 16 / E.sizeof);
alias SSEComplex(E) = SIMDComplex!(E, 16 / E.sizeof);

alias AVXArray(E) = SIMDArray!(E, 32 / E.sizeof);
alias AVXImaginary(E) = SIMDImaginary!(E, 32 / E.sizeof);
alias AVXComplex(E) = SIMDComplex!(E, 32 / E.sizeof);

alias FastSIMDArray(E) = Select!(is(AVXArray!E), AVXArray!E, SSEArray!E);
alias FastSIMDImaginary(E) = Select!(is(AVXImaginary!E), AVXImaginary!E, SSEImaginary!E);
alias FastSIMDComplex(E) = Select!(is(AVXComplex!E), AVXComplex!E, SSEComplex!E);


struct SIMDImaginary(E, N)
{
    Vector!(E, N) im;

    Vector!(E, N) re() const @property { Vector!(E, N) dst = 0; return dst; }

    void opAssign(SIMDImaginary!(E, N) img) { im = img.im; }
    void opAssign(IMG)(IMG e) if(isBuiltInImaginary!IMG) { im = e/1i; }

    SIMDImaginary opBinary(string op: "+")(SIMDImaginary rhs) const { return SIMDImaginary(im + rhs.im); }
    SIMDImaginary opBinary(string op: "+", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return SIMDImaginary(im + (e*-1i)); }
    SIMDComplex!(E, N) opBinary(string op: "+")(E e) const { Vector!(E, N) re = e; return SIMDComplex!(E, N)(re, im); }
    SIMDComplex!(E, N) opBinary(string op: "+")(Vector!(E, N) e) const { Vector!(E, N) re = e; return SIMDComplex!(E, N)(re, im); }
    SIMDComplex!(E, N) opBinary(string op: "+", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { Vector!(E, N) re = cpx.re; return SIMDComplex!(E, N)(re, im + cpx.im); }
    SIMDComplex!(E, N) opBinary(string op: "+")(Complex!E cpx) const { Vector!(E, N) re = cpx.re; return SIMDComplex!(E, N)(re, im + cpx.im); }
    SIMDComplex!(E, N) opBinary(string op: "+")(SIMDComplex!(E, N) cpx) const { return SIMDComplex!(E, N)(cpx.re, im + cpx.im); }

    SIMDImaginary opBinary(string op: "-")(SIMDImaginary rhs) const { return SIMDImaginary(im - rhs.im); }
    SIMDImaginary opBinary(string op: "-", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return SIMDImaginary(im - e*(-1i)); }
    SIMDComplex!(E, N) opBinary(string op: "-")(E e) const { Vector!(E, N) re = e; return SIMDComplex!(E, N)(re, im); }
    SIMDComplex!(E, N) opBinary(string op: "-")(Vector!(E, N) e) const { Vector!(E, N) re = e; return SIMDComplex!(E, N)(re, im); }
    SIMDComplex!(E, N) opBinary(string op: "-", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { Vector!(E, N) re = cpx.re; return SIMDComplex!(E, N)(re, im - cpx.im); }
    SIMDComplex!(E, N) opBinary(string op: "-")(Complex!E cpx) const { Vector!(E, N) re = cpx.re; return SIMDComplex!(E, N)(re, im - cpx.im); }
    SIMDComplex!(E, N) opBinary(string op: "-")(SIMDComplex!(E, N) cpx) const { return SIMDComplex!(E, N)(cpx.re, im - cpx.im); }

    Vector!(E, N) opBinary(string op: "*")(SIMDImaginary rhs) const { return -(im * rhs.im); }
    Vector!(E, N) opBinary(string op: "*", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return im * (e*1i); }
    SIMDImaginary opBinary(string op: "*")(E e) const { return SIMDImaginary(im * e); }
    SIMDImaginary opBinary(string op: "*")(Vector!(E, N) e) const { return SIMDImaginary(im * e); }
    SIMDComplex!(E, N) opBinary(string op: "*", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { return SIMDComplex!(E, N)(-im * cpx.im, im * cpx.re); }
    SIMDComplex!(E, N) opBinary(string op: "*")(Complex!E cpx) const { return SIMDComplex!(E, N)(-im*cpx.im, im * cpx.re); }
    SIMDComplex!(E, N) opBinary(string op: "*")(SIMDComplex!(E, N) cpx) const { return SIMDComplex!(E, N)(-im * cpx.im, im * cpx.re); }
}


struct SIMDComplex(E, N)
{
    Vector!(E, N) re;
    Vector!(E, N) im;

    void opAssign(SIMDComplex rhs) { re = rhs.re; im = rhs.im; }
    void opAssign(E e) { re = e; im = 0; }
    void opAssign(Vector!(E, N) r) { re = r; im = 0; }
    void opAssign(IMG)(IMG e) if(isBuiltInImaginary!IMG) { re = 0; im = e; }
    void opAssign(SIMDImaginary!(E, N) e) { re = 0; im = e; }
    void opAssign(Complex!E cpx) { re = cpx.re; im = cpx.im; }
    void opAssign(CPX)(CPX cpx) if(isBuiltInComplex!CPX) { re = cpx.re; im = cpx.im; }

    SIMDComplex opBinary(string op: "+")(SIMDComplex rhs) const { return SIMDComplex(re + rhs.re, im + rhs.im); }
    SIMDComplex opBinary(string op: "+")(E e) const { return SIMDComplex(re + e, im); }
    SIMDComplex opBinary(string op: "+")(Vector!(E, N) r) const { return SIMDComplex(re + r, im); }
    SIMDComplex opBinary(string op: "+", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return SIMDComplex(re, im + e/1i); }
    SIMDComplex opBinary(string op: "+")(SIMDImaginary!(E, N) rhs) const { return SIMDComplex(re, im + rhs.im); }
    SIMDComplex opBinary(string op: "+")(Complex!E cpx) const { return SIMDComplex(re + cpx.re, im + cpx.im); }
    SIMDComplex opBinary(string op: "+", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { return SIMDComplex(re + cpx.re, im + cpx.im); }

    SIMDComplex opBinary(string op: "-")(SIMDComplex rhs) const { return SIMDComplex(re - rhs.re, im - rhs.im); }
    SIMDComplex opBinary(string op: "-")(E e) const { return SIMDComplex(re - e, im); }
    SIMDComplex opBinary(string op: "-")(Vector!(E, N) r) const { return SIMDComplex(re - r, im); }
    SIMDComplex opBinary(string op: "-", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return SIMDComplex(re, im - e/1i); }
    SIMDComplex opBinary(string op: "-")(SIMDImaginary!(E, N) rhs) const { return SIMDComplex(re, im - rhs.im); }
    SIMDComplex opBinary(string op: "-")(Complex!E cpx) const { return SIMDComplex(re - cpx.re, im - cpx.im); }
    SIMDComplex opBinary(string op: "-", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { return SIMDComplex(re - cpx.re, im - cpx.im); }

    SIMDComplex opBinary(string op: "*")(SIMDComplex rhs) const { return SIMDComplex(re * rhs.re - im * rhs.im, re * rhs.im + im * rhs.re); }
    SIMDComplex opBinary(string op: "*")(E e) const { return SIMDComplex(re * e, im * e); }
    SIMDComplex opBinary(string op: "*")(Vector!(E, N) r) const { return SIMDComplex(re * r, im * r); }
    SIMDComplex opBinary(string op: "*", IMG)(IMG e) const if(isBuiltInImaginary!IMG) { return SIMDComplex(im * (e*1i), re * (e/1i)); }
    SIMDComplex opBinary(string op: "*")(SIMDImaginary!(E, N) rhs) const { return SIMDComplex(-im * rhs.im, re * rhs.im); }
    SIMDComplex opBinary(string op: "*")(Complex!E cpx) const { return SIMDComplex(re * cpx.re - im * cpx.im, re * cpx.im + im * cpx.re); }
    SIMDComplex opBinary(string op: "*", CPX)(CPX cpx) const if(isBuiltInComplex!CPX) { return SIMDComplex(re * cpx.re - im * cpx.im, re * cpx.im + im * cpx.re); }
}
*/