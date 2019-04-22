module GraphitiErrors
  module InvalidRequest
    class ExceptionHandler < GraphitiErrors::ExceptionHandler
      def initialize(options = {})
        unless options.key?(:log)
          options[:log] = false
        end

        super

        @show_raw_error = log?
      end

      def status_code(error)
        400
      end

      def error_payload(error)
        serializer = InvalidRequest::Serializer.new(error.errors)

        {
          errors: serializer.rendered_errors,
        }
      end
    end
  end
end
