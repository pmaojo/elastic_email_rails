module ElasticEmail
  class Deliverer

    attr_accessor :settings

    def initialize(settings)
      self.settings = settings
    end

    def api_key
      self.settings[:api_key]
    end

    def deliver!(rails_message)
      response = elastic_email_client.send_message build_elastic_email_message_for(rails_message)
      response_body = response.body
      if response.code == '200' && response_body.present? && JSON.parse(response_body)['success']
        rails_message.message_id = JSON.parse(response_body)['data']['messageid']
      else
        raise Error.new(response_body)
      end
      response
    end

    private

    def build_elastic_email_message_for(rails_message)
      elastic_email_message = build_basic_elastic_email_message_for rails_message
      remove_empty_values elastic_email_message

      elastic_email_message
    end

    def build_basic_elastic_email_message_for(rails_message)
      elastic_email_message = {
          apikey: api_key,
          msgTo: rails_message[:to].formatted,
          subject: rails_message.subject,
          bodyText: extract_text(rails_message),
          bodyHtml: extract_html(rails_message)
      }

      if rails_message[:from].tree.present?
        elastic_email_message[:from] = rails_message[:from].tree.addresses.first.address
        elastic_email_message[:fromName] = rails_message[:from].tree.addresses.first.display_name
      end

      if rails_message[:reply_to].present?
        elastic_email_message[:replyTo] =     rails_message[:reply_to].tree.addresses.first.address
        elastic_email_message[:replyToName] = rails_message[:reply_to].tree.addresses.first.display_name
      end

      elastic_email_message
    end

    def extract_html(rails_message)
      if rails_message.html_part
        rails_message.html_part.body.decoded
      else
        rails_message.content_type =~ /text\/html/ ? rails_message.body.decoded : nil
      end
    end

    def extract_text(rails_message)
      if rails_message.multipart?
        rails_message.text_part ? rails_message.text_part.body.decoded : nil
      else
        rails_message.content_type =~ /text\/plain/ ? rails_message.body.decoded : nil
      end
    end

    def remove_empty_values(elastic_email_message)
      elastic_email_message.delete_if { |key, value| value.nil? }
    end

    def elastic_email_client
      @elastic_email_client ||= Client.new
    end
  end
end

ActionMailer::Base.add_delivery_method :elastic_email, ElasticEmail::Deliverer
