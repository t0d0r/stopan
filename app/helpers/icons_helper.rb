# Small inline SVG icons, so the app ships no image or icon font.
module IconsHelper
  ICONS = {
    clip: '<path d="M10.5 4.5 5.4 9.6a1.8 1.8 0 0 0 2.5 2.5l5.6-5.6a3 3 0 0 0-4.2-4.2L3.6 8a4.2 4.2 0 0 0 6 6l4.4-4.4" />',
    lock: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.2" /><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2" />',
    search: '<circle cx="7" cy="7" r="4.2" /><path d="m10.2 10.2 3.3 3.3" />',
    clock: '<circle cx="8" cy="8" r="6" /><path d="M8 4.6V8l2.4 1.6" />',
    sun: '<circle cx="8" cy="8" r="2.8" /><path d="M8 1.5v1.6M8 12.9v1.6M1.5 8h1.6M12.9 8h1.6' \
         'M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1" />',
    moon: '<path d="M13.2 9.6A5.6 5.6 0 0 1 6.4 2.8a5.6 5.6 0 1 0 6.8 6.8z" />',
    check: '<path d="m3.5 8.5 3 3 6-7" />',
    up: '<path d="m4 10 4-4 4 4" />',
    down: '<path d="m4 6 4 4 4-4" />',
    inbox: '<path d="M2 9.5 3.8 3.6A1.5 1.5 0 0 1 5.2 2.5h5.6a1.5 1.5 0 0 1 1.4 1.1L14 9.5v3a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1z" />' \
           '<path d="M2 9.5h3.5l1 1.5h3l1-1.5H14" />',
    plus: '<path d="M8 3v10M3 8h10" />',
    bell: '<path d="M4 11.5V7.2a4 4 0 0 1 8 0v4.3l1.2 1.3H2.8z" /><path d="M6.6 14a1.5 1.5 0 0 0 2.8 0" />',
    link: '<path d="M6.8 9.2a2.6 2.6 0 0 0 3.7 0l2.2-2.2a2.6 2.6 0 0 0-3.7-3.7l-.9.9" />' \
          '<path d="M9.2 6.8a2.6 2.6 0 0 0-3.7 0L3.3 9a2.6 2.6 0 0 0 3.7 3.7l.9-.9" />',
    copy: '<rect x="5.5" y="5.5" width="8" height="8" rx="1.2" /><path d="M10.5 5.5v-2a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2" />',
    markdown: '<rect x="1" y="3.5" width="14" height="9" rx="1.5" />' \
              '<path d="M3.5 10V6l2 2.3L7.5 6v4M11.5 6v4M10 8.6l1.5 1.5 1.5-1.5" />',
    widen: '<path d="M9.5 2.5h4v4M13.5 2.5 9.2 6.8M6.5 13.5h-4v-4M2.5 13.5l4.3-4.3" />',
    narrow: '<path d="M13.5 2.5 9.2 6.8M9.2 3.3v3.5h3.5M2.5 13.5l4.3-4.3M6.8 12.7V9.2H3.3" />',
    impersonate: '<circle cx="6" cy="5.5" r="2.5" /><path d="M1.5 13.5a4.5 4.5 0 0 1 9 0" />' \
                 '<path d="M11 8h4M13 6l2 2-2 2" />',
    envelope: '<rect x="2" y="3.5" width="12" height="9" rx="1.2" /><path d="m2.5 4.5 5.5 4.5 5.5-4.5" />',
    pencil: '<path d="M10.8 2.8a1.6 1.6 0 0 1 2.3 2.3L5.5 12.7l-3 .8.8-3z" /><path d="m9.6 4 2.4 2.4" />',
    eye: '<path d="M1.5 8s2.4-4.5 6.5-4.5S14.5 8 14.5 8 12.1 12.5 8 12.5 1.5 8 1.5 8z" /><circle cx="8" cy="8" r="2" />',
    user: '<circle cx="8" cy="5.5" r="2.8" /><path d="M2.8 14a5.2 5.2 0 0 1 10.4 0" />',
    building: '<rect x="3" y="2" width="7" height="12" rx="1" /><path d="M10 6h2.5a.5.5 0 0 1 .5.5V14H10' \
              'M5.5 5h2M5.5 8h2M5.5 11h2" />',
    reply: '<path d="M6.5 4 2.5 8l4 4" /><path d="M2.5 8h7a4 4 0 0 1 4 4v1" />',
    note: '<path d="M3 2.5h7l3 3v8H3z" /><path d="M10 2.5v3h3M5.5 8.5h5M5.5 11h3" />',
    status: '<circle cx="8" cy="8" r="5.5" /><circle cx="8" cy="8" r="2" fill="currentColor" stroke="none" />',
    flag: '<path d="M3.5 14V2.5M3.5 3h8l-1.8 3 1.8 3h-8" />',
    gear: '<circle cx="8" cy="8" r="2.2" /><path d="M8 1.8v1.7M8 12.5v1.7M1.8 8h1.7M12.5 8h1.7M3.6 3.6l1.2 1.2' \
          'M11.2 11.2l1.2 1.2M3.6 12.4l1.2-1.2M11.2 4.8l1.2-1.2" />',
    spark: '<path d="M8 2v3M8 11v3M2 8h3M11 8h3" /><circle cx="8" cy="8" r="1.2" />',
    headset: '<path d="M3 9.5V8a5 5 0 0 1 10 0v1.5" /><rect x="2.5" y="9" width="2.5" height="4" rx="1" />' \
             '<rect x="11" y="9" width="2.5" height="4" rx="1" /><path d="M12.2 13v.3a1.7 1.7 0 0 1-1.7 1.7H8.5" />',
    globe: '<circle cx="8" cy="8" r="6" /><path d="M2 8h12M8 2c1.7 1.8 2.5 3.8 2.5 6S9.7 12.2 8 14C6.3 12.2 5.5 10.2 5.5 8S6.3 3.8 8 2z" />',
    shield: '<path d="M8 1.8 13 3.6v4.1c0 3.1-2.1 5.4-5 6.5-2.9-1.1-5-3.4-5-6.5V3.6z" /><path d="m5.8 8 1.6 1.6 2.9-3" />'
  }.freeze

  def icon(name, label: nil, size: 14)
    attributes = label ? { role: "img", "aria-label": label } : { "aria-hidden": "true" }
    content_tag(:svg, ICONS.fetch(name).html_safe, class: "icon", viewBox: "0 0 16 16", width: size, height: size,
                fill: "none", stroke: "currentColor", "stroke-width": 1.5, "stroke-linecap": "round",
                "stroke-linejoin": "round", **attributes)
  end
end
