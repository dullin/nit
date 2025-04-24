class A end
class B super A end
class C super B end

class Simple

    fun foo(a:A) do print "A" end
    fun foo(b:B) do print "B" end
    fun foo(c:C) do print "C" end
end

var s = new Simple
print "Start"
s.foo(new A)
s.foo(new B)
s.foo(new C)