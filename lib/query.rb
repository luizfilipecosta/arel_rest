require "active_support/concern"
#TODO: Criar uma forma de checar a syntax dos consultas. Ex: Não aceitar dimenssões sem <table_name>.<column>
module ArelRest
	module Query
		extend ActiveSupport::Concern
		included do
			WHITE_LIST_MENSURE_OP = {
				"count" => :count,
				"average" => :average,
				"minimum" => :minimum,
				"maximum" => :maximum,
				"sum"   => :sum
			}

			@relationship_tree = {}

			def self.schema
				@relationship_tree = yield
			end

			def self.query(_rest_query)
				# Conditional methods chain
				self
				.then do |method_chain| 
					_rest_query[:filters] ? method_chain.filter(_rest_query[:filters]) :  method_chain
				end
				.then do |method_chain| 
					_rest_query[:sort] ? method_chain.order_by_dimensions(_rest_query[:sort]) :  method_chain
				end
				.then do |method_chain| 
					_rest_query[:dimensions] ? method_chain.group_by_dimensions(_rest_query[:dimensions]) :  method_chain
				end
				.then do |method_chain|
					_rest_query[:page] ? method_chain.offset(_rest_query[:page]) :  method_chain.offset(0)
				end
				.then do |method_chain|
					_rest_query[:size] ? method_chain.limit(_rest_query[:size]) :  method_chain.limit(100)
				end
				.then do |method_chain|
					if _rest_query[:measures]
						mensure_op = _rest_query[:measures].split('.')[0]
						column = _rest_query[:measures].split('.')[1]
						method_chain.send(WHITE_LIST_MENSURE_OP[mensure_op], column)
					else
						method_chain
					end
				end
			end

			def self.filter(query)
				return where({}) unless query.present?
				query_nodes = ArelRest::Parser.parse_filter_to_arel(query)
				tables_from_arel_node = collect_tables_from_arel(query_nodes).reject{|table| table == self.table_name}

				paths = tables_from_arel_node.map do |table|
					build_join_hash find_path_to_relation(relationship_tree, table)
				end
				where(query_nodes).joins(paths)
			end

			def self.group_by_dimensions(query)
				return group({}) unless query.present?
				paths = query
				# TODO: Estudar syntaxe p/ entender se essa extração de nome de tabela é correta
				.map{|dimension| dimension.split('.')[0]}
				.map{|table| find_path_to_relation(relationship_tree, table)}.compact
				.map{|path| build_join_hash path}

				group(query).joins(paths)
			end

			def self.order_by_dimensions(query)
				return order({}) unless query.present?
				paths = query
				# TODO: Estudar syntaxe p/ entender se essa extração de nome de tabela é correta
				.keys
				.map(&:to_s)
				.map{|dimension| dimension.split('.')[0]}
				.map{|table| find_path_to_relation(relationship_tree, table)}.compact
				.map{|path| build_join_hash path}

				order(
					ArelRest::Predications::OrderOperator
					.process({
						attribute: query.keys.first.to_s,
						values: query.values.first
					})
					).joins(paths)
			end

			def self.relationship_tree
				@relationship_tree
			end

			# Busca o caminho até uma associação específica (ex: :comments)
			def self.find_path_to_relation(tree, target_table, current_path = [])
				tree.each do |model_name, associations|
					associations.each do |assoc_name, subtree|
						table_name_assoc = model_name.to_s.constantize.reflect_on_association(assoc_name).table_name
						path_with_assoc = current_path + [model_name, assoc_name]
						return path_with_assoc + [subtree.keys.first] if (table_name_assoc == target_table)

						result = find_path_to_relation(subtree, target_table, path_with_assoc)
						return result if result
					end
				end
				nil
			end

			# Converte caminho [:posts, :comments] em hash encadeado { posts: :comments }
			def self.build_join_hash(path)
				path ||= []
				join_path = path.select.with_index { |_, i| i.odd? }
				join_path.reverse.reduce { |acc, key| { key => acc } }
			end

			# Recebe um nó(Arel::Node) e busca o nome de todas as tabelas a partir desse nó
			# TODO: Talvez seja mais fácil obter toda a expressão e obter todas as tabelas a partir
			# da string
			def self.collect_tables_from_arel(node, tables = Set.new)
				return tables unless node.is_a?(Arel::Nodes::Node) || node.is_a?(Arel::Attributes::Attribute)

				# Se for atributo, pega o nome da tabela
				if node.is_a?(Arel::Attributes::Attribute)
					tables << node.relation.name.to_s
				end

				# Percorre children, expressions, left, right, grouping, etc
				children = []
				children += node.children if node.respond_to?(:children)
				children << node.left if node.respond_to?(:left) && node.left
				children << node.right if node.respond_to?(:right) && node.right
				children << node.expr if node.respond_to?(:expr) && node.expr
				children += node.expressions if node.respond_to?(:expressions)

				children.compact.each do |child|
					collect_tables_from_arel(child, tables)
				end

				tables
			end

		end
	end
end