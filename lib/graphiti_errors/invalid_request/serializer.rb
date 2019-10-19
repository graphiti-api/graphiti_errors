module GraphitiErrors
  module InvalidRequest
    class Serializer
      attr_reader :errors
      def initialize(errors)
        @errors = errors
        @status_code = 400
      end

      def rendered_errors
        errors_payload = []
        errors.details.each_pair do |attribute, att_errors|
          att_errors.each_with_index do |error, idx|
            code = error[:error]
            message = errors.messages[attribute][idx]

            errors_payload << {
              code: "bad_request",
              status: @status_code.to_s,
              title: "Request Error",
              detail: errors.full_message(attribute, message),
              source: {
                pointer: attribute.to_s.tr(".", "/").gsub(/\[(\d+)\]/, '/\1'),
              },
              meta: {
                attribute: attribute,
                message: message,
                code: code,
              },
            }
          end
        end

        errors_payload
      end
    end
  end
end
