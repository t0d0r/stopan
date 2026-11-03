# Pieces of the shared field style (specs/ui.md "Form fields").
module FormFieldsHelper
  # A field with a leading icon at its left edge; the block renders the
  # field. Only for search, Cc email and link fields, never for passwords
  # (specs/ui.md "Password fields").
  def input_icon(name, &block)
    tag.div(icon(name, size: 14) + capture(&block), class: "input-icon")
  end

  # Data attributes that make a select searchable (specs/ui.md "Searchable
  # selects"); merge them into the select's data.
  def combobox_data
    { combobox: true, combobox_empty: t("ui.combobox.no_match") }
  end
end
