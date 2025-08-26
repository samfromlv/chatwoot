class Api::V1::Accounts::CustomFiltersController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :check_admin_authorization?, only: [:admin_index, :admin_create, :admin_update, :admin_destroy]
  before_action :fetch_custom_filters, except: [:create, :admin_create]
  before_action :fetch_custom_filter, only: [:show, :update, :destroy]
  before_action :fetch_admin_custom_filter, only: [:admin_update, :admin_destroy]
  before_action :find_user, only: [:admin_index, :admin_create]
  DEFAULT_FILTER_TYPE = 'conversation'.freeze

  def index; end

  def show; end

  def create
    @custom_filter = current_user.custom_filters.create!(
      permitted_payload.merge(account_id: Current.account.id)
    )
    render json: { error: @custom_filter.errors.messages }, status: :unprocessable_entity and return unless @custom_filter.valid?
  end

  def update
    @custom_filter.update!(permitted_payload)
  end

  def destroy
    @custom_filter.destroy!
    head :no_content
  end

  # Admin methods for managing user-specific custom filters
  def admin_index
    @custom_filters = @user.custom_filters.where(
      account_id: Current.account.id,
      filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
    )
    render :index
  end

  def admin_create
    @custom_filter = @user.custom_filters.create!(
      permitted_payload.merge(account_id: Current.account.id)
    )
    render json: { error: @custom_filter.errors.messages }, status: :unprocessable_entity and return unless @custom_filter.valid?

    render :show
  end

  def admin_update
    @custom_filter.update!(permitted_payload)
    render :show
  end

  def admin_destroy
    @custom_filter.destroy!
    head :no_content
  end

  private

  def find_user
    @user = Current.account.users.find(permitted_params[:user_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def fetch_admin_custom_filter
    @custom_filter = Current.account.custom_filters.find(permitted_params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Custom filter not found' }, status: :not_found
  end

  def fetch_custom_filters
    @custom_filters = if permitted_params[:show_all] == 'true'
                        Current.account.custom_filters.where(
                          filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
                        )
                      elsif permitted_params[:show_shared] == 'true'
                        Current.account.custom_filters.where(
                          filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
                        ).where('user_id = ? OR name LIKE ?', current_user.id, '__ %')
                      else
                        current_user.custom_filters.where(
                          account_id: Current.account.id,
                          filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
                        )
                      end
  end

  def fetch_custom_filter
    @custom_filter = @custom_filters.find(permitted_params[:id])
  end

  def permitted_payload
    params.require(:custom_filter).permit(
      :name,
      :filter_type,
      query: {}
    )
  end

  def permitted_params
    params.permit(:id, :filter_type, :show_all, :show_shared, :user_id)
  end
end
