class A end
class B super A end
class C super B end

class Simple

    fun foo(a:A) do end
    fun foo(b:B) do end
    fun foo(c:C) do end
end

var s = new Simple
s.foo(new A)