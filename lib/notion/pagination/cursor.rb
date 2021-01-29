# frozen_string_literal: true
module Notion
  module Api
    module Pagination
      class Cursor
        include Enumerable

        attr_reader :client
        attr_reader :verb
        attr_reader :sleep_interval
        attr_reader :max_retries
        attr_reader :params

        def initialize(client, verb, params = {})
          @client = client
          @verb = verb
          @params = params.dup
          @sleep_interval = @params.delete(:sleep_interval)
          @max_retries = @params.delete(:max_retries) || client.default_max_retries
        end

        def each
          next_cursor = nil
          retry_count = 0
          loop do
            query = { limit: client.default_page_size }.merge(params).merge(start_cursor: next_cursor)
            begin
              response = client.send(verb, query)
            rescue Notion::Api::Errors::TooManyRequestsError => e
              raise e if retry_count >= max_retries

              client.logger.debug("#{self.class}##{__method__}") { e.to_s }
              retry_count += 1
              sleep(e.retry_after)
              next
            end
            yield response
            break unless response.has_more

            next_cursor = response.next_cursor
            break if next_cursor.nil? || next_cursor == ''

            retry_count = 0
            sleep(sleep_interval) if sleep_interval
          end
        end
      end
    end
  end
end