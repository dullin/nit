import multi_file1

class Double
    super Simple

    fun foo(b:B) do print "B" end
    fun foo(c:C) do print "C" end
end

var s = new Double
print "Start"
s.foo(new A)
s.foo(new B)
s.foo(new C)

var s2 = new Simple
print "Start2"
s2.foo(new A)
s2.foo(new B)
s2.foo(new C)