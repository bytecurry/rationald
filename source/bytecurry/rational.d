module bytecurry.rational;

import std.traits;
import std.format: format;

///
unittest {
    auto a = rational(6,10);
    assert(a.numerator == 3);
    assert(a.denominator == 5);

    assert(a == rational(3,5));
    assert(a * 2 == rational(6,5));
    assert(a / 2 == rational(3,10));

    assert(a + rational(1,10) == rational(7,10));

}


/**
 * A struct to accurately represent rational numbers (including fractions).
 */
struct Rational(T) if (isIntegral!T) {
private:
    /// Numerator
    T num;
    /// Denominator
    T den;

public:
    this(N: T, D: T)(N n, D d) pure nothrow {
        num = n;
        den = d;
        normalize();
    }

    this(I: T)(I n) pure nothrow {
        num = n;
        den = 1;
    }

    this(U: T)(const Rational!U other) pure nothrow {
        opAssign(other);
    }

    @property T numerator() pure nothrow const {
        return num;
    }
    @property T denominator() pure nothrow const {
        return den;
    }
    @property bool isInfinite() pure nothrow const {
        return den == 0 && num != 0;
    }
    @property bool isNaN() pure nothrow const {
        return den == 0 && num == 0;
    }

    // Assignment Operators:

    ///
    ref Rational opAssign(U: T)(Rational!U other) pure nothrow @nogc {
        num = other.num;
        den = other.den;
        return this;
    }

    ///
    ref Rational opAssign(I: T)(I other) pure nothrow @nogc {
        num = other;
        den = 1;
        return this;
    }

    // Comparison Operators:

    ///
    bool opEquals(U: T)(Rational!U other) pure nothrow const {
        return num == other.num && den == other.den;
    }

    ///
    bool opEquals(I: T)(I other) pure nothrow const {
        return num == other && den == 1;
    }

    ///
    int opCmp(U: T)(Rational!U other) pure nothrow const {
        return num * other.den - other.num * den;
    }

    ///
    int opCmp(I: T)(I other) pure nothrow const @nogc {
        return num - other* den;
    }

    // Unary Operators:

    ///
    Rational opUnary(string op)() const pure nothrow if (op == "+") {
        return this;
    }

    ///
    Rational opUnary(string op)() const pure nothrow if (op == "-") {
        return Rational(-num, den);
    }

    // Binary Operators:

    ///
    Rational!(CommonType!(T,U)) opBinary(string op, U)(Rational!U other) const pure nothrow {
        alias R = typeof(return);
        auto ret = R(num, den);
        return ret.opOpAssign!(op)(other);
    }

    ///
    Rational!(CommonType!(T,U)) opBinary(string op, U)(U other) const pure nothrow if (isIntegral!U) {
        alias R = typeof(return);
        auto ret = R(num, den);
        return ret.opOpAssign!(op)(other);
    }

    ///
    F opBinary(string op, F)(F other) const pure nothrow
        if (op == "^^" && isFloatingPoint!F)
    {
        return (cast(F) this) ^^ other;
    }

    // int + rational, and int * rational
    ///
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "+" || op == "*")
    {
        return opBinary!(op)(other);
    }

    ///
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "-")
    {
        return Rational(other * den - num, den);
    }

    ///
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "/")
    {
        return Rational(num, other * den);
    }


    // Op-Assign Operators:

    ///
    ref Rational opOpAssign(string op, U)(U other) pure nothrow
    if ((op == "+" || op == "-" || op == "*" || op == "/") && is(U: T))
    {
        static if (op == "+") {
            add(other);
        } else static if ( op == "-") {
            add(-other);
        } else static if (op == "*") {
            multiply(other);
        } else static if (op == "/") {
            multiply(1, other);
        }
        return this;
    }

    ///
    ref Rational opOpAssign(string op, U: T)(Rational!U other) pure nothrow
    if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        static if (op == "+") {
            add(other.num, other.den);
        } else static if (op == "-") {
            add(-other.num, other.den);
        } else static if (op == "*") {
            multiply(other.num, other.den);
        } else static if (op == "/") {
            multiply(other.den, other.num);
        }
        return this;
    }

    ///
    ref Rational opOpAssign(string op, U)(U exp) pure nothrow if (op == "^^" && isIntegral!U) {
        num ^^= exp;
        den ^^= exp;
        normalize();
        return this;
    }

    // Cast Operators:

    ///
    F opCast(F)() pure nothrow const if (isFloatingPoint!F) {
        return (cast(F) num) / (cast(F) den);
    }

    ///
    I opCast(I)() pure nothrow const if (isIntegral!I) {
        return cast(I) (num / den);
    }

    ///
    string toString() pure const {
        if (den == 1) {
            return format("%d", num);
        } else {
            return format("%d/%d", num, den);
        }
    }

    unittest {
        assert(rational(1,2).toString == "1/2");
        assert(rational(5).toString == "5");
    }

private:
    void multiply(T otherNum, T otherDen = 1) pure nothrow {
        num *= otherNum;
        den *= otherDen;
        normalize();
    }

    void add(T otherNum, T otherDen = 1) pure nothrow {
        num = num * otherDen + otherNum * den;
        den = den * otherDen;
        normalize();
    }

    void normalize() pure nothrow {
        T divisor = gcd(num, den);
        if (divisor > 1) {
            num /= divisor;
            den /= divisor;
        }
        if (den < 0) {
            num = - num;
            den = - den;
        }
    }

}

Rational!(CommonType!(A,B)) rational(A,B)(A a, B b) if (isIntegral!A && isIntegral!B) {
    alias R = typeof(return);
    return R(a, b);
}

Rational!T rational(T)(T n) if (isIntegral!T) {
    return Rational!T(n, 1);
}

T gcd(T)(T a, T b) pure nothrow if (isIntegral!(T)){
    T temp;
    while (b != 0) {
        temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}
