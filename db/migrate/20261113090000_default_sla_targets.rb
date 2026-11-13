# Realistic SLA targets from the start (specs/sla.md "Defaults"): the
# column's default for new installations, and the same values for an
# installation whose targets were never set.
class DefaultSlaTargets < ActiveRecord::Migration[8.1]
  DEFAULTS = {
    "urgent" => { "first_response" => 120, "resolution" => 1440 },
    "high" => { "first_response" => 480, "resolution" => 4320 },
    "normal" => { "first_response" => 1440, "resolution" => 7200 },
    "low" => { "first_response" => 4320, "resolution" => 14_400 }
  }.freeze

  class Setting < ActiveRecord::Base
    self.table_name = "app_settings"
  end

  def up
    change_column_default :app_settings, :sla_targets, from: {}, to: DEFAULTS
    Setting.reset_column_information
    Setting.find_each do |setting|
      set = setting.sla_targets.to_h.values.any? { |kinds| kinds.to_h.values.any? { |minutes| minutes.to_i.positive? } }
      setting.update_columns(sla_targets: DEFAULTS) unless set
    end
  end

  def down
    change_column_default :app_settings, :sla_targets, from: DEFAULTS, to: {}
  end
end
