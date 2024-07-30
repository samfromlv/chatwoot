class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    @conversations = if permitted_params[:status].nil?
                       Current.account.conversations.includes(
                         :assignee, :contact, :inbox, :taggings
                       ).where(inbox_id: inbox_ids, contact_id: @contact.id).order(id: :desc).limit(20)
                     else
                       Current.account.conversations.includes(
                         :assignee, :contact, :inbox, :taggings
                       ).where(inbox_id: inbox_ids, contact_id: @contact.id, status: permitted_params[:status]).order(id: :desc).limit(20)
                     end
  end

  private

  def inbox_ids
    if Current.user.administrator? || Current.user.agent?
      Current.user.assigned_inboxes.pluck(:id)
    else
      []
    end
  end

  def permitted_params
    params.permit(:status)
  end
end
