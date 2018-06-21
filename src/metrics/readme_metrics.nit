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

# Collect common metrics about README files
#
# Also works with generic Markdown files.
module readme_metrics

import metrics_base
import commands_docdown

redef class ToolContext

	# README related metrics phase
	var readme_metrics_phase: Phase = new ReadmeMetricsPhase(self, null)
end

# Extract metrics about README files
private class ReadmeMetricsPhase
	super Phase

	redef fun process_mainmodule(mainmodule, given_mmodules) do
		if not toolcontext.opt_readme.value and not toolcontext.opt_all.value then return

		print toolcontext.format_h1("\n# ReadMe metrics")
		var model = toolcontext.modelbuilder.model

		# var cmd_parser = new CommandParser(model, mmodules.first, mbuilder)
		var md_parser = new MdParser
		md_parser.github_mode = true
		md_parser.wikilinks_mode = true
		md_parser.post_processors.add new MDocProcessSynopsis
		md_parser.post_processors.add new MDocProcessCodes
		# md_parser.post_processors.add new MDocProcessCommands(cmd_parser, toolcontext)
		model.mdoc_parser = md_parser


		var metrics = new ReadmeMetrics
		metrics.collect_metrics(model.mpackages)
		metrics.to_console(toolcontext)

		var csv = toolcontext.opt_csv.value
		if csv then metrics.to_csv.write_to_file("{toolcontext.opt_dir.value or else "metrics"}/readme.csv")
	end
end

# A Markdown visitor that collects metrics about a Readme content
class MDocMetricsVisitor
	super MdVisitor

	# Count blocks
	var block_counter = new Counter[String]

	# Count sections
	var headline_counter = new Counter[Int]

	# Collect metrics about the mpackage's mdoc
	fun collect_metrics(mpackage: MPackage) do
		var mdoc = mpackage.mdoc_or_fallback
		if mdoc == null then return
		enter_visit(mdoc.mdoc_document)
	end

	redef fun visit(node) do node.collect_metrics(self)
end

redef class MdNode
	private fun collect_metrics(v: MDocMetricsVisitor) do
		v.block_counter.inc self.class_name
		visit_all(v)
	end
end

redef class MdHeading
	redef fun collect_metrics(v) do
		v.headline_counter.inc level
		super
	end
end

# All metrics about the readmes
class ReadmeMetrics
	super HashMap[MPackage, ReadmeMetric]

	# Collect all metric names from submetrics
	fun metrics_names: ArraySet[String] do
		var keys = new ArraySet[String]
		keys.add "MPackage"
		for mpackage, values in self do
			keys.add_all values.keys
		end
		return keys
	end

	# Render `self` as a CsvDocument
	fun to_csv: CsvDocument do
		var doc = new CsvDocument
		doc.header = metrics_names.to_a

		var metrics = metrics_names
		for mpackage in self.keys do
			doc.records.add self[mpackage].to_csv_record(metrics)
		end
		return doc
	end

	# Print `self` into stdout
	fun to_console(toolcontext: ToolContext) do
		for mpackage, values in self do
			if not values.has_readme then continue
			values.to_console(toolcontext)
		end
	end

	# Collect metrics for all `mpackages`
	fun collect_metrics(mpackages: Collection[MPackage]) do
		for mpackage in mpackages do
			var metric = new ReadmeMetric(mpackage)
			metric.collect_metrics
			self[mpackage] = metric
		end
	end
end

# Readme metrics associated to a Package
class ReadmeMetric
	super HashMap[String, Int]

	# Package this Readme is about
	var mpackage: MPackage

	# Render `self` as a CsvDocument record
	fun to_csv_record(keys: ArraySet[String]): Array[String] do
		var record = new Array[String]
		record.add mpackage.full_name
		for key in keys do
			if key == keys.first then continue
			var value = if self.has_key(key) then self[key] else 0
			record.add value.to_s
		end
		return record
	end

	# Return the value associated with `key` or `0`.
	fun value_or_zero(key: String): Int do
		return if self.has_key(key) then self[key] else 0
	end

	# Print `self` on stdout
	fun to_console(toolcontext: ToolContext) do
		print toolcontext.format_h2("\n ## package {mpackage} ({readme_path or else "no readme"})")
		for key, value in self do
			print "  * {key} {value}"
		end
	end

	# Collect metrics about `mpackage`
	fun collect_metrics do
		if not has_package_dir then
			print "Warning: no source file for `{mpackage}`"
			self["has_package"] = 0
			return
		end
		self["has_package"] = 1

		if not has_readme then
			print "Warning: no readme file for `{mpackage}`"
			self["has_readme"] = 0
			return
		end
		self["has_readme"] = 1
		self["md_lines"] = md_lines.length

		md_visitor.collect_metrics(mpackage)
		collect_sections_metrics
		collect_blocs_metrics
	end

	# Path to the package
	var package_path: nullable SourceFile is lazy do return mpackage.location.file

	# Is `mpackage` in its own directory?
	var has_package_dir: Bool is lazy do
		var path = package_path
		if path == null then return false
		return not path.filename.has_suffix(".nit")
	end

	# Return the path to the `mpackage` Readme file
	var readme_path: nullable String is lazy do
		var package_path = self.package_path
		if package_path == null then return null
		return package_path.filename / "README.md"
	end

	# Does `mpackage` has a Readme file?
	var has_readme: Bool is lazy do
		var readme_path = self.readme_path
		if readme_path == null then return false
		return readme_path.to_s.file_exists
	end

	# Read markdown lines
	#
	# Returns an empty array if the Readme does not exist.
	var md_lines: Array[String] is lazy do
		var path = readme_path
		if path == null then return new Array[String]
		return path.to_path.read_lines
	end

	# Markdown visitor used to collect MDoc metrics
	var md_visitor = new MDocMetricsVisitor is lazy

	# Collect metrics related to section headings
	fun collect_sections_metrics do
		self["nb_section"] = md_visitor.headline_counter.sum
		for lvl, count in md_visitor.headline_counter do
			self["HL {lvl}"] = count
		end
	end

	# Collect metrics related to Markdown blocks
	fun collect_blocs_metrics do
		self["md_blocks"] = md_visitor.block_counter.sum
		for block, count in md_visitor.block_counter do
			self[block] = count
		end
	end
end
