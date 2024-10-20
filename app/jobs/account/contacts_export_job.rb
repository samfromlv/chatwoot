class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    @params = params
    @account_user = @account.users.find(user_id)

    headers = valid_headers(column_names)
    generate_csv(headers)
    send_mail
  end

  private

  def generate_csv(headers)
    csv_data = CSV.generate do |csv|
      csv << headers
      contacts.each do |contact|
        csv << headers.map { |header| contact_value(contact, header) }
      end
    end

    attach_export_file(csv_data)
  end

  def contact_value(contact, header)
    if contact.respond_to?(header)
      contact.send(header)
    elsif contact.additional_attributes&.key?(header)
      contact.additional_attributes[header]
    elsif contact.custom_attributes&.key?(header)
      contact.custom_attributes[header]
    end
  end

  def contacts
    if @params.present? && @params[:payload].present? && @params[:payload].any?
      result = ::Contacts::FilterService.new(@account, @account_user, @params).perform
      result[:contacts]
    elsif @params[:label].present?
      @account.contacts.resolved_contacts.tagged_with(@params[:label], any: true)
    else
      @account.contacts.resolved_contacts
    end
  end

  def valid_headers(column_names)
    columns = column_names.present? && !column_names.strip.empty? ? string_to_array(column_names) : default_columns
    # headers = columns.map { |column| column if Contact.column_names.include?(column) }
    columns.compact
  end

  def attach_export_file(csv_data)
    return if csv_data.blank?

    @account.contacts_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{@account.name}_#{@account.id}_contacts.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::ChannelNotificationsMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end

  def string_to_array(string)
    string.split.reject(&:empty?)
  end

  def default_columns
    %w[id name email phone_number identifier]
  end
end
