# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1. You can set it to `auto` to automatically start a worker
# for each available processor.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# The job queue runs inside Puma in production, as threads of the web
# process (async mode), not as forked processes: the page refreshes are
# jobs too, and Action Cable's async adapter reaches only the browsers
# connected to the process that broadcasts
# (specs/notifications.md "Delivery").
if ENV["RAILS_ENV"] == "production"
  plugin :solid_queue
  solid_queue_mode :async
end

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Refuse a request body over MAX_REQUEST_BODY bytes with 413 before it is
# read, so an upload larger than the attachment limits is never stored
# (specs/attachments.md "Request size"). The default leaves room for 5
# files of 10 MB and the form's text. 0 turns the limit off, as in
# Thruster, which reads the same variable in the Docker image.
max_request_body = Integer(ENV.fetch("MAX_REQUEST_BODY", 52 * 1024 * 1024))
raise ArgumentError, "MAX_REQUEST_BODY must be 0 (no limit) or a number of bytes" if max_request_body.negative?
http_content_length_limit max_request_body if max_request_body.positive?
