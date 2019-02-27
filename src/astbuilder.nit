# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Instantiation and transformation of semantic nodes in the AST of expressions and statements
module astbuilder

intrude import semantize::typing
intrude import literal
intrude import parser
intrude import semantize::scope

# General factory to build semantic nodes in the AST of expressions
class ASTBuilder
	# The module used as reference for the building
	# It is used to gather types and other stuff
	var mmodule: MModule

	# The anchor used for some mechanism relying on types
	var anchor: nullable MClassType

	# Make a new Int literal
	fun make_int(value: Int): AIntegerExpr
	do
		return new AIntegerExpr.make(value, mmodule.int_type)
	end

	# Make a new instantiation
	fun make_new(callsite: CallSite, args: nullable Array[AExpr]): ANewExpr
	do
		return new ANewExpr.make(callsite, args)
	end

	# Make a new message send
	fun make_call(recv: AExpr, callsite: CallSite, args: nullable Array[AExpr]): ACallExpr
	do
		return new ACallExpr.make(recv, callsite, args)
	end

	# Make a new, empty, sequence of statements
	fun make_block: ABlockExpr
	do
		return new ABlockExpr.make
	end

	# Make a new, empty, loop of statements
	fun make_loop: ALoopExpr
	do
		return new ALoopExpr.make
	end

	# Make a new variable read
	fun make_var_read(variable: Variable, mtype: MType): AVarExpr
	do
		return new AVarExpr.make(variable, mtype)
	end

	# Make a new variable assignment
	fun make_var_assign(variable: Variable, value: AExpr): AVarAssignExpr
	do
		return new AVarAssignExpr.make(variable, value)
	end

	# Make a new attribute read
	fun make_attr_read(recv: AExpr, attribute: MAttribute): AAttrExpr
	do
		var mtype = attribute.intro.static_mtype.resolve_for(recv.mtype.as(not null), anchor, mmodule, true)
		return new AAttrExpr.make(recv, attribute, mtype)
	end

	# Make a new attribute assignment
	fun make_attr_assign(recv: AExpr, attribute: MAttribute, value: AExpr): AAttrAssignExpr
	do
		return new AAttrAssignExpr.make(recv, attribute, value)
	end

	# Make a new escapable block
	fun make_do: ADoExpr
	do
		return new ADoExpr.make
	end

	# Make a new break for a given escapemark
	fun make_break(escapemark: EscapeMark): ABreakExpr
	do
		return new ABreakExpr.make(escapemark)
	end

	# Make a new conditional
	# `mtype` is the return type of the whole if, in case of a ternary operator.
	fun make_if(condition: AExpr, mtype: nullable MType): AIfExpr
	do
		return new AIfExpr.make(condition, mtype)
	end
end

redef class AExpr
	# Return a new variable read that contains the value of the expression
	# This method take care efficiently of creating and initalising an anonymous local variable
	#
	# Note: since this method do side-effects (AST replacement), there could be unexpected effects when used as
	# argument of other methods related to AST transformations.
	fun make_var_read: AVarExpr
	do
		var variable = self.variable_cache
		if variable == null then
			assert parent != null
			var place = detach_with_placeholder
			variable = new Variable("")
			variable.declared_type = self.mtype
			var nvar = new AVarAssignExpr.make(variable, self)
			place.replace_with(nvar)
			self.variable_cache = variable
		end
		return new AVarExpr.make(variable, variable.declared_type.as(not null))
	end

	private var variable_cache: nullable Variable

	# The `detach` method completely remove the node in the parent.
	# However, sometime, it is useful to keep the emplacement of the removed child.
	#
	# The standard use case is the insertion of a node between a parent `p` and a child `p.c`.
	# To create the new node `n`, we need to attach the child to it.
	# But, to put `n` where `c` was in `p`, the place has to be remembered.
	#
	# ~~~nitish
	# var p: AExpr
	# var c = p.c
	# var h = c.detach_with_placeholder
	# var n = astbuilder.make_XXX(c)
	# h.replace_with(n)
	# ~~~
	fun detach_with_placeholder: AExpr
	do
		var h = new APlaceholderExpr.make
		self.replace_with(h)
		return h
	end


	# Add `expr` at the end of the block
	#
	# REQUIRE: self isa ABlockExpr
	#
	# Note: this method, aimed to `ABlockExpr` is promoted to `AExpr` because of the limitations of the hierarchies generated by sablecc3
	fun add(expr: AExpr)
	do
		print "add not implemented in {inspect}"
		abort
	end

	redef fun accept_ast_validation(v)
	do
		super
		if mtype == null and not is_typed then
			#debug "TYPING: untyped expression"
		end
	end
end

# A placeholder for a `AExpr` node
# Instances are transiantly used to mark some specific emplacements in the AST
# during complex transformations.
#
# Their must not appear in a valid AST
#
# @see AExpr::detach_with_placeholder
class APlaceholderExpr
	super AExpr
	private init make
	do
	end

	redef fun accept_ast_validation(v)
	do
		super
		debug "PARENT: remaining placeholder"
	end
end

redef class ABlockExpr
	private init make
	do
		self.is_typed = true
	end

	redef fun add(expr)
	do
		n_expr.add expr
	end
end

