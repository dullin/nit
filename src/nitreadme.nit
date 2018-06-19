# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module nitreadme

import code_index
import frontend
import frontend::parse_examples
import commands::commands_docdown
import commands::commands_md
import console

redef class ToolContext

	var nitreadme_phase: Phase = new NitReadmePhase(self, null)

	var opt_check_readme = new OptionBool("Check README.md files", "--check-readme")

	redef init do
		super
		option_context.add_option(opt_check_readme)
	end
end

private class NitReadmePhase
	super Phase

	redef fun process_mainmodule(mainmodule, mmodules) do
		var mbuilder = toolcontext.modelbuilder
		var model = mbuilder.model

		# prepare markdown parser
		var cmd_parser = new CommandParser(model, mmodules.first, mbuilder)
		var md_parser = new MdParser
		md_parser.github_mode = true
		md_parser.wikilinks_mode = true
		md_parser.post_processors.add new MDocProcessSynopsis
		md_parser.post_processors.add new MDocProcessCodes
		md_parser.post_processors.add new MDocProcessCommands(cmd_parser, toolcontext)
		md_parser.post_processors.add new MDocProcessSummary
		model.mdoc_parser = md_parser

		# create index
		var index = new ExamplesIndex(mbuilder)
		index.index_model(model)

		var mpackages = extract_mpackages(mmodules)
		for mpackage in mpackages do

			# Fictive and buggy packages are ignored
			if not mpackage.has_source then
				toolcontext.warning(mpackage.location, "no-source",
					"Warning: `{mpackage}` has no source file")
				continue
			end

			if not mpackage.has_readme then
				# toolcontext.warning(mpackage.location, "no-readme",
					# "Warning: `{mpackage}` has no `README.md` file")
				continue
			end

			suggest_examples_replacement(index, mpackage)
		end
	end

	# Extract the list of packages from the mmodules passed as arguments
	fun extract_mpackages(mmodules: Collection[MModule]): Collection[MPackage] do
		var mpackages = new ArraySet[MPackage]
		for mmodule in mmodules do
			var mpackage = mmodule.mpackage
			if mpackage == null then continue
			mpackages.add mpackage
		end
		return mpackages.to_a
	end

	fun suggest_examples_replacement(index: ExamplesIndex, mpackage: MPackage) do
		var suggester = new ExampleSuggest(toolcontext, index)

		var mdoc = mpackage.mdoc_or_fallback
		if mdoc == null then
			print "no mdoc"
			return
		end
		suggester.match_mdoc(mdoc)

# TODO already use examples
# TODO best match at best place
# TODO replace node


	end
end

class ExamplesIndex
	super CodeIndex

	fun index_model(model: Model) do
		for mmodule in model.mmodules do
			if not mmodule.is_example then continue
			index_mentity(mmodule)
		end
		# update_index
	end
end

class MdCodeVisitor
	super MdVisitor

	var code_blocks = new Array[MdCodeBlock]

	redef fun visit(node) do
		if node isa MdCodeBlock then
			var info = node.info
			if info == null or info == "nit" then
				code_blocks.add node
			end
		end
		node.visit_all(self)
	end
end

class ExampleSuggest

	var toolcontext: ToolContext
	var code_index: ExamplesIndex

	fun match_mdoc(mdoc: MDoc) do
		var blocks = parse_mdoc(mdoc)
		var i = 0
		for block in blocks do
			i += 1

			var code = block.literal
			if code == null or code.is_empty then continue

			var node = parse_code(code)
			if node == null then continue

			var examples = match_examples(node)
			print_suggestions(code, examples)
		end
		if i > 0 then
			print "{mdoc.original_mentity or else "NULL"}: {i} blocks of code"
		end
	end

	fun parse_mdoc(mdoc: MDoc): Array[MdCodeBlock] do
		var ast = mdoc.mdoc_document
		var v = new MdCodeVisitor
		v.enter_visit(ast)
		return v.code_blocks
	end

	fun parse_code(code: String): nullable ANode do
		var node = toolcontext.parse_something(code)
		if not node isa AModule then
			# print "no AModule"
			return null
		end

		var mbuilder = toolcontext.modelbuilder
		mbuilder.load_rt_module(null, node, "tmp")
		mbuilder.run_phases
		return node
	end

	fun match_examples(node: ANode): Array[vsm::IndexMatch[CodeDocument]] do
		return code_index.find_node(node)
	end

	fun print_suggestions(code: String, results: Array[vsm::IndexMatch[CodeDocument]]) do
		# var mbuilder = toolcontext.modelbuilder
		# var model = mbuilder.model
		var i = 0

		# print "\n\n# For code block #{i}:\n".bold.blue
		# print code.blue
		# print ""

		for match in results do
			# print match
			# print match.document.tfidf
			if i >= 3 then break
			# var mentity = model.mentity_by_full_name(doc.document.title).as(not null)
			# var mentity = match.document.mentity
			# print "## {mentity.full_name} ({match.similarity})".bold.green
			# var cmd = new CmdEntityCode(model, mbuilder, mentity = mentity)
			# cmd.init_command
			# print cmd.to_md.write_to_string.light_gray
			# print ""
			i += 1
		end
	end
end

# build toolcontext
var toolcontext = new ToolContext
var tpl = new Template
tpl.add "Usage: nitreadme [OPTION]... <file.nit>...\n"
tpl.add "Helpful features about README files."
toolcontext.tooldescription = tpl.write_to_string

# process options
toolcontext.process_options(args)
var arguments = toolcontext.option_context.rest

# build model
var model = new Model
var mbuilder = new ModelBuilder(model, toolcontext)
var mmodules = mbuilder.parse_full(arguments)

# process
if mmodules.is_empty then return
mbuilder.run_phases
toolcontext.run_global_phases(mmodules)

# TODO
# replace code
# add examples
# add links
# add doc
# add features
# add uml

# TOC
# prev/next
# reorder sections

