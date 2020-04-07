module multidispatch

import astbuilder
import parse_annotations
import phase
import semantize
intrude import modelize_property
intrude import scope
intrude import typing

redef class ToolContext
	# Parses  annotations.
	var multi_disptach_phase: Phase = new MultiDispatchPhase(self, [modelize_property_phase,typing_phase])
end

private class MultiDispatchPhase
	super Phase

	# The entry point of the multiple dispatch phase
	# In reality, the multiple dispatch phase is executed on each module
	redef fun process_nclassdef(nclassdef)do
		nclassdef.do_dispatch(self.toolcontext)
	end
end

redef class AClassdef

    fun do_dispatch(toolcontext: ToolContext) do
        var multi_dispatch_visitor = new MultiDispatchVisitor(toolcontext, toolcontext.modelbuilder.identified_modules.first, self, new ASTBuilder(mmodule.as(not null)))
        multi_dispatch_visitor.enter_visit(self)
    end
end

private class MultiDispatchVisitor
    super Visitor

    var toolcontext: ToolContext
    var mainmodule: MModule
    var visited_class : AClassdef
    var ast_builder: ASTBuilder

    redef fun visit(node)
    do
        print self.visited_class.n_propdefs.count
        node.visit_all(self)
        
    end

end