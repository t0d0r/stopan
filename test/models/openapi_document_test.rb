require "test_helper"

# The OpenAPI description covers the whole API (specs/api.md "OpenAPI").
class OpenapiDocumentTest < ActiveSupport::TestCase
  VERBS = %w[get post patch delete].freeze

  def document = OpenapiDocument.to_h

  def operations
    document["paths"].flat_map { |path, verbs| verbs.map { |verb, operation| [ verb, path, operation ] } }
  end

  # "GET /api/v1/tickets/{number}" for every API route; PUT repeats PATCH.
  def routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless path.start_with?("/api/v1/") && path != "/api/v1/openapi.json"

      verb = route.verb.downcase
      next if verb == "put"

      "#{verb} #{path.gsub(/:(\w+)/) { "{#{Regexp.last_match(1).sub('ticket_number', 'number')}}" }}"
    end
  end

  test "every API route has an operation and every operation a route" do
    described = operations.map { |verb, path, _| "#{verb} #{path}" }
    assert_empty routes - described, "routes without an operation"
    assert_empty described - routes, "operations without a route"
    assert_operator described.size, :>=, 50
  end

  test "the document is OpenAPI 3.1 with the bearer token as security" do
    assert_equal "3.1.0", document["openapi"]
    assert_equal "Stopan API", document.dig("info", "title")
    assert_equal [ { "bearer" => [] } ], document["security"]
    assert_equal "bearer", document.dig("components", "securitySchemes", "bearer", "scheme")
  end

  test "operations have unique ids, a known tag, a summary and error answers" do
    ids = operations.map { |_, _, operation| operation["operationId"] }
    assert_equal ids.uniq, ids
    tags = document["tags"].map { |tag| tag["name"] }
    operations.each do |verb, path, operation|
      label = "#{verb} #{path}"
      assert_includes VERBS, verb, label
      assert operation["summary"].present?, label
      assert_includes tags, operation["tags"].sole, label
      codes = operation["responses"].keys
      assert codes.any? { |code| code.start_with?("2") }, label
      assert_empty %w[401 403 429] - codes, label
      assert_includes codes, "404", label if path.include?("{")
      assert_empty %w[400 422] - codes, label if operation["requestBody"]
      assert_nil operation["requestBody"], label if verb == "get"
    end
  end

  test "every path parameter is declared and every reference resolves" do
    operations.each do |verb, path, operation|
      declared = Array(operation["parameters"]).filter_map do |parameter|
        parameter = document.dig(*parameter["$ref"].delete_prefix("#/").split("/")) if parameter["$ref"]
        parameter["name"] if parameter["in"] == "path"
      end
      assert_equal path.scan(/\{(\w+)\}/).flatten.sort, declared.sort, "#{verb} #{path}"
    end

    refs = document.to_json.scan(/"\$ref":"(#[^"]+)"/).flatten.uniq
    assert_operator refs.size, :>, 10
    refs.each { |ref| assert document.dig(*ref.delete_prefix("#/").split("/")), ref }
  end

  test "values come from the models, and no secret field is described as returned" do
    schemas = document.dig("components", "schemas")
    assert_equal Ticket::STATUSES, schemas.dig("Ticket", "properties", "status", "enum")
    assert_equal Ticket::PRIORITIES, schemas.dig("Ticket", "properties", "priority", "enum")
    assert_equal User::ROLES, schemas.dig("User", "properties", "role", "enum")
    returned = schemas.to_json
    %w[smtp_password" imap_password" deepl_api_key" token_digest refresh_token].each do |secret|
      assert_not_includes returned, "\"#{secret}", secret
    end
  end
end
