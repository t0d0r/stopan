# Where an earlier message starts in the text of a mail when it is quoted
# without ">" (Outlook, forwards): a separator line, or a header block of
# a From line with a date and a subject line before the next empty line;
# a rule line right before it belongs to it. The ticket page shows it as a
# collapsible earlier message, and replies that come in by mail are cut
# there (specs/organization-mail.md "Display of mail", "Processing a
# message").
module MailQuote
  RULE = /\A\s*([-_=*])\1{2,}\s*\z/
  FROM = /\A\s*\*?(from|von|от|de|van|da)\s*:\*?\s*\S/i
  DATE = /\A\s*\*?(sent|date|gesendet|datum|изпратено|дата|envoyé|verzonden|inviato)\s*:/i
  SUBJECT = /\A\s*\*?(subject|betreff|тема|objet|onderwerp|oggetto)\s*:/i
  SEPARATOR = /\A\s*(-{2,}\s*(original message|forwarded message|ursprüngliche nachricht|weitergeleitete nachricht|оригинално съобщение|препратено съобщение)\s*-{2,}|begin forwarded message:)\s*\z/i
  FORWARD = /forwarded message|weitergeleitete nachricht|препратено съобщение|begin forwarded message/i

  module_function

  # The index of the first line of the earlier message, or nil. With
  # keep_forwards a forward separator and the header block right after it
  # do not count, so a forward inside a reply stays.
  def start(lines, keep_forwards: false)
    at = lines.each_index.find do |index|
      next false if keep_forwards && forward?(lines, index)

      lines[index].match?(SEPARATOR) || header_size(lines, index).positive?
    end
    return unless at

    before = lines.first(at).rindex { |line| line.strip.present? }
    before && lines[before].match?(RULE) ? before : at
  end

  # The number of header lines at index, or 0 when no header block starts there.
  def header_size(lines, index)
    return 0 unless lines[index].match?(FROM)

    block = lines[index..].take_while(&:present?).first(10)
    block.any? { |line| line.match?(DATE) } && block.any? { |line| line.match?(SUBJECT) } ? block.size : 0
  end

  # A forward separator, or a line right after one (empty lines and rules
  # between them do not count).
  def forward?(lines, index)
    forward = ->(line) { line.match?(SEPARATOR) && line.match?(FORWARD) }
    return true if forward.(lines[index])

    before = lines.first(index).rindex { |line| line.strip.present? && !line.match?(RULE) }
    before.present? && forward.(lines[before])
  end
end
