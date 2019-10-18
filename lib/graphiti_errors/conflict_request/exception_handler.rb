module GraphitiErrors
  module ConflictRequest
    class ExceptionHandler < GraphitiErrors::InvalidRequest::ExceptionHandler
      def status_code(error)
        409
      end
    end
  end
end
