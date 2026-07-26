# frozen_string_literal: true

# Provider clients must not emit authorization headers or prompt content to the
# application log. Errors are reported in SuggestionService without secrets.
Langchain.logger.level = Logger::WARN if defined?(Langchain)
