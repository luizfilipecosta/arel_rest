module ArelRest::Predications
  class LtOperator
    class << self
      def process(query)
        table = Arel::Table.new(query[:attribute].split(".")[0])
        column = query[:attribute].split(".")[1]

        table[column].lt(query[:values])
      end
    end
  end
end