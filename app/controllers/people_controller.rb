# A person's profile with ticket statistics, for staff (specs/people.md).
# Agents see only people of their own organizations.
class PeopleController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @person = self.class.visible_people(current_user).find(params[:id])
    @stats = PersonStats.new(@person, current_user)
  end

  # Everyone for administrators; for agents the members of their organizations.
  def self.visible_people(user)
    return User.all if user.admin?

    User.where(id: Membership.where(organization_id: user.memberships.select(:organization_id)).select(:user_id))
  end
end
