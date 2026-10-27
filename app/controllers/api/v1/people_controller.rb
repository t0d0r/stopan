module Api
  module V1
    # A person's profile and ticket statistics, for staff (specs/people.md).
    class PeopleController < BaseController
      def show
        require_staff!
        person = ::PeopleController.visible_people(current_user).find(params[:id])
        stats = PersonStats.new(person, current_user)
        render json: {
          person: user_json(person).merge(deactivated: person.deactivated?, created_at: time_json(person.created_at),
                                          last_sign_in_at: time_json(person.last_sign_in_at),
                                          organizations: person.organizations.map { |organization| organization_json(organization) }),
          stats: { total: stats.total, unsolved: stats.unsolved, done: stats.done, last_30_days: stats.last_30_days,
                   first_response_median_seconds: stats.first_response_median, resolution_median_seconds: stats.resolution_median,
                   by_source: stats.by_source },
          recent: stats.recent.map { |ticket| ticket_json(ticket) }
        }
      end
    end
  end
end
