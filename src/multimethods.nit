import phase
import astbuilder

intrude import modelize_property
intrude import scope
intrude import typing

redef class ToolContext
    var multimethod_phase: Phase = new MultimethodsPhase(self, [modelize_property_phase,typing_phase])
end

private class MultimethodsPhase
    super Phase

    redef fun process_nmodule(nmodule)do
        var visitor = new MultiDispatchCallVisitor(self.toolcontext, new ASTBuilder(nmodule.mmodule.as(not null)))
		visitor.enter_visit(nmodule)
	end

    redef fun process_nclassstddef(nstdclassdef)do
        var visitor = new MultiDispatchClassVisitor(self.toolcontext, new ASTBuilder(nstdclassdef.mclassdef.as(not null).mmodule))
		visitor.enter_visit(nstdclassdef)
	end

end


redef class ANode
    private fun do_call(visitor: MultiDispatchCallVisitor)do end
    private fun do_dispatch(visitor: MultiDispatchClassVisitor)do end
end

### Call site modification

private class MultiDispatchCallVisitor
    super Visitor

    var toolcontext: ToolContext
    var ast_builder: ASTBuilder

    var visited_property: nullable AMethPropdef

    redef fun visit(node)
    do
        node.do_call(self)
        node.visit_all(self)
    end

end


redef class AMethPropdef
    redef fun do_call(visitor: MultiDispatchCallVisitor)do 
        visitor.visited_property = self
    end
end

redef class ASendExpr 

    redef fun do_call(visitor: MultiDispatchCallVisitor)do 
        if callsite != null then do
            #print "Sending" + callsite.mproperty.name
            if callsite.mproperty.name == "toto" then do
                var test2_property = visitor.toolcontext.modelbuilder.try_get_mproperty_by_name(self, callsite.mpropdef.mclassdef, "toto2")
                print "Replacing toto"
                callsite = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), test2_property.as(MMethod), false)
                var block = visitor.ast_builder.make_block
                block.add visitor.ast_builder.make_call(self, callsite.as(not null), null)
                block.add visitor.ast_builder.make_call(self, callsite.as(not null), null)
                replace_with(block)
            end
        end
    end

end

#### Class modification to add dispatch

private class MultiDispatchClassVisitor
    super Visitor

    var toolcontext: ToolContext
    var ast_builder: ASTBuilder

    redef fun visit(node)
    do
        node.do_dispatch(self)
        node.visit_all(self)
    end

end

redef class AStdClassdef 
    redef fun do_dispatch(visitor: MultiDispatchClassVisitor) do
        if mclass.name == "MyClass" then do
            print mclass.name
            for n_propdef in n_propdefs do
                if n_propdef isa AMethPropdef and n_propdef.n_methid != null then do
                    print n_propdef.n_methid.collect_text
                    print n_propdef.mpropdef.name
                    if n_propdef.n_signature != null then do
                        print n_propdef.n_signature.to_s
                    end
                end
            end
        end
    end
end