require 'google/apis/dialogflow_v3beta1'

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

    # configure_dialogflow_client_defaults
    detect_intent(session_id, message)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.warn "DialogFlow Error: (account-#{hook.try(:account_id)}, hook-#{hook.id}) #{e.message}"
    hook.prompt_reauthorization!
    hook.disable
  end

  def process_response(message, response, session_id)
    fulfillment_messages = response.query_result.response_messages
    fulfillment_messages.each do |fulfillment_message|
      content_params = generate_content_params(fulfillment_message)
      if content_params['action'].present?
        handle_tool_response(message, session_id, content_params['tool']) if content_params['tool'].present?
        process_action(message, content_params['action'])
      else
        create_conversation(message, content_params)
      end
    end
  end

  def handle_tool_response(message, session_id, tool)
    tool_response = detect_tool_response_intent(session_id, tool)
    process_response(message, tool_response, session_id)
  rescue StandardError => e
    Rails.logger.warn "DialogFlow Error: (account-#{hook.try(:account_id)}, hook-#{hook.id}) #{e.message}"
  end

  def generate_content_params(fulfillment_message)
    text_response = fulfillment_message.text.to_h
    content_params = { content: text_response[:text].first } if text_response[:text].present?
    content_params ||= fulfillment_message.payload.to_h
    if fulfillment_message.tool_call.present?
      content_params['tool'] = fulfillment_message.tool_call.tool
      content_params['tool_action'] = fulfillment_message.tool_call.action
      content_params['tool_params'] = fulfillment_message.tool_call.input_parameters
      content_params['action'] = fulfillment_message.tool_call.input_parameters['intent'] if content_params['tool_action'] == 'ConversationAction'
    end
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
    client = create_dialogflow_client

    request = create_detect_request(message)

    execute_detect_request(client, request, session_id)
  end

  def detect_tool_response_intent(session_id, tool)
    client = create_dialogflow_client

    request = create_detect_tool_response_request(tool)

    execute_detect_request(client, request, session_id)
  end

  def execute_detect_request(client, request, session_id)
    environment_id = hook.settings['environment_id']
    sesssion_path = build_session_path(session_id)
    if environment_id.present? && environment_id != '-'
      client.detect_project_location_agent_enviroment_session_intent(
        sesssion_path, request
      )
    else
      client.detect_project_location_agent_session_intent(
        sesssion_path, request
      )
    end
  end

  def build_session_path(session_id)
    environment_id = hook.settings['environment_id']
    base_path = "projects/#{hook.settings['project_id']}/locations/#{hook.settings['location_id']}/agents/#{hook.settings['agent_id']}"
    if environment_id.present? && environment_id != '-'
      "#{base_path}/environments/#{environment_id}/sessions/#{session_id}"
    else
      "#{base_path}/sessions/#{session_id}"
    end
  end

  def create_detect_request(message)
    query_input = Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1QueryInput.new(
      text: Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1TextInput.new(
        text: message
      ),
      language_code: 'en'
    )

    # Construct the detectIntent request
    Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1DetectIntentRequest.new(
      query_input: query_input
    )
  end

  def create_detect_tool_response_request(tool)
    tool_call_result = Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1ToolCallResult.new(
      tool: tool,
      action: 'ConversationAction',
      output_parameters: { text: 'Ok' }
    )

    query_input = Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1QueryInput.new(
      tool_call_result: tool_call_result,
      language_code: 'en'
    )

    # Construct the detectIntent request
    Google::Apis::DialogflowV3beta1::GoogleCloudDialogflowCxV3beta1DetectIntentRequest.new(
      query_input: query_input
    )
  end

  def create_dialogflow_client
    client = Google::Apis::DialogflowV3beta1::DialogflowService.new

    client.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(hook.settings['credentials'].to_json),
      scope: 'https://www.googleapis.com/auth/cloud-platform'
    )

    client
  end
end
