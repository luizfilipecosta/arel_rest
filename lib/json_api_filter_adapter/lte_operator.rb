module JsonApiFilterAdapter
	class LteOperator
		class << self
			def process(q)
				[template(q), q[:values]]
			end

			def template(q)
				":attribute <= ?".gsub(":attribute", q[:attribute])
			end
		end
	end
end