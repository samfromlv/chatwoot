class CustomFilterPolicy < ApplicationPolicy
  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator? || @account_user.agent?
  end

  def destroy?
    @account_user.administrator? || @account_user.agent?
  end

  # Admin-only policy methods for managing user-specific custom filters
  def admin_index?
    @account_user.administrator?
  end

  def admin_create?
    @account_user.administrator?
  end

  def admin_update?
    @account_user.administrator?
  end

  def admin_destroy?
    @account_user.administrator?
  end
end