redef class ALoopExpr
	private init make
	do
		_n_kwloop = new TKwloop
		self.is_typed = true
		n_block = new ABlockExpr
		n_block.is_typed = true
	end

	redef fun add(expr)
	do
		n_block.add expr
	end
end

redef class ADoExpr
	private init make
	do
		_n_kwdo = new TKwdo
		self.is_typed = true
		n_block = new ABlockExpr
		n_block.is_typed = true
	end

	# Make a new break expression of the given do
	fun make_break: ABreakExpr
	do
		var escapemark = self.break_mark
		if escapemark == null then
			escapemark = new EscapeMark(null)
			self.break_mark = escapemark
		end
		return new ABreakExpr.make(escapemark)
	end

	redef fun add(expr)
	do
		n_block.add expr
	end
end

redef class ABreakExpr
	private init make(escapemark: EscapeMark)
	do
		_n_kwbreak = new TKwbreak
		self.escapemark = escapemark
		escapemark.escapes.add self
		self.is_typed = true
	end
end

redef class AIfExpr
	private init make(condition: AExpr, mtype: nullable MType)
	do
		_n_kwif = new TKwif
		_n_expr = condition
		_n_expr.parent = self
		_n_kwthen = new TKwthen
		_n_then = new ABlockExpr.make
		_n_kwelse = new TKwelse
		_n_else = new ABlockExpr.make
		self.mtype = mtype
		self.is_typed = true
	end
end

redef class AType
	private init make
	do
		var n_id = new TClassid
		var n_qid = new AQclassid
		n_qid.n_id = n_id
		_n_qid = n_qid
	end
end

redef class AIntegerExpr
	private init make(value: Int, t: MType)
	do
		self.value = value
		self._n_integer = new TInteger # dummy
		self.mtype = t
	end
end

redef class ANewExpr
	private init make(callsite: CallSite, args: nullable Array[AExpr])
	do
		_n_kwnew = new TKwnew
		_n_type = new AType.make
		_n_args = new AListExprs
		if args != null then
			n_args.n_exprs.add_all(args)
		end
		self.callsite = callsite
		self.recvtype = callsite.recv.as(MClassType)
		if callsite.mproperty.is_new then
			self.mtype = callsite.msignature.return_mtype
		else
			self.mtype = callsite.recv
		end
		self.is_typed = true
	end
end

redef class ACallExpr
	private init make(recv: AExpr, callsite: CallSite, args: nullable Array[AExpr])
	do
		self._n_expr = recv
		_n_args = new AListExprs
		_n_qid = new AQid
		_n_qid.n_id = new TId
		if args != null then
			self.n_args.n_exprs.add_all(args)
		end
		self.callsite = callsite
		self.mtype = callsite.msignature.return_mtype
		self.is_typed = true
	end
end

redef class AAttrExpr
	private init make(recv: AExpr, attribute: MAttribute, t: MType)
	do
		_n_expr = recv
		recv.parent = self
		_n_id = new TAttrid
		mproperty = attribute
		mtype = t
	end
end

redef class AAttrAssignExpr
	private init make(recv: AExpr, attribute: MAttribute, value: AExpr)
	do
		_n_expr = recv
		recv.parent = self
		_n_id = new TAttrid
		_n_value = value
		value.parent = self
		_n_assign = new TAssign
		mproperty = attribute
		mtype = value.mtype
	end
end

redef class AVarExpr
	private init make(v: Variable, mtype: MType)
	do
		_n_id = new TId
		variable = v
		self.mtype = mtype
	end
end

redef class AVarAssignExpr
	private init make(v: Variable, value: AExpr)
	do
		_n_id = new TId
		_n_value = value
		value.parent = self
		_n_assign = new TAssign
		variable = v
		mtype = value.mtype
	end
end

# Check the consitency of AST
class ASTValidationVisitor
	super Visitor
	redef fun visit(node)
	do
		node.accept_ast_validation(self)
	end
	private var path = new CircularArray[ANode]
	private var seen = new HashSet[ANode]
end

redef class ANode
	# Recursively validate a AST node.
	# This ensure that location and parenting are defined and coherent.
	#
	# After complex low-level AST manipulation and construction,
	# it is recommended to call it.
	#
	# Note: this just instantiate and run an `ASTValidationVisitor`.
	fun validate
	do
		(new ASTValidationVisitor).enter_visit(self)
	end

	private fun accept_ast_validation(v: ASTValidationVisitor)
	do
		var parent = self.parent
		var path = v.path

		if path.length > 0 then
			var path_parent = v.path.first
			if parent == null then
				self.parent = path_parent
				#debug "PARENT: expected parent: {path_parent}"
				v.seen.add(self)
			else if parent != path_parent then
				self.parent = path_parent
				if v.seen.has(self) then
					debug "DUPLICATE (NOTATREE): already seen node with parent {parent} now with {path_parent}."
				else
					v.seen.add(self)
					debug "PARENT: expected parent: {path_parent}, got {parent}"
				end
			end
		end

		if not isset _location then
			#debug "LOCATION: unlocated node {v.path.join(", ")}"
			_location = self.parent.location
		end

		path.unshift(self)
		visit_all(v)
		path.shift
	end
end

redef class AAnnotation
	redef fun accept_ast_validation(v)
	do
		# Do not enter in annotations
	end
end
