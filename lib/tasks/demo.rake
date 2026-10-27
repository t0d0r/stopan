# Example data for trying Stopan in development (specs/auth.md, Demo data).
# Every demo user gets DEMO_PASSWORD, which is never printed.
namespace :stopan do
  desc "Create example organizations, users and tickets (development only; needs DEMO_PASSWORD)"
  task demo: :environment do
    abort "stopan:demo refuses to run in production." if Rails.env.production?
    password = ENV["DEMO_PASSWORD"].to_s
    abort "Set DEMO_PASSWORD (at least #{Devise.password_length.min} characters)." if password.length < Devise.password_length.min
    if Organization.exists?(name: "Acme Bakery")
      puts "stopan:demo: demo data already exists."
      next
    end

    ActiveRecord::Base.transaction do
      user = ->(name, email, role = "requester") {
        User.create!(name: name, email: email, role: role, password: password, password_confirmation: password)
      }
      acme = Organization.create!(name: "Acme Bakery", notes: "Three shops and a central kitchen.")
      globex = Organization.create!(name: "Globex Logistics", notes: "Warehouse and office, Monday to Friday.")
      agent = user.("Maria Ivanova", "maria.agent@example.com", "agent")
      second_agent = user.("Petar Georgiev", "petar.agent@example.com", "agent")
      anna = user.("Anna Petrova", "anna@example.com")
      boris = user.("Boris Dimitrov", "boris@example.com")
      chris = user.("Chris Taylor", "chris@example.com")
      acme.users << [ anna, boris ]
      globex.users << chris
      # Agents work their own organizations only (specs/roles.md): Maria
      # both, Petar Globex.
      acme.users << agent
      globex.users << [ agent, second_agent ]

      printer = Ticket.create!(subject: "Receipt printer in shop 2 prints blank pages",
                               description: "Since this morning the receipt printer at the second till prints empty " \
                                            "paper. We replaced the roll and restarted it.",
                               requester: anna, organization: acme, actor: anna)
      printer.add_comment(author: agent, body: "Thanks Anna. Is the paper roll inserted with the shiny side towards the print head?")
      printer.add_comment(author: agent, body: "Model is the old thermal one; we have a spare in the store room.", internal: true)
      printer.apply_changes!({ assignee_id: agent.id, status: "pending" }, actor: agent)

      Ticket.create!(subject: "New staff member needs an email account",
                     description: "Please create an account for our new baker who starts on Monday.",
                     requester: boris, organization: acme, actor: boris)

      vpn = Ticket.create!(subject: "VPN disconnects every few minutes",
                           description: "The warehouse laptop loses the VPN connection about every five minutes.",
                           requester: chris, organization: globex, priority: "high", actor: agent)
      vpn.apply_changes!({ assignee_id: second_agent.id, priority: "urgent" }, actor: agent)
      vpn.add_comment(author: second_agent, body: "We updated the VPN client remotely. Please try again and tell us if it still drops.",
                      status: "done")
      vpn.add_comment(author: chris, body: "Still drops after the update, unfortunately.")
    end
    puts "stopan:demo: created 2 organizations, 5 users (password from DEMO_PASSWORD) and 3 tickets."
  end
end
