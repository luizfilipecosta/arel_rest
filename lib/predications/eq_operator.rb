module ArelRest::Predications
  class EqOperator
    class << self
      def process(query)
        values = query[:values] == '=null=' ? nil : query[:values]

        table = Arel::Table.new(query[:attribute].split(".")[0])
        table[query[:attribute].split(".")[1]].eq(values)
      end
    end
  end
end
