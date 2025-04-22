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

    redef fun process_nclassdef(nclassdef)do
        if nclassdef isa AStdClassdef then toolcontext.modelbuilder.build_multi_dispatch(nclassdef)
	end

end

private class MPropDefMultiSorter
	super Comparator
	redef type COMPARED: MMethodDef
	var mmodule: MModule


	# Compares the methods definitions by comparing the neting of specialisation
	# if nesting is the same. Looks at each individual parameters and prioritizing
	# the last one.
	redef fun compare(pa, pb)
	do
		var a = pa.msignature.mparameters
		var b = pb.msignature.mparameters
        assert a.length == b.length

        for i in [0..a.length[ do
            var atype = a[i].mtype
            var btype = b[i].mtype
            if atype == btype then
                # Check the next parameter if we have the same one
                continue
            else if atype.is_subtype(mmodule, pa.mclassdef.bound_mtype, btype) then
                return -1
            else
                return 1
            end
        end

        # Shouldn't happen while using it on multimethods
        return 0
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