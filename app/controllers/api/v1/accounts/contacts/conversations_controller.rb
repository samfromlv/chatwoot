class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    limit = determine_limit

    @conversations = Current.account.conversations.includes(
      :assignee, :contact, :inbox, :taggings
    ).where(inbox_id: inbox_ids, contact_id: @contact.id)

    @conversations = @conversations.where(status: permitted_params[:status]) if permitted_params[:status].present?

    @conversations = @conversations.order(id: :desc).limit(limit)
  end

  private

  def determine_limit
    limit = 20
    return limit if permitted_params[:limit].nil?

    [permitted_params[:limit].to_i, limit].min
  end

  def inbox_ids
    if Current.user.administrator? || Current.user.agent?
      Current.user.assigned_inboxes.pluck(:id)
    else
      []
    end
  end

  def permitted_params
    params.permit(:status, :limit)
  end
end
