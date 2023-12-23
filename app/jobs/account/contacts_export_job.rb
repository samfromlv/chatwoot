class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, column_names)
    account = Account.find(account_id)
    headers = valid_headers(column_names)
    generate_csv(account, headers)
    file_url = account_contact_export_url(account)

    AdministratorNotifications::ChannelNotificationsMailer.with(account: account).contact_export_complete(file_url)&.deliver_later
  end

  def generate_csv(account, headers)
    csv_data = CSV.generate do |csv|
      csv << headers
      account.contacts.each do |contact|
      csv << headers.map do |header|
        if contact.respond_to?(header)
          contact.send(header)
        elsif contact.additional_attributes && contact.additional_attributes.key?(header)
          contact.additional_attributes[header]
        else
        elsif contact.custom_attributes && contact.custom_attributes.key?(header)
          contact.custom_attributes[header]
        else
          nil
        end
      end
    end
    end

    attach_export_file(account, csv_data)
  end

  def valid_headers(column_names)
    columns = column_names.present? && !column_names.strip.empty? ? string_to_array(column_names) : default_columns
    #headers = columns.map { |column| column if Contact.column_names.include?(column) }
    columns.compact
  end

  def attach_export_file(account, csv_data)
    return if csv_data.blank?

    account.contacts_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{account.name}_#{account.id}_contacts.csv",
      content_type: 'text/csv'
    )
  end

  def account_contact_export_url(account)
    Rails.application.routes.url_helpers.rails_blob_url(account.contacts_export)
  end

  def string_to_array(string)
    string.split.reject(&:empty?)
  end

  def default_columns
    %w[id name email phone_number identifier]
  end
end
