class A end
class B super A end
class C super B end

class Simple

    fun foo(a:A) do print "A" end
    fun foo(b:B) do print "B" end
end

class Double
    super Simple

    redef fun foo(b:B) do print "B2" end
end

var s = new Double
print "Start"
s.foo(new A)
s.foo(new B)

var s2 = new Simple
s2.foo(new A)
s2.foo(new B)