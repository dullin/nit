module multimethods

import phase
import astbuilder
import astprinter

intrude import modelize_property
intrude import scope
intrude import typing

redef class ToolContext
    var multimethod_phase: Phase = new MultimethodsPhase(self, [modelize_property_phase])
end

private class MultimethodsPhase
    super Phase

    redef fun process_nclassdef(nclassdef)do
        #if nclassdef isa AStdClassdef then toolcontext.modelbuilder.build_multi_dispatch(nclassdef)
	end

end

redef class ModelBuilder

    private fun build_multi_dispatch(nclassdef: AStdClassdef)
    do
        var multimethods = new HashSet[MMethodMulti]
        var mclassdef = nclassdef.mclassdef
        var mmodule = mclassdef.mmodule
        var mpropdef_multi_sorter = new MPropDefMultiSorter(mmodule)
        for npropdef in nclassdef.n_propdefs do
            if npropdef isa AMethPropdef then
                var mmethodmulti = npropdef.mpropdef.mproperty.multi_dispatch
                if mmethodmulti != null then
                    multimethods.add(mmethodmulti)
                    print "MMM13 - Found a multi method variant length : {multimethods.length}"
                end
            end
        end

        for multimethod in multimethods do
            var dispatchdef = multimethod.lookup_first_definition(mmodule, mclassdef.bound_mtype)
            assert dispatchdef isa MMethodMultiDef
            for multiprop in multimethod.multimethods do
                var multipropdef = multiprop.lookup_first_definition(mmodule, mclassdef.bound_mtype)
                dispatchdef.multimethoddefs.add(multipropdef)
            end
            mpropdef_multi_sorter.sort(dispatchdef.multimethoddefs)
            for mpropdef in dispatchdef.multimethoddefs do
					toolcontext.modelbuilder.toolcontext.info("MMM14 Method name sorted : {mpropdef.mproperty.c_name}", 4)
			end
        end
    end
end