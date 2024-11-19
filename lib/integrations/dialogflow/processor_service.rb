require 'google/apis/dialogflow_v2beta1'

class Integrations::Dialogflow::ProcessorService < Integrations::BotProcessorService
  pattr_initialize [:event_name!, :hook!, :event_data!]

  private

  def message_content(message)
    # TODO: might needs to change this to a way that we fetch the updated value from event data instead
    # cause the message.updated event could be that that the message was deleted

    return message.content_attributes['submitted_values']&.first&.dig('value') if event_name == 'message.updated'

    message.content
  end

  def get_response(session_id, message)
    if hook.settings['credentials'].blank?
      Rails.logger.warn "Account: #{hook.try(:account_id)} Hook: #{hook.id} credentials are not present." && return
    end
    detect_intent(session_id, message)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.warn "DialogFlow Error: (account-#{hook.try(:account_id)}, hook-#{hook.id}) #{e.message}"
    hook.prompt_reauthorization!
    hook.disable
  end

  def process_response(message, response)
    fulfillment_messages = response.query_result.fulfillment_messages
    fulfillment_messages.each do |fulfillment_message|
      content_params = generate_content_params(fulfillment_message)
      if content_params['action'].present?
        process_action(message, content_params['action'])
      else
        create_conversation(message, content_params)
      end
    end
  end

  def generate_content_params(fulfillment_message)
    text_response = fulfillment_message.text.to_h
    content_params = { content: text_response[:text].first } if text_response[:text].present?
    content_params ||= fulfillment_message.payload.to_h
    content_params
  end

  def create_conversation(message, content_params)
    return if content_params.blank?

    conversation = message.conversation
    conversation.messages.create!(
      content_params.merge(
        {
          message_type: :outgoing,
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id
        }
      )
    )
  end

  def detect_intent(session_id, message)
    # Initialize Dialogflow client
    Rails.logger.warn 'Test67'

    dialogflow = Google::Apis::DialogflowV2beta1::DialogflowService.new

    dialogflow.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(hook.settings['credentials'].to_json),
      scope: 'https://www.googleapis.com/auth/cloud-platform'
    )

    # Build session path
    session = "projects/#{hook.settings['project_id']}/agent/sessions/#{session_id}"
    # Build query input
    query_input = Google::Apis::DialogflowV2beta1::GoogleCloudDialogflowV2beta1QueryInput.new(
      text: Google::Apis::DialogflowV2beta1::GoogleCloudDialogflowV2beta1TextInput.new(
        text: message,
        language_code: 'en-US'
      )
    )
    # Construct the detectIntent request
    request = Google::Apis::DialogflowV2beta1::GoogleCloudDialogflowV2beta1DetectIntentRequest.new(
      query_input: query_input
    )
    # Call detectIntent
    dialogflow.detect_session_intent(session, request)
  end
end
