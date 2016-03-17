module bytecurry.rational;

import std.exception : assumeWontThrow;
import std.format;
import std.math : abs;
import std.numeric : gcd;
import std.traits;

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

    /**
     * Return if the rational is infinite. i.e. if the denominator is zero and the numerator
     * is non-zero
     */
    @property bool isInfinity() pure nothrow const {
        return den == 0 && num != 0;
    }

    /**
     * Return if the rational is finite. i.e. if the denominator is non-zero.
     */
    @property bool isFinite() pure nothrow const {
        return den != 0;
    }

    /**
     * Return whether or not the rational is indeterminate (not a number), i.e. both the numerator and
     * denominator are zero.
     */
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
    if ((op == "+" || op == "*") && isIntegral!U)
    {
        return opBinary!(op)(other);
    }

    ///
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "-" && isIntegral!U)
    {
        return Rational(other * den - num, den);
    }

    ///
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "/" && isIntegral!U)
    {
        return Rational(other * den, num);
    }

    // Op-Assign Operators:

    ///
    ref Rational opOpAssign(string op, U: T)(U other) pure nothrow
    if ((op == "+" || op == "-" || op == "*" || op == "/") && is(U: T))
    {
        static if (op == "+") {
            add(other);
        } else static if ( op == "-") {
            sub(other);
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
            sub(other.num, other.den);
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

    /// cast to floating point type
    F opCast(F)() pure nothrow const if (isFloatingPoint!F) {
        return (cast(F) num) / (cast(F) den);
    }

    /// cast to integer type
    I opCast(I)() pure nothrow const if (isIntegral!I) {
        return cast(I) (num / den);
    }

    /**
     * Write the rational to a sink. It supports the same formatting option as integers
     * and outputs the numerator and denominator using those options.
     *
     * If the denominator is on, the / and denominator aren't output.
     * At some point I might make this more sophisticated.
     */
    void toString(Char)(scope void delegate(const(Char)[]) sink, FormatSpec!Char fmt) const {
        if (fmt.spec == '/') {
            if (fmt.flPlus && num > 0) {
                // special formatting for positive numbers
                if (fmt.flPlus) {
                    sink("+");
                }
            }
            auto intSpec = FormatSpec!Char("%d");
            formatValue(sink, num, intSpec);
            if ( fmt.flHash || den != 1) {
                if (fmt.flSpace) {
                    sink(" / ");
                } else {
                    sink("/");
                }
                formatValue(sink, den, intSpec);
            }
        } else {
            formatValue(sink, num, fmt);
            if (den != 1) {
                sink("/");
                formatValue(sink, den, fmt);
            }
        }
     }

    /// convert to string
    string toString() const {
        import std.array : appender;
        auto buf = appender!string();
        auto spec = singleSpec("%s");
        toString((const(char)[] c) { buf.put(c); }, spec);
        //formatValue(buf, this, spec);
        return buf.data;
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

    // needed for proper unsigned arithmetic
    void sub(T otherNum, T otherDen = 1) pure nothrow {
        num = num * otherDen - otherNum * den;
        den = den * otherDen;
    }

    void normalize() pure nothrow {
        if (den < 0) {
            num = - num;
            den = - den;
        }
        T divisor = assumeWontThrow(gcd(num.abs, den));
        if (divisor > 1) {
            num /= divisor;
            den /= divisor;
        }
    }

    invariant {
        assert(den >= 0);
        assert(gcd(num.abs, den) == 1 || (num == 0 && den == 0));
    }

}

// construction and normalization
@safe unittest {
    auto a = rational(1,2);
    assert(a.numerator == 1);
    assert(a.denominator == 2);
    a = rational(10,25);
    assert(a.numerator == 2);
    assert(a.denominator == 5);
}

// comparison
@safe unittest {
    assert(rational(1, 2) == rational(2, 4));
    assert(rational(5,1) == 5);
    assert(rational(2,3) > rational(1,2));
    assert(rational(4,5) < rational(3,2));
    assert(rational(3,2) >= rational(3,2));
    assert(rational(3,2) > 1);
    assert(rational(1,2) < 1);
    assert(rational(4,4) >= 1);
}

//unary operators
@safe unittest {
    assert(-rational(1,2) == rational(-1,2));
    assert(-rational(-1,2) == rational(1,2));
}

// binary operators
@safe unittest {
    assert(rational(1,4) ^^ 0.5 == 0.5);
    assert(1 + rational(3,2) == rational(5,2));
    assert(2 * rational(1,2) == rational(1,1));
    assert(2 - rational(1,2) == rational(3,2));
    assert(3 / rational(2,3) == rational(9,2));

}


// properties
@safe unittest {
    assert(rational(1,0).isInfinity);
    assert(!rational(0,0).isInfinity);
    assert(!rational(0,1).isInfinity);

    assert(!rational(1,0).isFinite);
    assert(!rational(0,0).isFinite);
    assert(rational(0,1).isFinite);

    assert(rational(0,0).isNaN);
    assert(!rational(1,0).isNaN);
    assert(!rational(0,1).isNaN);
}

// toString
unittest {
    import std.stdio;
    writeln(rational(1,2));
    assert(rational(1,2).toString == "1/2");
    assert(rational(5).toString == "5");
}


/**
Create a rational object, with $(D n) as the numerator and $(D d) as the denominator.
 */
Rational!(CommonType!(A,B)) rational(A,B)(A n, B d) if (isIntegral!A && isIntegral!B) {
    alias R = typeof(return);
    return R(n, d);
}

/// ditto
Rational!T rational(T)(T n) if (isIntegral!T) {
    return Rational!T(n, 1);
}

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
