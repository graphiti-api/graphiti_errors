module GraphitiErrors
  module ConflictRequest
    class Serializer < InvalidRequest::Serializer
      def initialize(errors)
        super(errors)
        @status_code = 409
      end
    end
  end
end
