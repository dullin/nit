class A end

class B super A end

class C super B end

class MyClass
    fun toto do 
        print "DEBUG1" 
        print "DEBUG2" 
        print "DEBUG3" 
    end

    fun toto2(a:A, c:Int) do 
        print("DEBUG4")
        print("DEBUG5 - " + c.to_s) 
    end

    fun toto3(a:A, c: Int) do 
        print("DEBUG6")
        print("DEBUG7 - " + c.to_s)
    end

    fun toto3(b:B, c: Int) do 
    	print("DEBUG8-0")
    end


    #fun toto3(b:B, c: Int) do print("DEBUG9 -  " + c.to_s)

end

var obj = new MyClass
obj.toto

print("Next")

var a = new A
var b = new B
print(a isa A)
print("MMM12")
obj.toto3(a, 3)
obj.toto3(b, 4)
