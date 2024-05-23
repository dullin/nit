import phase
import astbuilder
import astprinter

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

redef class ASignature
	# Create an array of AVarExpr representing the read of every parameters
	private fun make_parameter_read2(ast_builder: ASTBuilder): Array[AVarExpr]
	do
		var args = new Array[AVarExpr]
		for n_param in self.n_params do
			var mtype = n_param.variable.declared_type
			var variable = n_param.variable
			if variable != null and mtype != null then
                var arg = ast_builder.make_var_read(variable, mtype)
                arg.location = variable.location.as(not null)
				args.push arg
			end
		end
		return args
	end
end

redef class AMethPropdef
    redef fun do_call(visitor: MultiDispatchCallVisitor)
    do 
        visitor.visited_property = self

        if self.mpropdef.mproperty.multim then
            print "AMETHPROP VISIT MULTI"
            if self.mpropdef == self.mpropdef.mproperty.multim_intro then
                print "First multim method! " + self.mpropdef.mproperty.mpropdefs.length.to_s

                # TEST OF ADDING CALLSITE TO OTHER METHOD DEF
                #var mprop = self.mpropdef.mproperty.mpropdefs.last.mproperty
                #var callsite = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), mprop.as(MMethod), false)
                #var call = visitor.ast_builder.make_call(new ASelfExpr, callsite, null)
                #var new_block = new ABlockExpr
                # Add new stuff
                #new_block.n_expr.push call
                
                #replace_with(new_block)


            end
            print self.mpropdef.mproperty.mpropdefs.length
        end

        if self.mpropdef.mclassdef.to_s == "phasing$MyClass" then 
            print "MMM13 - Visiting MethPropdef " + self.mpropdef.mclassdef.to_s + " " + self.mpropdef.name
            #print isset mpropdef.mproperty._multim_intro 
	    if self.mpropdef.name == "toto3X" and 
	    self.mpropdef == self.mpropdef.mproperty.multim_intro 
	    then 
                #self.print_tree
                #print "TREE BEFORE MODIFICATION"
                #self.n_block.print_tree

                var toto2_property = visitor.toolcontext.modelbuilder.try_get_mproperty_by_name(self, self.mpropdef.mclassdef, "toto2")
                var newcallsite = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), toto2_property.as(MMethod), false)
                newcallsite.location = self.location

                # if with isa
                var args = self.n_signature.as(not null).make_parameter_read2(visitor.ast_builder)

                # Make new call site with old args
                var newcall = visitor.ast_builder.make_call(new ASelfExpr, newcallsite, args)
                newcall.location = self.location
                newcall.validate

                #var mclass = visitor.toolcontext.modelbuilder.try_get_mclass_by_name(self, visitor.ast_builder.mmodule, "A")
                var mtype = self.n_signature.param_types[0]
                
                var ma_var = args[0]
                var myIsa = visitor.ast_builder.make_isa(ma_var, mtype)
                var myIf = visitor.ast_builder.make_if(myIsa)
                myIf.n_then.add newcall
                myIf.n_kwelse = new TKwelse
                myIf.n_else = self.n_block

                var new_block = new ABlockExpr
                # Add new stuff
                new_block.n_expr.push newcall
                new_block.location = self.location
                new_block.validate
                
                # Keep existing stuff
                var actual_expr = self.n_block
                if actual_expr isa ABlockExpr then
                    new_block.n_expr.add_all(actual_expr.n_expr)
                else if actual_expr != null then
                    new_block.n_expr.push(actual_expr)
                end

                self.n_block = myIf

                #self.n_block.print_tree
            end
            self.print_tree
        end
    end
end

# TODO : Try to add call before other call

redef class ACallExpr 

    redef fun do_call(visitor: MultiDispatchCallVisitor)
    do
        if callsite != null then
            #print "Sending" + callsite.mproperty.name
            if callsite.mproperty.name == "BADBAD" then
                print "MMM5 - Replacing toto"

                #print "Before"
                #self.parent.print_tree
                #print "Test"
                #print self.n_expr isa AVarExpr
                #var varRead = visitor.ast_builder.make_var(self.n_expr.as(AVarExpr).variable.as(not null), self.n_expr.as(AVarExpr).mtype.as(not null))
                var toto2_property = visitor.toolcontext.modelbuilder.try_get_mproperty_by_name(self, callsite.mpropdef.mclassdef, "toto2")
                var newcallsite = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), toto2_property.as(MMethod), false)
                var newcall = visitor.ast_builder.make_call(self.n_expr, newcallsite, null)

                var varRead = self.n_expr.make_var_read
                var newcallsite2 = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), toto2_property.as(MMethod), false)
                #varRead = visitor.ast_builder.make_var(self.n_expr.as(AVarExpr).variable.as(not null), self.n_expr.as(AVarExpr).mtype.as(not null))
                var newcall2 = visitor.ast_builder.make_call(varRead, callsite.as(not null), null)
                
                var block = visitor.ast_builder.make_block
                
                block.add newcall
                block.add newcall2

                #block.add visitor.ast_builder.make_call(recv, callsite2, null)
                
                #block.add visitor.ast_builder.make_call(recv, callsite, null)
                replace_with(block)
                #print "After - self"
                # Self has no parent after replace
                #self.print_tree
                #print "After - block"
                #block.parent.print_tree
            end
            # Adding signature check
            #if callsite.mproperty.name == "toto3" then do
            if 1 == 2 then
                print("MMM4 - checking signature for toto3")
                #should be the first param of call - self.n_args.n_exprs[0]
                #print(self.n_args.n_exprs[0])
                var mclass = visitor.toolcontext.modelbuilder.try_get_mclass_by_name(self, visitor.ast_builder.mmodule, "A")
                var ma_var = self.n_args.n_exprs[0]
                var myIsa = visitor.ast_builder.make_isa(ma_var, mclass.mclass_type)
                var myIf = visitor.ast_builder.make_if(myIsa)

                # call toto2 if object is A
                var toto2_property = visitor.toolcontext.modelbuilder.try_get_mproperty_by_name(self, callsite.mpropdef.mclassdef, "toto2")
                var newcallsite = visitor.ast_builder.create_callsite(visitor.toolcontext.modelbuilder, visitor.visited_property.as(not null), toto2_property.as(MMethod), false)
                var newcall = visitor.ast_builder.make_call(self.n_expr, newcallsite, null)

                myIf.n_then.add newcall

                # keep call to toto3

                #myIf.print_tree

                replace_with(myIf)
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
            print "MMM14 - THE CLASS"
            for n_propdef in n_propdefs do
                if n_propdef isa AMethPropdef and n_propdef.n_methid != null then do
                    #print n_propdef.n_methid.collect_text
                    #print n_propdef.mpropdef.name
                    if n_propdef.n_signature != null then do
                        #print n_propdef.n_signature.to_s
                    end
                end
            end
        end
    end
end