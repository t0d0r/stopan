# SQLite's lower() and LIKE fold only ASCII letters, so searching Bulgarian
# text would be case-sensitive. ulower() folds with Ruby's Unicode-aware
# String#downcase; search scopes compare ulower(column) with a downcased
# pattern (specs/queues.md).
module SqliteUnicodeFunctions
  def configure_connection
    super
    @raw_connection.create_function("ulower", 1) do |function, value|
      function.result = value.is_a?(String) ? value.downcase : value
    end
  end
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  prepend SqliteUnicodeFunctions
end
