module GraphitiErrors
  module Validation
    module Validatable
      def render_errors_for(record)
        validation = Validation::Serializer.new \
          record, deserialized_params.relationships

        render \
          json: {errors: validation.errors},
          status: :unprocessable_entity
      end
    end
  end
end
