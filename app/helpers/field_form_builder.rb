# The default form builder (specs/ui.md "Form fields"), set in
# ApplicationController. It lives with the helpers (not a helper module:
# only *_helper.rb files are views' helpers). A field whose
# attribute has errors gets aria-invalid and its messages right under it,
# linked with aria-describedby, so every model form shows them without
# changes to the form. The role="alert" box at the top stays
# (ApplicationHelper#form_errors).
class FieldFormBuilder < ActionView::Helpers::FormBuilder
  INPUTS = %i[text_field email_field password_field number_field url_field search_field telephone_field
              date_field text_area file_field].freeze

  INPUTS.each do |helper|
    define_method(helper) do |method, options = {}|
      with_field_errors(method, options) { |merged| super(method, merged) }
    end
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    with_field_errors(method, html_options) { |merged| super(method, choices, options, merged, &block) }
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    with_field_errors(method, html_options) do |merged|
      super(method, collection, value_method, text_method, options, merged)
    end
  end

  private

  def with_field_errors(method, options)
    messages = field_error_messages(method)
    return yield(options) if messages.empty?

    error_id = "#{options[:id] || field_id(method)}_error"
    yield(invalid_options(options, error_id)) +
      @template.tag.span(@template.safe_join(messages, @template.tag.br), class: "field-error", id: error_id)
  end

  # Errors of an association land on its name, not on the _id field.
  def field_error_messages(method)
    return [] unless object.respond_to?(:errors)

    names = [ method.to_sym ]
    names << method.to_s.delete_suffix("_id").to_sym if method.to_s.end_with?("_id")
    names.flat_map { |name| object.errors.full_messages_for(name) }.uniq
  end

  def invalid_options(options, error_id)
    options = options.dup
    options.delete(:"aria-invalid")
    options.delete("aria-invalid")
    aria = (options.delete(:aria) || {}).to_h.symbolize_keys
    described = [ aria[:describedby], options.delete(:"aria-describedby"), options.delete("aria-describedby"), error_id ]
    options.merge(aria: aria.merge(invalid: true, describedby: described.compact_blank.join(" ")))
  end
end
