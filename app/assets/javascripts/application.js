// Page behaviour for Stopan. Plain JavaScript plus Turbo Drive (turbo-rails),
// which swaps the <body> on link clicks and form submits instead of loading
// a new page. This file runs once; setUpPage runs on every turbo:load.
// Listeners on document or window that belong to one page pass
// { signal: pageSignal }, so they are removed when the next page loads.
let pageAbort = null;
let pageSignal;

// The text size zoom on <body> (specs/ui.md "Text size zoom"): window sizes and
// getBoundingClientRect are in screen pixels, CSS lengths inside the page
// are multiplied by the zoom, so screen pixels are divided by it first.
function pageZoom() {
  const body = document.body;
  return body.offsetWidth ? body.getBoundingClientRect().width / body.offsetWidth : 1;
}

// Text areas grow with their text instead of scrolling. scrollHeight leaves
// out the border, which with border-box sizing would leave the box a pixel
// short. Without JavaScript the field keeps its normal scroll bar. A field
// that is not shown yet (the closed composer on phones) is measured when it
// first shows.
function autoGrow(textarea) {
  let minimum = textarea.offsetHeight;
  const grow = () => {
    if (textarea.getClientRects().length === 0) return;
    minimum ||= textarea.offsetHeight;
    const scrollY = window.scrollY;
    textarea.style.height = "auto";
    const border = textarea.offsetHeight - textarea.clientHeight;
    textarea.style.height = `${Math.max(minimum, textarea.scrollHeight + border)}px`;
    if (window.scrollY !== scrollY) window.scrollTo(window.scrollX, scrollY);
  };
  textarea.addEventListener("input", grow);
  window.addEventListener("resize", grow, { signal: pageSignal });
  grow();
}

// Forms with data-confirm (delete buttons) ask first in a dialog that says
// what will happen; data-confirm-title and data-confirm-button fill it in.
// Without the dialog the browser's own confirm is used.
function setUpConfirm(dialog) {
  let pending = null;

  // A whole form asks (data-confirm), or only one of its submit buttons
  // does (data-confirm on the button, e.g. "Delete" in the bulk bar).
  document.querySelectorAll("form[data-confirm], form:has(button[data-confirm]), form#bulk-form").forEach((form) => {
    form.addEventListener("submit", (event) => {
      if (form.dataset.confirmed === "true") return;
      const asker = form.dataset.confirm ? form : event.submitter?.dataset.confirm ? event.submitter : null;
      if (!asker) return;
      event.preventDefault();
      const submitter = event.submitter;
      if (!dialog) {
        if (window.confirm(asker.dataset.confirm)) submitConfirmed(form, submitter);
        return;
      }
      pending = { form, submitter };
      dialog.querySelector("[data-confirm-title]").textContent = asker.dataset.confirmTitle || dialog.dataset.defaultTitle;
      dialog.querySelector("[data-confirm-body]").textContent = asker.dataset.confirm;
      dialog.querySelector("[data-confirm-ok]").textContent = asker.dataset.confirmButton || dialog.dataset.defaultButton;
      dialog.returnValue = "";
      dialog.showModal();
      dialog.querySelector("[data-confirm-cancel]").focus();
    });
  });

  if (!dialog) return;
  // Escape and the backdrop cancel; only the destructive button confirms.
  dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });
  dialog.addEventListener("close", () => {
    if (dialog.returnValue === "confirm" && pending) submitConfirmed(pending.form, pending.submitter);
    pending = null;
  });
}

function submitConfirmed(form, submitter) {
  form.dataset.confirmed = "true";
  form.requestSubmit(submitter?.form === form ? submitter : undefined);
}

// The reply form switches between a public reply and an internal note: the
// paper turns pink, a hint appears and the button says what will happen.
function setUpComposer(composer) {
  const button = composer.querySelector("[data-composer-submit]");
  const update = () => {
    const internal = composer.querySelector("[data-composer-mode=internal]:checked") !== null;
    composer.classList.toggle("is-internal", internal);
    composer.classList.toggle("sticky--pink", internal);
    composer.classList.toggle(`sticky--${composer.dataset.staffColor}`, !internal);
    if (!button) return;
    button.querySelector("[data-composer-label]").textContent = internal ? button.dataset.internalLabel : button.dataset.publicLabel;
    button.querySelectorAll("[data-composer-icon]").forEach((icon) => { icon.hidden = (icon.dataset.composerIcon === "internal") !== internal; });
  };
  composer.querySelectorAll("[data-composer-mode]").forEach((radio) => radio.addEventListener("change", update));
}

// "Email the requester" (specs/notifications.md "Emails to the requester"):
// the toggle saves at once, and the warning under it follows. The save is
// a POST with _method through Turbo's fetch, so this tab skips its own
// refresh; on failure the toggle flips back.
function setUpRequesterMail(block) {
  const box = block.querySelector("[data-requester-mail-toggle]");
  const show = () => block.classList.toggle("is-off", !box.checked);
  box.addEventListener("change", async () => {
    show();
    const body = new FormData();
    body.append("_method", "patch");
    body.append("email_requester", box.checked ? "1" : "0");
    const token = document.querySelector("meta[name=csrf-token]")?.content;
    let ok = false;
    try {
      const send = window.Turbo?.fetch || window.fetch;
      const response = await send(block.dataset.path, {
        method: "POST", body, credentials: "same-origin", headers: { "X-CSRF-Token": token, Accept: "text/html" }
      });
      ok = response.ok;
    } catch {}
    // A saved toggle is not work in progress for the live refresh check.
    if (ok) box.defaultChecked = box.checked;
    else { box.checked = !box.checked; show(); }
  }, { signal: pageSignal });
}

// The eye on a password field shows or hides what was typed, keeping the
// focus and the caret; sending the form hides it again (specs/ui.md
// "Password fields").
function setUpPasswordField(field) {
  const input = field.querySelector("input");
  const button = field.querySelector("[data-password-toggle]");
  if (!input || !button) return;
  const show = (visible) => {
    input.type = visible ? "text" : "password";
    const label = visible ? button.dataset.hideLabel : button.dataset.showLabel;
    button.setAttribute("aria-pressed", String(visible));
    button.setAttribute("aria-label", label);
    button.title = label;
  };
  button.hidden = false;
  // Keep the focus in the field while the button is pressed.
  button.addEventListener("mousedown", (event) => event.preventDefault(), { signal: pageSignal });
  button.addEventListener("click", () => {
    const start = input.selectionStart;
    const end = input.selectionEnd;
    show(input.type === "password");
    input.focus();
    if (start !== null) input.setSelectionRange(start, end);
  }, { signal: pageSignal });
  input.form?.addEventListener("submit", () => show(false), { signal: pageSignal });
}

// File drop zone (specs/ui.md "Form fields"): the real file input keeps the
// files. The area is its label (a click opens the picker) and takes dropped
// files; the list shows each chosen file with a remove button. The input's
// files are rebuilt with DataTransfer, so the form sends exactly the listed
// files and pageIsBusy still sees them. A file over the size limit, or
// one more than the count limit, is left out and named in the alert box
// under the list; the server checks the same limits again. Without
// DataTransfer the plain input stays as it is.
function setUpDropzone(zone) {
  const input = zone.querySelector("[data-dropzone-input]");
  const area = zone.querySelector("[data-dropzone-area]");
  const list = zone.querySelector("[data-dropzone-list]");
  const status = zone.querySelector("[data-dropzone-status]");
  const template = zone.querySelector("template[data-dropzone-item]");
  const errors = zone.querySelector("[data-dropzone-errors]");
  if (!input || !area || !list || !status || !template) return;
  try { new DataTransfer(); } catch { return; }

  let files = Array.from(input.files);
  const maxFiles = Number(zone.dataset.maxFiles) || Infinity;
  const maxSize = Number(zone.dataset.maxSize) || Infinity;
  const named = (text, file) => (text || "").replace("%{name}", () => file.name);
  // Replaces the lines of the alert box; an empty list clears it.
  const refuse = (lines) => {
    errors?.replaceChildren(...lines.map((line) => {
      const item = document.createElement("p");
      item.className = "field-error";
      item.textContent = line;
      return item;
    }));
  };
  const key = (file) => [file.name, file.size, file.lastModified].join("/");
  const language = document.documentElement.lang || undefined;
  const format = (value, unit, digits) => {
    try {
      return new Intl.NumberFormat(language, { style: "unit", unit, unitDisplay: "short", maximumFractionDigits: digits }).format(value);
    } catch {
      return `${value.toFixed(digits)} ${{ byte: "B", kilobyte: "kB", megabyte: "MB" }[unit]}`;
    }
  };
  // Binary steps, as the server's limit (Attachable::MAX_SIZE) and its hint;
  // "B" for bytes in every language (Intl writes "byte" or "Byte").
  const size = (bytes) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return format(bytes / 1024, "kilobyte", 0);
    return format(bytes / 1024 / 1024, "megabyte", 1);
  };
  const chosen = (count) => {
    if (count === 0) return zone.dataset.chosenZero;
    if (count === 1) return zone.dataset.chosenOne;
    return zone.dataset.chosenOther.replace("%{count}", () => String(count));
  };
  const write = () => {
    const transfer = new DataTransfer();
    files.forEach((file) => transfer.items.add(file));
    input.files = transfer.files;
  };
  const render = (announce) => {
    list.replaceChildren(...files.map((file, index) => {
      const item = template.content.firstElementChild.cloneNode(true);
      item.querySelector(".dropzone__name").textContent = file.name;
      item.querySelector(".dropzone__size").textContent = size(file.size);
      const button = item.querySelector(".dropzone__remove");
      const label = zone.dataset.removeLabel.replace("%{name}", () => file.name);
      button.setAttribute("aria-label", label);
      button.title = label;
      button.addEventListener("click", () => remove(index));
      return item;
    }));
    list.hidden = files.length === 0;
    if (announce) status.textContent = chosen(files.length);
  };
  const add = (more) => {
    const known = new Set(files.map(key));
    const refused = [];
    Array.from(more).forEach((file) => {
      if (known.has(key(file))) return;
      if (file.size > maxSize) {
        refused.push(named(zone.dataset.tooBig, file));
        return;
      }
      if (files.length >= maxFiles) {
        refused.push(named(zone.dataset.tooMany, file));
        return;
      }
      known.add(key(file));
      files.push(file);
    });
    write();
    render(true);
    refuse(refused);
  };
  function remove(index) {
    files.splice(index, 1);
    write();
    render(true);
    refuse([]);
    const buttons = list.querySelectorAll(".dropzone__remove");
    (buttons[index] || buttons[index - 1] || input).focus();
  }

  // The picker replaces the input's files (cancelling may empty them): add
  // what was picked to the earlier ones and write them all back.
  input.addEventListener("change", () => add(input.files));

  let depth = 0;
  const carriesFiles = (event) => Array.from(event.dataTransfer?.types || []).includes("Files");
  zone.addEventListener("dragenter", (event) => {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    depth += 1;
    zone.classList.add("is-dragover");
  });
  zone.addEventListener("dragover", (event) => {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
  });
  zone.addEventListener("dragleave", () => {
    depth = Math.max(0, depth - 1);
    if (depth === 0) zone.classList.remove("is-dragover");
  });
  zone.addEventListener("drop", (event) => {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    depth = 0;
    zone.classList.remove("is-dragover");
    add(event.dataTransfer.files);
  });

  zone.classList.add("is-enhanced");
  area.hidden = false;
  render(false);
}

// Phone menu (ui.md "Menu bar"): the button shows the sections, preferences
// and account under the bar; a click outside or Escape closes it. Turbo
// swaps the whole bar on the next page, so it starts closed there.
function setUpMenu(menubar) {
  const button = menubar?.querySelector("[data-menu-toggle]");
  if (!button) return;
  const show = (open) => {
    menubar.classList.toggle("is-open", open);
    button.setAttribute("aria-expanded", open);
  };
  button.addEventListener("click", () => show(!menubar.classList.contains("is-open")));
  document.addEventListener("click", (event) => {
    if (menubar.classList.contains("is-open") && !menubar.contains(event.target)) show(false);
  }, { signal: pageSignal });
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || !menubar.classList.contains("is-open")) return;
    show(false);
    button.focus();
  }, { signal: pageSignal });
}

// Ticket page on phones (ui.md "Ticket page on phones"): the side panels
// start closed and open from their title strip, and the composer opens from
// the Reply bar at the bottom of the screen. What is open is kept per page
// in this tab, so a live refresh (a new body) does not close it. On wide
// screens the classes change nothing.
const openOnPage = new Map();

function setUpTicketOnPhones(page) {
  if (!page) return;
  if (!openOnPage.has(location.pathname)) openOnPage.set(location.pathname, new Set());
  const remembered = openOnPage.get(location.pathname);

  page.querySelectorAll("[data-side-panel]").forEach((panel) => {
    const toggle = panel.querySelector("[data-panel-toggle]");
    const show = (open) => {
      panel.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", open);
      if (open) remembered.add(panel.id);
      else remembered.delete(panel.id);
    };
    // A link to #sharing (after changing the link) opens that panel.
    show(panel.classList.contains("is-open") || remembered.has(panel.id) || location.hash === `#${panel.id}`);
    toggle.addEventListener("click", () => show(!panel.classList.contains("is-open")));
  });

  const composer = page.querySelector("#composer");
  const open = page.querySelector("[data-reply-open]");
  if (!composer || !open) return;
  const showComposer = (shown) => {
    composer.classList.toggle("is-open", shown);
    open.setAttribute("aria-expanded", shown);
    if (shown) remembered.add(composer.id);
    else remembered.delete(composer.id);
  };
  showComposer(composer.classList.contains("is-open") || remembered.has(composer.id));
  open.addEventListener("click", () => {
    showComposer(true);
    composer.scrollIntoView({ block: "start" });
    const field = composer.querySelector("textarea");
    field?.dispatchEvent(new Event("input"));
    field?.focus({ preventScroll: true });
  });
  composer.querySelector("[data-reply-close]")?.addEventListener("click", () => {
    showComposer(false);
    open.focus();
  });
}

// Assign menus in the queue float under their button, so the table's scroll
// box does not clip them; one is open at a time (specs/queues.md). Without
// JavaScript the <details> opens inside the cell.
function setUpAssignMenus(menus) {
  if (menus.length === 0) return;
  const closeAll = (except) => menus.forEach((menu) => { if (menu !== except) menu.open = false; });

  menus.forEach((menu) => {
    const list = menu.querySelector(".assign-menu__list");
    menu.classList.add("is-floating");
    menu.addEventListener("toggle", () => {
      if (!menu.open) return;
      closeAll(menu);
      const zoom = pageZoom();
      const rect = menu.querySelector("summary").getBoundingClientRect();
      const box = { top: rect.top / zoom, bottom: rect.bottom / zoom, left: rect.left / zoom };
      const below = box.bottom + 4 + list.offsetHeight <= window.innerHeight / zoom;
      list.style.top = `${below ? box.bottom + 4 : Math.max(8, box.top - 4 - list.offsetHeight)}px`;
      list.style.left = `${Math.max(8, Math.min(box.left, window.innerWidth / zoom - list.offsetWidth - 8))}px`;
    });
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest("details[data-assign-menu]")) closeAll();
  }, { signal: pageSignal });
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    const open = Array.from(menus).find((menu) => menu.open);
    if (!open) return;
    open.open = false;
    open.querySelector("summary").focus();
  }, { signal: pageSignal });
  window.addEventListener("scroll", () => closeAll(), { signal: pageSignal, capture: true, passive: true });
  window.addEventListener("resize", () => closeAll(), { signal: pageSignal });
}

// Staff new ticket form: the organization select lists only the chosen
// requester's organizations (specs/tickets.md "Creating").
function setUpRequesterOrganizations(requester) {
  const organization = document.getElementById(requester.dataset.requesterOrganizations);
  const hint = document.getElementById("organization-hint");
  if (!organization) return;

  const update = () => {
    const chosen = requester.selectedOptions[0];
    const allowed = chosen && chosen.value ? (chosen.dataset.organizations || "").split(" ") : null;
    const fitting = [];
    organization.querySelectorAll("option").forEach((option) => {
      if (!option.value) return;
      const fits = allowed !== null && allowed.includes(option.value);
      option.hidden = !fits;
      option.disabled = !fits;
      if (fits) fitting.push(option);
    });
    if (organization.selectedOptions[0]?.disabled) organization.value = "";
    if (fitting.length === 1) organization.value = fitting[0].value;
    organization.disabled = allowed === null;
    if (hint) hint.textContent = allowed === null ? hint.dataset.chooseText : hint.dataset.defaultText;
  };
  requester.addEventListener("change", update);
  update();
  // What the page picks as it loads (the requester's only organization,
  // after the form came back with errors) is not the user's work in
  // progress: it becomes the starting value that pageIsBusy compares with.
  Array.from(organization.options).forEach((option) => { option.defaultSelected = option.selected; });
}

// "Copy link" buttons copy the value of the field they name; the field
// itself is selected on focus, so copying also works by hand.
function setUpCopyButtons() {
  // One-click copy of a value (the public page links in the organizations
  // list, specs/public-form.md); the tooltip says "Copied" for a moment.
  document.querySelectorAll("[data-copy-value]").forEach((button) => {
    const label = button.title;
    button.addEventListener("click", async () => {
      await copyText(button.dataset.copyValue);
      // A visible "Copied" that screen readers also hear, where the button has one.
      const status = button.querySelector("[data-copied-status]");
      button.classList.add("is-copied");
      button.title = button.dataset.copiedLabel;
      if (status) status.textContent = button.dataset.copiedLabel;
      setTimeout(() => {
        button.classList.remove("is-copied");
        button.title = label;
        if (status) status.textContent = "";
      }, 2000);
    }, { signal: pageSignal });
  });
  document.querySelectorAll("[data-copy]").forEach((button) => {
    const field = document.getElementById(button.dataset.copy);
    const label = button.querySelector("[data-copy-label]");
    if (!field || !label) return;
    const original = label.textContent;
    button.addEventListener("click", async () => {
      field.select();
      try {
        await navigator.clipboard.writeText(field.value);
      } catch {
        document.execCommand("copy");
      }
      label.textContent = button.dataset.copiedLabel;
      setTimeout(() => { label.textContent = original; }, 2000);
    });
  });
  document.querySelectorAll("input[data-select-on-focus]").forEach((field) => {
    field.addEventListener("focus", () => field.select());
  });
}

// Puts text on the clipboard; plain HTTP (other than localhost) has no
// Clipboard API, so a hidden text area and execCommand stand in.
async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return;
  } catch {}
  const area = document.createElement("textarea");
  area.value = text;
  area.readOnly = true;
  area.style.cssText = "position: fixed; top: 0; opacity: 0;";
  document.body.append(area);
  area.select();
  document.execCommand("copy");
  area.remove();
}

// Copy box in a message's title strip (specs/ui.md "Copy box"): copies the
// message's text as shown. The text is looked up on click, because the
// in-place edit form can replace it.
function setUpCopyBoxes() {
  document.querySelectorAll("[data-copy-message]").forEach((button) => {
    const message = button.closest(".message");
    if (!message?.querySelector("[data-message-text]")) return;
    button.hidden = false;
    button.addEventListener("click", async () => {
      const text = message.querySelector("[data-message-text]");
      if (!text) return;
      // The mail's HTML view copies the text it shows (organization-mail.md "HTML view").
      const frame = message.querySelector("[data-mail-pane='html']:not([hidden]) iframe");
      let copied;
      if (frame?.contentDocument?.body) {
        copied = frame.contentDocument.body.innerText.trim();
      } else {
        // Addresses shown with a short label are copied in full (specs/markdown.md "Plain text links").
        const links = [...text.querySelectorAll("a[data-address]")];
        const labels = links.map((link) => link.textContent);
        links.forEach((link) => { link.textContent = link.getAttribute("href"); });
        // Closed earlier messages are copied too, without their summary lines
        // (organization-mail.md "Display of mail").
        const closed = [...text.querySelectorAll("details:not([open])")];
        const skipped = [...text.querySelectorAll("[data-copy-skip]")];
        closed.forEach((details) => { details.open = true; });
        skipped.forEach((element) => { element.hidden = true; });
        copied = text.innerText.trim();
        skipped.forEach((element) => { element.hidden = false; });
        closed.forEach((details) => { details.open = false; });
        links.forEach((link, index) => { link.textContent = labels[index]; });
      }
      // The request copies the ticket's facts before its text (specs/ui.md "Copy box").
      if (message.dataset.copyHeader) copied = `${message.dataset.copyHeader}\n\n${copied}`;
      await copyText(copied);
      button.classList.add("is-copied");
      button.title = button.dataset.copied;
      button.setAttribute("aria-label", button.dataset.copied);
      setTimeout(() => {
        button.classList.remove("is-copied");
        button.title = button.dataset.label;
        button.setAttribute("aria-label", button.dataset.label);
      }, 1500);
    }, { signal: pageSignal });
  });
}

// Each code block of a Markdown message gets a copy button in its corner
// (specs/markdown.md "Copy code"). The block is wrapped, so the button
// stays put while a long line scrolls; the message's copy box skips it.
function setUpCodeCopy(root = document) {
  const template = document.querySelector("template[data-code-copy]");
  if (!template) return;
  root.querySelectorAll(".markdown-body pre").forEach((pre) => {
    // A page restored from Turbo's cache keeps the wrapper but not the
    // listener: the expando below is not part of the snapshot.
    if (!pre.parentElement.classList.contains("code-block")) {
      const block = document.createElement("div");
      block.className = "code-block";
      pre.before(block);
      block.append(pre, template.content.firstElementChild.cloneNode(true));
    }
    const button = pre.parentElement.querySelector(".code-copy");
    if (!button || button.codeCopyReady) return;
    button.codeCopyReady = true;
    let timer;
    button.addEventListener("click", async () => {
      await copyText(pre.textContent.replace(/\n$/, ""));
      clearTimeout(timer);
      button.classList.add("is-copied");
      button.title = button.dataset.copied;
      button.setAttribute("aria-label", button.dataset.copied);
      timer = setTimeout(() => {
        button.classList.remove("is-copied");
        button.title = button.dataset.label;
        button.setAttribute("aria-label", button.dataset.label);
      }, 1500);
    });
  });
}

// Menu bar dropdowns (the notification panel) close on a click outside
// and on Escape, which returns focus to their button. They are looked up on
// each event, because a live refresh replaces the notification panel.
function setUpDropdowns() {
  const dropdowns = () => document.querySelectorAll("details[data-dropdown]");
  document.addEventListener("click", (event) => {
    dropdowns().forEach((dropdown) => { if (dropdown.open && !dropdown.contains(event.target)) dropdown.open = false; });
  }, { signal: pageSignal });
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    dropdowns().forEach((dropdown) => {
      if (!dropdown.open) return;
      dropdown.open = false;
      dropdown.querySelector("summary").focus();
    });
  }, { signal: pageSignal });
}

// Live notification panel (specs/notifications.md): the server only says
// that something changed; the panel is fetched again over HTTP, so the
// usual sign-in and visibility checks apply. Signals are coalesced, and an
// open panel is left alone until it is closed. The notifications page
// reloads itself instead, unless only this tab's own request caused it.
let notificationsTimer = null;
let notificationsRequestId;

function scheduleNotificationsRefresh() {
  const requestId = this?.getAttribute?.("request-id") || "";
  if (notificationsTimer === null) notificationsRequestId = requestId;
  else if (notificationsRequestId !== requestId) notificationsRequestId = "";
  clearTimeout(notificationsTimer);
  notificationsTimer = setTimeout(refreshNotifications, 300);
}

async function refreshNotifications() {
  notificationsTimer = null;
  if (document.querySelector("[data-notifications-page]")) {
    const stream = document.createElement("turbo-stream");
    stream.setAttribute("action", "refresh");
    if (notificationsRequestId) stream.setAttribute("request-id", notificationsRequestId);
    window.Turbo?.renderStreamMessage(stream.outerHTML);
    return;
  }
  const current = document.querySelector("[data-notifications]");
  if (!current) return;
  if (current.open) {
    current.addEventListener("toggle", scheduleNotificationsRefresh, { once: true });
    return;
  }
  let response;
  try {
    response = await fetch(current.dataset.panelUrl, { headers: { Accept: "text/html" }, credentials: "same-origin" });
  } catch {
    return;
  }
  if (!response.ok) return;
  const template = document.createElement("template");
  template.innerHTML = (await response.text()).trim();
  const fresh = template.content.querySelector("[data-notifications]");
  const latest = document.querySelector("[data-notifications]");
  if (fresh && latest && !latest.open) latest.replaceWith(fresh);
}

// Viewer count of a shared link (specs/sharing.md "Who is viewing now"):
// the signal carries only the number; the text comes from the page.
function updateShareViewers() {
  const count = Math.max(Number(this.getAttribute("count")) || 0, 0);
  document.querySelectorAll("[data-share-viewers]").forEach((label) => {
    const key = count === 0 && label.dataset.zero ? "zero" : count <= 1 ? "one" : "other";
    label.textContent = label.dataset[key].replace("%{count}", count);
    label.closest(".share-viewers").dataset.count = count;
  });
}

// Who is online now (specs/presence.md): the signal only says that something
// changed; each staff page fetches its own view (its language, its scope,
// without the reader) and lets Turbo replace the button, the list and a
// ticket's viewers line. Pages wait a moment, not all at once.
let presenceTimer = null;

function schedulePresenceRefresh() {
  clearTimeout(presenceTimer);
  presenceTimer = setTimeout(refreshPresence, 200 + Math.random() * 400);
}

async function refreshPresence() {
  presenceTimer = null;
  const menu = document.querySelector("[data-presence]");
  if (!menu) return;
  const url = new URL(menu.dataset.presenceUrl, location.href);
  const ticket = document.querySelector("[data-ticket-page]")?.dataset.ticket;
  if (ticket) url.searchParams.set("ticket", ticket);
  let response;
  try {
    response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" }, credentials: "same-origin" });
  } catch {
    return;
  }
  if (response.ok) window.Turbo?.renderStreamMessage(await response.text());
}

function registerStreamActions() {
  if (!window.Turbo?.StreamActions) return;
  window.Turbo.StreamActions.notifications_refresh = scheduleNotificationsRefresh;
  window.Turbo.StreamActions.share_viewers = updateShareViewers;
  window.Turbo.StreamActions.presence_refresh = schedulePresenceRefresh;
}

registerStreamActions();

// Live page refreshes (specs/timeline.md, specs/sharing.md) never throw
// away work in progress: while the page is busy the refresh waits, a
// notice says so, and it runs once the page is idle (checked every second).
function pageIsBusy() {
  if (document.querySelector(".board-card.is-dragging")) return true;
  const active = document.activeElement;
  if (active && active.matches("input:not([type=hidden]):not([readonly]), textarea, select")) return true;
  if (document.querySelector("details[open], dialog[open]")) return true;
  return Array.from(document.querySelectorAll("input:not([type=hidden]), textarea, select")).some((field) => {
    if (field.type === "file") return field.files.length > 0;
    if (field.type === "checkbox" || field.type === "radio") return field.checked !== field.defaultChecked;
    if (field.tagName === "SELECT") {
      // Without a selected attribute a single select starts on its first option.
      const options = Array.from(field.options);
      if (!field.multiple && !options.some((option) => option.defaultSelected)) return field.selectedIndex > 0;
      return options.some((option) => option.selected !== option.defaultSelected);
    }
    return field.value !== field.defaultValue;
  });
}

let heldRefresh = null;

document.addEventListener("turbo:before-stream-render", (event) => {
  if (event.target.getAttribute("action") !== "refresh") return;
  const render = event.detail.render;
  event.detail.render = async (stream) => {
    if (!pageIsBusy()) return render(stream);
    if (heldRefresh) return;
    document.querySelectorAll("[data-live-notice]").forEach((notice) => { notice.hidden = false; });
    heldRefresh = setInterval(() => {
      if (pageIsBusy()) return;
      clearInterval(heldRefresh);
      heldRefresh = null;
      render(stream);
    }, 1000);
  };
});

// Attachment preview (specs/attachments.md "Preview"): one <dialog> per
// page, filled from the clicked [data-preview-item] link. Arrow keys move
// between files; Escape closes. Modified clicks still download.
function setUpPreview(dialog) {
  const items = [...document.querySelectorAll("[data-preview-item]")];
  if (!dialog || items.length === 0) return;

  const media = dialog.querySelector("[data-preview-media]");
  const caption = dialog.querySelector("[data-preview-caption]");
  const meta = dialog.querySelector("[data-preview-meta]");
  const count = dialog.querySelector("[data-preview-count]");
  const download = dialog.querySelector("[data-preview-download]");
  const navButtons = dialog.querySelectorAll("[data-preview-prev], [data-preview-next]");
  let index = 0;

  const message = (text) => {
    const p = document.createElement("p");
    p.className = "preview__none";
    p.textContent = text;
    return p;
  };

  const render = (kind, url, name) => {
    switch (kind) {
      case "image": {
        const img = document.createElement("img");
        img.src = url;
        img.alt = name;
        // Scaled down to fit, the image becomes a button for its actual size
        // (specs/attachments.md "Image size").
        img.addEventListener("load", () => {
          const box = img.getBoundingClientRect();
          if (img.naturalWidth <= Math.ceil(box.width / pageZoom()) + 1 &&
              img.naturalHeight <= Math.ceil(box.height / pageZoom()) + 1) return;
          const button = document.createElement("button");
          button.type = "button";
          button.className = "preview__zoom";
          const label = (actual) => {
            button.setAttribute("aria-pressed", String(actual));
            button.setAttribute("aria-label", actual ? dialog.dataset.fitLabel : dialog.dataset.actualLabel);
            button.title = button.getAttribute("aria-label");
          };
          label(false);
          img.replaceWith(button);
          button.append(img);
          button.addEventListener("click", () => {
            const actual = !media.classList.contains("is-actual");
            media.classList.toggle("is-actual", actual);
            label(actual);
          });
        }, { once: true });
        return img;
      }
      case "pdf": {
        const frame = document.createElement("iframe");
        frame.src = url;
        frame.title = name;
        return frame;
      }
      case "text": {
        const pre = document.createElement("pre");
        fetch(url, { credentials: "same-origin" })
          .then((response) => (response.ok ? response.text() : Promise.reject(response.status)))
          .then((text) => { pre.textContent = text; })
          .catch(() => pre.replaceWith(message(dialog.dataset.loadError)));
        return pre;
      }
      default:
        return message(dialog.dataset.noPreview);
    }
  };

  const show = (i) => {
    index = (i + items.length) % items.length;
    const item = items[index];
    const { previewKind, previewUrl, filename, details } = item.dataset;
    media.classList.remove("is-actual");
    dialog.classList.toggle("preview--image", previewKind === "image");
    media.replaceChildren(render(previewKind, previewUrl, filename));
    caption.textContent = filename;
    meta.textContent = details;
    count.textContent = items.length > 1 ? `${index + 1} / ${items.length}` : "";
    download.href = item.href;
    navButtons.forEach((button) => { button.hidden = items.length < 2; });
  };

  items.forEach((item, i) => {
    item.addEventListener("click", (event) => {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      show(i);
      dialog.showModal();
    }, { signal: pageSignal });
  });

  dialog.querySelector("[data-preview-close]").addEventListener("click", () => dialog.close(), { signal: pageSignal });
  dialog.querySelector("[data-preview-prev]").addEventListener("click", () => show(index - 1), { signal: pageSignal });
  dialog.querySelector("[data-preview-next]").addEventListener("click", () => show(index + 1), { signal: pageSignal });
  // A click on the backdrop lands on the dialog element itself.
  dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); }, { signal: pageSignal });
  dialog.addEventListener("keydown", (event) => {
    if (event.key === "ArrowLeft") show(index - 1);
    if (event.key === "ArrowRight") show(index + 1);
  }, { signal: pageSignal });
  // Emptying the media frees large images and stops a PDF viewer.
  dialog.addEventListener("close", () => media.replaceChildren(), { signal: pageSignal });
}

// Task lists (specs/markdown.md "Task lists"): editors tick check boxes in
// place; the server flips the "[ ]" on that line and saves it as an edit.
// Turbo's fetch carries a request id, so this tab skips its own refresh.
// "Hide" on a machine translation removes it from this page; without
// JavaScript the button stays hidden (specs/translation.md).
// "Hide" folds a translation back to the Translate button, which shows the
// stored translation again (specs/translation.md); kept across refreshes.
const hiddenTranslations = new Set();

function setUpTranslations() {
  document.querySelectorAll("[data-translation-hide]").forEach((button) => {
    const block = button.closest("[data-translation]");
    const key = `${location.pathname}#${block.dataset.translation}`;
    const show = document.querySelector(`[data-translation-show="${block.dataset.translation}"]`);
    const toggle = (hidden) => {
      block.hidden = hidden;
      if (show) show.hidden = !hidden;
      if (hidden) hiddenTranslations.add(key); else hiddenTranslations.delete(key);
    };
    button.hidden = false;
    button.addEventListener("click", () => { toggle(true); show?.focus(); }, { signal: pageSignal });
    show?.addEventListener("click", () => { toggle(false); button.focus(); }, { signal: pageSignal });
    toggle(hiddenTranslations.has(key));
  });
}

// Reports charts (specs/reports.md): one tooltip per date group on hover
// and focus, built with textContent from the group's data-rows
// ([series, name, value], ...); the tables under the charts have the same
// numbers without it.
function setUpReportCharts() {
  document.querySelectorAll("[data-report-chart]").forEach((chart) => {
    const plot = chart.querySelector(".report-chart__plot");
    const tooltip = chart.querySelector("[data-chart-tooltip]");
    const show = (group) => {
      tooltip.replaceChildren();
      const title = document.createElement("div");
      title.textContent = group.dataset.label;
      tooltip.append(title);
      JSON.parse(group.dataset.rows).forEach(([ series, name, value ]) => {
        const row = document.createElement("div");
        row.className = "report-chart__tooltip-row";
        const key = document.createElement("span");
        key.className = `report-chart__tooltip-key report-legend__key--${series}`;
        const number = document.createElement("strong");
        number.textContent = String(value);
        const label = document.createElement("span");
        label.textContent = name;
        row.append(key, number, label);
        tooltip.append(row);
      });
      tooltip.hidden = false;
      const box = plot.getBoundingClientRect();
      const mark = group.getBoundingClientRect();
      const left = mark.left - box.left + mark.width / 2 - tooltip.offsetWidth / 2;
      tooltip.style.left = `${Math.max(0, Math.min(left, box.width - tooltip.offsetWidth))}px`;
    };
    const hide = () => { tooltip.hidden = true; };
    chart.querySelectorAll("[data-chart-group]").forEach((group) => {
      group.addEventListener("pointerenter", () => show(group));
      group.addEventListener("focus", () => show(group));
      group.addEventListener("pointerleave", hide);
      group.addEventListener("blur", hide);
    });
  });
}

function setUpTaskLists() {
  document.querySelectorAll("[data-task-path] input[type=checkbox][data-task-line]").forEach((box) => {
    box.disabled = false;
    box.addEventListener("change", async () => {
      const body = new FormData();
      // POST with _method like Rails forms: the server's WAF allows only
      // GET, HEAD, POST and OPTIONS (specs/deploy.md "ModSecurity").
      body.append("_method", "patch");
      body.append("line", box.dataset.taskLine);
      body.append("checked", box.checked ? "1" : "0");
      const token = document.querySelector("meta[name=csrf-token]")?.content;
      let ok = false;
      try {
        const send = window.Turbo?.fetch || window.fetch;
        const response = await send(box.closest("[data-task-path]").dataset.taskPath, {
          method: "POST", body, credentials: "same-origin", headers: { "X-CSRF-Token": token, Accept: "text/html" }
        });
        ok = response.ok;
      } catch {}
      // A saved tick is not work in progress for the live refresh check.
      if (ok) box.defaultChecked = box.checked;
      else box.checked = !box.checked;
    }, { signal: pageSignal });
  });
}

// Double-click to edit (specs/timeline.md "Editing"): opens the in-place
// form of a message the user may edit, with the caret near the click. The
// visible text before the click is matched against the plain text without
// white space and Markdown punctuation, so syntax and paragraph breaks do
// not get in the way.
const CARET_SKIP = /[\s*_~`|#>[\]()!\\-]/;

function textBeforePoint(element, x, y) {
  let node;
  let offset;
  if (document.caretPositionFromPoint) {
    const position = document.caretPositionFromPoint(x, y);
    node = position?.offsetNode;
    offset = position?.offset;
  } else if (document.caretRangeFromPoint) {
    const range = document.caretRangeFromPoint(x, y);
    node = range?.startContainer;
    offset = range?.startOffset;
  }
  if (!node || !element.contains(node)) return null;
  const before = document.createRange();
  before.selectNodeContents(element);
  before.setEnd(node, offset);
  return before.toString();
}

function caretOffset(source, before) {
  if (before === null) return source.length;
  const visible = [...before].filter((char) => !CARET_SKIP.test(char)).join("");
  if (!visible) return 0;
  const map = [];
  let compact = "";
  for (let i = 0; i < source.length; i++) {
    if (CARET_SKIP.test(source[i])) continue;
    compact += source[i];
    map.push(i);
  }
  for (let length = Math.min(30, visible.length); length >= 3; length = Math.floor(length / 2)) {
    const piece = visible.slice(-length);
    let best = -1;
    for (let at = compact.indexOf(piece); at !== -1; at = compact.indexOf(piece, at + 1)) {
      if (best === -1 || Math.abs(at + length - visible.length) < Math.abs(best + length - visible.length)) best = at;
    }
    if (best !== -1) return map[best + length - 1] + 1;
  }
  return source.length;
}

function setUpDoubleClickEdit() {
  document.addEventListener("dblclick", (event) => {
    const text = event.target.closest?.("[data-message-text]");
    if (!text || event.target.closest("a, input, button, summary")) return;
    const link = text.closest(".message")?.querySelector(".message__bar a.edit-link");
    const frame = text.closest("turbo-frame");
    if (!link || !frame) return;
    const before = textBeforePoint(text, event.clientX, event.clientY);
    window.getSelection()?.removeAllRanges();
    frame.addEventListener("turbo:frame-load", () => {
      const field = frame.querySelector("textarea");
      if (!field) return;
      const at = caretOffset(field.value, before);
      field.focus({ preventScroll: true });
      field.setSelectionRange(at, at);
    }, { once: true });
    link.click();
  }, { signal: pageSignal });

  // Ctrl/Cmd+Enter saves an edit form. Escape cancels an unchanged one; a
  // changed one is left alone.
  document.addEventListener("keydown", (event) => {
    const form = event.target.closest?.("form.edit-form");
    if (!form) return;
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit();
      return;
    }
    if (event.key !== "Escape") return;
    const changed = [...form.querySelectorAll("input:not([type=hidden]), textarea")].some((field) => field.value !== field.defaultValue);
    if (!changed) form.querySelector(".edit-form__actions a")?.click();
  }, { signal: pageSignal });
}

// Message form (specs/notifications.md "Messages from administrators"):
// how many people the chosen recipients reach.
function setUpMessageForm(select) {
  const hint = document.querySelector("[data-recipient-count]");
  if (!hint) return;
  const show = () => {
    const option = select.selectedOptions[0];
    if (!option || !option.value) { hint.textContent = ""; return; }
    const count = Number(option.dataset.count || 0);
    const key = count === 0 ? "zero" : count === 1 ? "one" : "other";
    hint.textContent = hint.dataset[key].replace("%{count}", count);
  };
  select.addEventListener("change", show, { signal: pageSignal });
  show();
}

// A long original request is cut to about a third of the window with a
// button to open it (specs/timeline.md "Long requests collapse"). Opened
// requests stay open for this page across live refreshes and edits.
const openedRequests = new Set();

function setUpLongRequest() {
  const article = document.querySelector("[data-long-request]");
  // The mail's HTML view when it is shown, else the text (organization-mail.md "HTML view").
  const text = article?.querySelector("[data-mail-pane='html']:not([hidden])") || article?.querySelector("[data-message-text]");
  if (!text) return;
  article.querySelector(".long-request__toggle")?.remove();
  article.querySelectorAll(".is-collapsed").forEach((node) => node.classList.remove("is-collapsed"));
  const height = Math.round(Math.max(window.innerHeight / pageZoom() * 0.35, 200));
  if (text.scrollHeight <= height * 1.3) return;

  const key = location.pathname;
  text.id ||= "request-text";
  text.style.setProperty("--collapsed-height", `${height}px`);
  const button = document.createElement("button");
  button.type = "button";
  button.className = "long-request__toggle";
  button.setAttribute("aria-controls", text.id);
  const show = (open) => {
    text.classList.toggle("is-collapsed", !open);
    button.setAttribute("aria-expanded", String(open));
    button.textContent = open ? article.dataset.less : article.dataset.more;
  };
  button.addEventListener("click", () => {
    const open = button.getAttribute("aria-expanded") !== "true";
    if (open) openedRequests.add(key); else openedRequests.delete(key);
    show(open);
    if (!open) article.scrollIntoView({ block: "nearest" });
  }, { signal: pageSignal });
  text.after(button);
  show(openedRequests.has(key));
}

// Runs of event lines between messages fold into one line
// (specs/timeline.md "Event lines between messages fold"). Opened runs stay
// open for this page across live refreshes; a link to a line opens its run.
const openedEventRuns = new Set();
let eventRunTargetSeen = null;

function setUpEventRuns() {
  // A link opens its run once; a live refresh with the same address does not reopen it.
  const fresh = location.href !== eventRunTargetSeen;
  eventRunTargetSeen = location.href;
  const target = fresh && location.hash.startsWith("#event-") ? document.getElementById(location.hash.slice(1)) : null;
  document.querySelectorAll("[data-event-run]").forEach((run) => {
    const button = run.querySelector(".timeline__run-toggle");
    const key = `${location.pathname}#${run.dataset.eventRun}`;
    const show = (open) => {
      run.classList.toggle("is-folded", !open);
      button.setAttribute("aria-expanded", String(open));
    };
    button.addEventListener("click", () => {
      const open = button.getAttribute("aria-expanded") !== "true";
      if (open) openedEventRuns.add(key); else openedEventRuns.delete(key);
      show(open);
    }, { signal: pageSignal });
    button.hidden = false;
    if (target && run.contains(target) && !openedEventRuns.has(key)) {
      openedEventRuns.add(key);
      show(true);
      target.scrollIntoView({ block: "center" });
    } else {
      show(openedEventRuns.has(key));
    }
  });
}

window.addEventListener("hashchange", () => {
  const target = location.hash.startsWith("#event-") ? document.getElementById(location.hash.slice(1)) : null;
  const button = target?.closest("[data-event-run].is-folded")?.querySelector(".timeline__run-toggle");
  if (!button) return;
  button.click();
  target.scrollIntoView({ block: "center" });
});

// The mail's HTML in a sealed frame with tabs to the text
// (specs/organization-mail.md "HTML view"). The frame may be read from
// here (allow-same-origin, no scripts inside), so it grows to its content.
function setUpMailView() {
  document.querySelectorAll("[data-mail-view]").forEach((view) => {
    const tabs = view.querySelector("[data-mail-tabs]");
    const frame = view.querySelector("[data-mail-frame]");
    const panes = { html: view.querySelector("[data-mail-pane='html']"), text: document.getElementById(view.dataset.textPane || "mail-pane-text") };
    const fit = () => {
      const root = frame.contentDocument?.documentElement;
      if (!root || frame.contentDocument.URL === "about:blank") return;
      // Shrink first: a document is never shorter than its frame.
      frame.style.height = "1px";
      frame.style.height = `${root.scrollHeight + 2}px`;
    };
    const show = (name) => {
      Object.entries(panes).forEach(([key, pane]) => { if (pane) pane.hidden = key !== name; });
      tabs.querySelectorAll("[data-mail-tab]").forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.mailTab === name)));
      if (name === "html") fit();
      setUpLongRequest();
    };
    tabs.hidden = false;
    frame.addEventListener("load", () => { fit(); setUpLongRequest(); }, { signal: pageSignal });
    tabs.addEventListener("click", (event) => {
      const tab = event.target.closest("[data-mail-tab]");
      if (tab) show(tab.dataset.mailTab);
    }, { signal: pageSignal });
    show("html");
  });
}

// Shift+click on a check box ticks or clears every box between it and
// the one clicked before, as in a mail program (specs/ui.md "Check box
// lists"). A list is the boxes that share a name ending in [] and a
// form; hidden rows (a narrowed member picker) are left alone. Each box
// that changes fires "change", so counters and bars follow.
let lastChecked = null;
document.addEventListener("click", (event) => {
  const box = event.target;
  if (!(box instanceof HTMLInputElement) || box.type !== "checkbox" || !box.name.endsWith("[]")) return;
  const previous = lastChecked;
  lastChecked = box;
  if (!event.shiftKey || !previous || previous === box || !previous.isConnected) return;
  if (previous.name !== box.name || previous.form !== box.form) return;

  const boxes = [...document.querySelectorAll('input[type="checkbox"]')].filter((other) =>
    other.name === box.name && other.form === box.form && !other.disabled && other.getClientRects().length > 0);
  const from = boxes.indexOf(previous);
  const to = boxes.indexOf(box);
  if (from < 0 || to < 0) return;
  boxes.slice(Math.min(from, to), Math.max(from, to) + 1).forEach((other) => {
    if (other.checked === box.checked) return;
    other.checked = box.checked;
    other.dispatchEvent(new Event("change", { bubbles: true }));
  });
  // Shift+click on a label would also select the text in between.
  window.getSelection()?.removeAllRanges();
});

// Bulk actions of the queue (specs/queues.md "Bulk actions"): the bar
// shows once a row is selected and offers the whole list when the whole
// page is selected.
function setUpBulkActions() {
  const form = document.querySelector("[data-bulk-form]");
  const page = document.querySelector("[data-bulk-page]");
  if (!form || !page) return;
  const rows = [...document.querySelectorAll("[data-bulk-row]")];
  const all = form.querySelector("[data-bulk-all]");
  const clear = form.querySelector("[data-bulk-clear]");
  const scope = form.querySelector("[data-bulk-scope]");
  const count = form.querySelector("[data-bulk-count]");
  const update = () => {
    const selected = rows.filter((row) => row.checked).length;
    const whole = scope.value === "list";
    form.hidden = selected === 0 && !whole;
    page.checked = selected === rows.length;
    page.indeterminate = selected > 0 && selected < rows.length;
    if (all) all.hidden = whole || selected !== rows.length;
    clear.hidden = false;
    const label = whole ? form.dataset.allSelected : (selected === 1 ? form.dataset.selectedOne : form.dataset.selectedOther);
    count.textContent = label.replace("%{count}", selected);
    rows.forEach((row) => row.closest("tr")?.classList.toggle("is-selected", row.checked || whole));
  };
  const choose = (checked) => {
    rows.forEach((row) => { row.checked = checked; });
    scope.value = "selected";
    update();
  };
  rows.forEach((row) => row.addEventListener("change", () => { scope.value = "selected"; update(); }, { signal: pageSignal }));
  page.addEventListener("change", () => choose(page.checked), { signal: pageSignal });
  clear.addEventListener("click", () => choose(false), { signal: pageSignal });
  all?.addEventListener("click", () => { scope.value = "list"; update(); }, { signal: pageSignal });
  update();
}

// The organization flush button stays off until the exact name is typed
// (specs/admin.md "Flush all tickets of an organization"); the server
// checks it again.
function setUpFlushConfirm() {
  document.querySelectorAll("[data-flush-name]").forEach((field) => {
    const button = field.form.querySelector("[data-flush-button]");
    const update = () => { button.disabled = field.value.trim() !== field.dataset.flushName; };
    field.addEventListener("input", update, { signal: pageSignal });
    update();
  });
}

// The member picker on an organization page (specs/admin.md "Adding
// members"): typing narrows the list, the button counts the ticked users.
function setUpMemberPicker() {
  document.querySelectorAll("[data-member-picker]").forEach((form) => {
    const search = form.querySelector("[data-picker-search]");
    const rows = [...form.querySelectorAll("[data-picker-row]")];
    const empty = form.querySelector("[data-picker-empty]");
    const submit = form.querySelector("[data-picker-submit]");
    form.querySelector("[data-picker-search-wrap]").hidden = false;
    const count = () => {
      const ticked = rows.filter((row) => row.querySelector("[data-picker-check]").checked).length;
      submit.disabled = ticked === 0;
      const label = ticked === 1 ? form.dataset.buttonOne : form.dataset.buttonOther;
      submit.value = label.replace("%{count}", ticked);
      rows.forEach((row) => row.classList.toggle("is-picked", row.querySelector("[data-picker-check]").checked));
    };
    const narrow = () => {
      const words = search.value.toLowerCase().split(/\s+/).filter(Boolean);
      let shown = 0;
      rows.forEach((row) => {
        const match = words.every((word) => row.dataset.search.includes(word));
        row.hidden = !match;
        if (match) shown += 1;
      });
      empty.hidden = shown > 0;
    };
    search.addEventListener("input", narrow, { signal: pageSignal });
    // Enter in the search field must not add anyone.
    search.addEventListener("keydown", (event) => { if (event.key === "Enter") event.preventDefault(); }, { signal: pageSignal });
    form.addEventListener("change", count, { signal: pageSignal });
    count();
  });
}

// A select whose list can grow long becomes a text field with a list that
// narrows as you type (specs/ui.md "Searchable selects"). The select stays
// in the form, hidden: it holds and sends the value, and its change event
// still drives dependent scripts and the filters that send on change.
function setUpCombobox(select) {
  // A page restored from Turbo's cache still holds the last field: rebuild it.
  select.parentElement.querySelector(`:scope > [data-combobox-for="${select.id}"]`)?.remove();
  select.hidden = false;

  const id = select.id || `combobox-${Math.random().toString(36).slice(2)}`;
  select.id = id;
  const wrap = document.createElement("div");
  wrap.className = "combobox";
  wrap.dataset.comboboxFor = id;
  const input = document.createElement("input");
  input.type = "text";
  input.id = `${id}-combobox`;
  input.className = `${select.className} combobox__input`;
  input.autocomplete = "off";
  input.spellcheck = false;
  input.setAttribute("role", "combobox");
  input.setAttribute("aria-autocomplete", "list");
  input.setAttribute("aria-expanded", "false");
  input.setAttribute("aria-controls", `${id}-listbox`);
  ["aria-invalid", "aria-describedby"].forEach((name) => {
    if (select.hasAttribute(name)) input.setAttribute(name, select.getAttribute(name));
  });
  input.disabled = select.disabled;
  const list = document.createElement("ul");
  list.id = `${id}-listbox`;
  list.className = "combobox__list";
  list.setAttribute("role", "listbox");
  list.hidden = true;
  const empty = document.createElement("p");
  empty.className = "combobox__empty";
  empty.textContent = select.dataset.comboboxEmpty || "";
  empty.hidden = true;
  wrap.append(input, list, empty);
  select.before(wrap);
  select.hidden = true;
  document.querySelectorAll(`label[for="${id}"]`).forEach((label) => { label.htmlFor = input.id; });
  if (!input.hasAttribute("aria-label") && !document.querySelector(`label[for="${input.id}"]`)) {
    input.setAttribute("aria-label", select.getAttribute("aria-label") || "");
  }

  const options = () => [...select.options].filter((option) => !option.hidden && !option.disabled);
  const blank = () => [...select.options].find((option) => option.value === "");
  const shownText = (option) => option?.text || "";
  // As wide as the longest option, like a select (not the size attribute:
  // CSS reads that as a list box).
  const longest = Math.max(0, ...[...select.options].map((option) => option.text.length));
  input.style.setProperty("--combobox-chars", Math.min(Math.max(longest, 8), 30));
  input.placeholder = blank()?.text || "";
  input.value = shownText(select.selectedOptions[0]);
  input.defaultValue = input.value;

  let rows = [];
  let active = -1;
  const setActive = (index) => {
    rows.forEach((row, i) => row.classList.toggle("is-active", i === index));
    active = index;
    if (index >= 0) {
      input.setAttribute("aria-activedescendant", rows[index].id);
      rows[index].scrollIntoView({ block: "nearest" });
    } else {
      input.removeAttribute("aria-activedescendant");
    }
  };
  const render = (query) => {
    const words = query.toLowerCase().split(/\s+/).filter(Boolean);
    const matches = options().filter((option) => {
      if (option.value === "") return words.length === 0;
      const haystack = `${option.text} ${option.dataset.detail || ""}`.toLowerCase();
      return words.every((word) => haystack.includes(word));
    });
    list.replaceChildren();
    rows = matches.map((option, i) => {
      const row = document.createElement("li");
      row.id = `${list.id}-${i}`;
      row.className = "combobox__option";
      row.setAttribute("role", "option");
      row.setAttribute("aria-selected", String(option.selected));
      row.dataset.value = option.value;
      const text = document.createElement("span");
      text.className = "combobox__text";
      text.textContent = option.text;
      row.append(text);
      if (option.dataset.detail) {
        const detail = document.createElement("span");
        detail.className = "combobox__detail";
        detail.textContent = option.dataset.detail;
        row.append(detail);
      }
      list.append(row);
      return row;
    });
    empty.hidden = rows.length > 0;
    const selected = rows.findIndex((row) => row.getAttribute("aria-selected") === "true");
    setActive(words.length ? (rows.length ? 0 : -1) : selected);
  };
  const open = (query = "") => {
    render(query);
    list.hidden = rows.length === 0;
    input.setAttribute("aria-expanded", String(rows.length > 0));
  };
  const isOpen = () => !list.hidden || !empty.hidden;
  const close = () => {
    list.hidden = true;
    empty.hidden = true;
    input.setAttribute("aria-expanded", "false");
    setActive(-1);
  };
  const choose = (value) => {
    const changed = select.value !== value;
    select.value = value;
    input.value = shownText(select.selectedOptions[0]);
    input.setCustomValidity("");
    close();
    if (changed) select.dispatchEvent(new Event("change", { bubbles: true }));
  };
  // Leaving the field: an empty field chooses the blank option; text that
  // names no option gives way to the chosen text.
  const settle = () => {
    if (input.value.trim() === "" && blank()) {
      choose("");
    } else {
      input.value = shownText(select.selectedOptions[0]);
      close();
    }
  };

  // Focus selects the text, so typing replaces it; a click that gives the
  // focus must not put the caret in place of that selection.
  let keepSelection = false;
  input.addEventListener("mousedown", () => { keepSelection = document.activeElement !== input; }, { signal: pageSignal });
  input.addEventListener("mouseup", (event) => {
    if (keepSelection) event.preventDefault();
    keepSelection = false;
  }, { signal: pageSignal });
  input.addEventListener("focus", () => { input.select(); open(); }, { signal: pageSignal });
  input.addEventListener("click", () => { if (!isOpen()) open(); }, { signal: pageSignal });
  input.addEventListener("input", () => {
    input.setCustomValidity("");
    open(input.value);
  }, { signal: pageSignal });
  input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      if (!isOpen()) return open(input.value === shownText(select.selectedOptions[0]) ? "" : input.value);
      if (rows.length) setActive((active + (event.key === "ArrowDown" ? 1 : rows.length - 1)) % rows.length);
    } else if (event.key === "Enter" && isOpen()) {
      event.preventDefault();
      if (active >= 0) choose(rows[active].dataset.value);
    } else if (event.key === "Escape" && isOpen()) {
      event.preventDefault();
      input.value = shownText(select.selectedOptions[0]);
      close();
    }
  }, { signal: pageSignal });
  input.addEventListener("blur", settle, { signal: pageSignal });
  // A press on the list must not take the focus from the field first.
  list.addEventListener("mousedown", (event) => event.preventDefault(), { signal: pageSignal });
  list.addEventListener("click", (event) => {
    const row = event.target.closest(".combobox__option");
    if (row) choose(row.dataset.value);
  }, { signal: pageSignal });
  // The hidden select's required check is shown on the field.
  select.addEventListener("invalid", (event) => {
    event.preventDefault();
    input.setCustomValidity(select.validationMessage);
    input.reportValidity();
  }, { signal: pageSignal });
  // Scripts that change the select (or disable it) show on the field.
  select.addEventListener("change", () => {
    input.value = shownText(select.selectedOptions[0]);
    input.disabled = select.disabled;
  }, { signal: pageSignal });
}

function setUpPage() {
  registerStreamActions();
  clearInterval(heldRefresh);
  heldRefresh = null;
  pageAbort?.abort();
  pageAbort = new AbortController();
  pageSignal = pageAbort.signal;

  document.querySelectorAll("textarea[data-autogrow]").forEach(autoGrow);
  setUpConfirm(document.querySelector("[data-confirm-dialog]"));
  setUpPreview(document.querySelector("[data-preview-dialog]"));
  document.querySelectorAll("[data-composer]").forEach(setUpComposer);
  document.querySelectorAll("[data-requester-mail]").forEach(setUpRequesterMail);
  document.querySelectorAll("[data-password-field]").forEach(setUpPasswordField);
  document.querySelectorAll("[data-dropzone]").forEach(setUpDropzone);
  setUpAssignMenus(document.querySelectorAll("details[data-assign-menu]"));
  setUpCopyButtons();
  setUpCopyBoxes();
  setUpCodeCopy();
  setUpMailView();
  setUpLongRequest();
  setUpEventRuns();
  setUpBulkActions();
  setUpFlushConfirm();
  setUpMemberPicker();
  document.querySelectorAll("select[data-combobox]").forEach(setUpCombobox);
  setUpDoubleClickEdit();
  setUpTaskLists();
  setUpTranslations();
  setUpReportCharts();
  document.querySelectorAll("select[data-message-recipients]").forEach(setUpMessageForm);
  setUpDropdowns();
  setUpMenu(document.querySelector(".menubar"));
  setUpTicketOnPhones(document.querySelector("[data-ticket-page]"));

  document.querySelectorAll("select[data-requester-organizations]").forEach(setUpRequesterOrganizations);

  // Theme and text size apply at once; the cookie keeps them for the next page.
  document.querySelectorAll("form[data-preference]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      const button = event.submitter;
      // The language switch reloads the page in the new language.
      if (!button || !button.name || button.name === "locale") return;
      event.preventDefault();
      document.cookie = `${button.name}=${button.value}; path=/; max-age=31536000; samesite=lax`;
      document.documentElement.dataset[button.name] = button.value;
      if (button.name === "scale") {
        form.querySelectorAll("button[name=scale]").forEach((option) => {
          option.setAttribute("aria-pressed", option === button);
        });
      }
    });
  });

  // Filter selects in the queue and admin lists apply at once; without
  // JavaScript the queue has a <noscript> Apply button, admin lists their own.
  document.querySelectorAll("form[data-filter-form] select[data-auto-submit]").forEach((select) => {
    select.addEventListener("change", () => select.form.requestSubmit());
  });

  // Clearing a search field (the field's own x button) shows the list
  // without the search again; only when a search was shown, so clearing
  // typed text on another page does not leave it.
  document.querySelectorAll("form[data-filter-form] input[type=search], form[data-search-form] input[type=search]").forEach((field) => {
    field.addEventListener("search", () => {
      if (field.value === "" && field.defaultValue !== "") field.form.requestSubmit();
    });
  });

  document.querySelectorAll("[data-flash]").forEach(setUpFlash);
  document.querySelectorAll("[data-board]").forEach(setUpBoard);
}

// Notices go after a few seconds (not while hovered or focused); alerts
// stay until closed. Going: a sweep to the left, then the band closes
// (specs/ui.md "Flash messages").
function setUpFlash(flash) {
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let leaving = false;
  const dismiss = () => {
    if (leaving) return;
    leaving = true;
    if (reducedMotion) return flash.remove();
    flash.classList.add("is-leaving");
    setTimeout(() => {
      flash.style.height = `${flash.offsetHeight}px`;
      void flash.offsetHeight;
      flash.classList.add("is-collapsing");
      setTimeout(() => flash.remove(), 260);
    }, 500);
  };
  const close = flash.querySelector("[data-dismiss]");
  if (close) close.addEventListener("click", dismiss);
  if (flash.dataset.flashKind !== "notice") return;
  let timer = setTimeout(dismiss, 6000);
  const pause = () => clearTimeout(timer);
  const resume = () => { timer = setTimeout(dismiss, 3000); };
  flash.addEventListener("mouseenter", pause);
  flash.addEventListener("mouseleave", resume);
  flash.addEventListener("focusin", pause);
  flash.addEventListener("focusout", resume);
}

// An alert made by a script, in the same band and look as the server's.
function showAlert(text) {
  let stack = document.querySelector(".flash-stack");
  if (!stack) {
    stack = document.createElement("div");
    stack.className = "flash-stack";
    document.querySelector("main")?.prepend(stack);
  }
  const flash = document.createElement("div");
  flash.className = "sticky sticky--pink flash flash--alert";
  flash.setAttribute("role", "alert");
  flash.dataset.flash = "";
  flash.dataset.flashKind = "alert";
  flash.innerHTML = '<div class="sticky__bar"><button type="button" class="sticky__box" data-dismiss aria-label="x">&times;</button>' +
    '<span class="sticky__caption"></span><span class="sticky__box sticky__box--spacer" aria-hidden="true"></span></div><p class="flash__text"></p>';
  flash.querySelector(".flash__text").textContent = text;
  stack.append(flash);
  setUpFlash(flash);
}

// The kanban board (specs/board.md): columns expand and collapse (kept per
// browser), cards are dragged onto columns they may move to, and the move
// is a PATCH through Turbo's fetch, so this tab skips its own refresh.
function setUpBoard(board) {
  const key = "stopan-board-expanded";
  const columns = [...board.querySelectorAll("[data-board-column]")];
  const transitions = JSON.parse(board.dataset.transitions || "{}");
  let saved = null;
  try { saved = JSON.parse(localStorage.getItem(key)); } catch {}
  if (Array.isArray(saved)) {
    columns.forEach((column) => column.classList.toggle("is-collapsed", !saved.includes(column.dataset.key)));
  } else {
    // Without a remembered choice, empty columns start collapsed.
    columns.forEach((column) => { if (!column.querySelector("[data-board-card]")) column.classList.add("is-collapsed"); });
  }

  // The board fits the window from its top to the bottom edge, so its
  // sideways scrollbar stays in view (specs/board.md "Scrolling").
  const fit = () => {
    const zoom = pageZoom();
    const top = board.getBoundingClientRect().top + window.scrollY;
    board.style.setProperty("--board-height", `${Math.max(320, (window.innerHeight - top) / zoom - 12)}px`);
  };
  fit();
  window.addEventListener("resize", fit, { signal: pageSignal });

  // Dragging near the left or right edge scrolls the board that way.
  board.addEventListener("dragover", (event) => {
    if (!dragged) return;
    const box = board.getBoundingClientRect();
    if (event.clientX < box.left + 80) board.scrollLeft -= 18;
    else if (event.clientX > box.right - 80) board.scrollLeft += 18;
  }, { signal: pageSignal });
  const save = () => {
    try {
      localStorage.setItem(key, JSON.stringify(columns.filter((c) => !c.classList.contains("is-collapsed")).map((c) => c.dataset.key)));
    } catch {}
  };
  board.addEventListener("click", (event) => {
    const toggle = event.target.closest("[data-board-toggle]");
    if (!toggle) return;
    toggle.closest("[data-board-column]").classList.toggle("is-collapsed");
    save();
  }, { signal: pageSignal });

  // A column takes a card whose status may move to it, or another stage
  // (or the plain column) of the card's own status (specs/board.md).
  const droppable = (card, column) => {
    const sameStatus = column.dataset.status === card.dataset.status;
    if (!sameStatus) return card.dataset.allowed.split(" ").includes(column.dataset.status);
    return (column.dataset.stage || "") !== (card.dataset.stage || "");
  };

  // Ticked cards move together (specs/board.md "Several cards at once").
  const bar = document.querySelector("[data-board-bulk]");
  const checks = () => [...board.querySelectorAll("[data-board-check]")];
  const ticked = () => checks().filter((box) => box.checked).map((box) => box.closest("[data-board-card]"));
  const showSelection = () => {
    const cards = ticked();
    checks().forEach((box) => box.closest("[data-board-card]").classList.toggle("is-selected", box.checked));
    if (!bar) return;
    bar.hidden = cards.length === 0;
    const label = cards.length === 1 ? bar.dataset.selectedOne : bar.dataset.selectedOther;
    bar.querySelector("[data-board-count]").textContent = label.replace("%{count}", cards.length);
  };
  const clearSelection = () => {
    checks().forEach((box) => { box.checked = false; });
    showSelection();
  };
  board.addEventListener("change", (event) => { if (event.target.matches("[data-board-check]")) showSelection(); }, { signal: pageSignal });
  bar?.querySelector("[data-board-clear]").addEventListener("click", clearSelection, { signal: pageSignal });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && ticked().length && !document.querySelector("dialog[open]")) clearSelection();
  }, { signal: pageSignal });
  showSelection();

  // The cards being dragged: every ticked card when the dragged one is
  // ticked, else that card alone.
  let dragged = null;
  let group = [];
  let tag = null;
  const clear = () => {
    board.classList.remove("is-dragging-card");
    columns.forEach((column) => column.classList.remove("is-droppable", "is-refused", "is-over"));
    group.forEach((card) => card.classList.remove("is-dragging"));
    tag?.remove();
    tag = null;
    dragged = null;
    group = [];
  };
  board.addEventListener("dragstart", (event) => {
    const card = event.target.closest?.("[data-board-card]");
    if (!card) return;
    dragged = card;
    group = card.querySelector("[data-board-check]")?.checked ? ticked() : [ card ];
    group.forEach((one) => one.classList.add("is-dragging"));
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", group.map((one) => one.dataset.ticket).join(" "));
    if (group.length > 1) {
      // The pointer carries a tag with the number of tickets.
      tag = document.createElement("div");
      tag.className = "board-drag-tag";
      tag.textContent = board.dataset.dragCount.replace("%{count}", group.length);
      document.body.append(tag);
      event.dataTransfer.setDragImage(tag, 12, 12);
    }
    board.classList.add("is-dragging-card");
    columns.forEach((column) => {
      const ok = group.some((one) => droppable(one, column));
      const home = group.every((one) => column.dataset.status === one.dataset.status && (column.dataset.stage || "") === (one.dataset.stage || ""));
      column.classList.toggle("is-droppable", ok);
      column.classList.toggle("is-refused", !ok && !home);
    });
  }, { signal: pageSignal });
  board.addEventListener("dragend", clear, { signal: pageSignal });
  columns.forEach((column) => {
    column.addEventListener("dragover", (event) => {
      if (!dragged || !column.classList.contains("is-droppable")) return;
      event.preventDefault();
      column.classList.add("is-over");
    }, { signal: pageSignal });
    column.addEventListener("dragleave", (event) => {
      if (!column.contains(event.relatedTarget)) column.classList.remove("is-over");
    }, { signal: pageSignal });
    column.addEventListener("drop", async (event) => {
      if (!dragged || !column.classList.contains("is-droppable")) return;
      event.preventDefault();
      const cards = group;
      clear();
      const movable = cards.filter((card) => droppable(card, column));
      let moved = 0;
      // One after another, so the cards land in order and the counts stay right.
      for (const card of movable) {
        if (await moveCard(card, column, cards.length === 1)) moved += 1;
      }
      if (cards.length > 1) {
        clearSelection();
        if (moved < cards.length) {
          showAlert(board.dataset.someRefused.replace("%{count}", cards.length - moved).replace("%{total}", cards.length));
        }
      }
    }, { signal: pageSignal });
  });

  // A small panel with the start of the ticket while a card is hovered or
  // its subject link has the focus (specs/board.md "Preview on hover").
  const preview = document.querySelector("[data-card-preview]");
  if (preview) {
    const fetched = new Map();
    let timer = null;
    let shownFor = null;
    const hide = () => {
      clearTimeout(timer);
      timer = null;
      if (!shownFor) return;
      shownFor.querySelector(".board-card__title a")?.removeAttribute("aria-describedby");
      shownFor = null;
      preview.hidden = true;
    };
    const place = (card) => {
      const box = card.getBoundingClientRect();
      const zoom = pageZoom();
      const width = Math.min(380, window.innerWidth / zoom - 24);
      preview.style.width = `${width}px`;
      const right = box.right / zoom + 10;
      const left = right + width <= window.innerWidth / zoom - 8 ? right : Math.max(8, box.left / zoom - width - 10);
      preview.style.left = `${left}px`;
      preview.style.top = "0px";
      const height = preview.offsetHeight;
      preview.style.top = `${Math.max(8, Math.min(box.top / zoom, window.innerHeight / zoom - height - 8))}px`;
    };
    const show = async (card) => {
      if (dragged || board.querySelector("details[open]")) return;
      const url = card.dataset.previewUrl;
      if (!fetched.has(url)) {
        fetched.set(url, fetch(url, { credentials: "same-origin", headers: { Accept: "text/html" } })
          .then((response) => (response.ok ? response.text() : ""))
          .catch(() => ""));
      }
      const html = await fetched.get(url);
      // The pointer may have left, or moved to another card, meanwhile.
      if (!html || waitingFor !== card) return;
      preview.innerHTML = html;
      preview.hidden = false;
      shownFor = card;
      card.querySelector(".board-card__title a")?.setAttribute("aria-describedby", preview.id);
      place(card);
    };
    let waitingFor = null;
    const wait = (card) => {
      if (waitingFor === card) return;
      hide();
      waitingFor = card;
      timer = setTimeout(() => show(card), 500);
    };
    const leave = () => { waitingFor = null; hide(); };
    board.addEventListener("mouseover", (event) => {
      const card = event.target.closest("[data-board-card]");
      // The check box and the Move menu have their own job.
      if (!card || event.target.closest("[data-board-check], .board-card__move")) return leave();
      wait(card);
    }, { signal: pageSignal });
    board.addEventListener("mouseout", (event) => {
      const card = event.target.closest("[data-board-card]");
      if (card && !card.contains(event.relatedTarget)) leave();
    }, { signal: pageSignal });
    board.addEventListener("focusin", (event) => {
      const link = event.target.closest(".board-card__title a");
      if (link && link.matches(":focus-visible")) wait(link.closest("[data-board-card]"));
    }, { signal: pageSignal });
    board.addEventListener("focusout", leave, { signal: pageSignal });
    board.addEventListener("dragstart", leave, { signal: pageSignal });
    board.addEventListener("change", leave, { signal: pageSignal });
    board.addEventListener("toggle", leave, { capture: true, signal: pageSignal });
    board.addEventListener("scroll", leave, { capture: true, passive: true, signal: pageSignal });
    window.addEventListener("scroll", leave, { passive: true, signal: pageSignal });
    document.addEventListener("keydown", (event) => { if (event.key === "Escape") leave(); }, { signal: pageSignal });
  }

  const count = (column, change) => {
    column.querySelectorAll("[data-column-count]").forEach((element) => {
      element.textContent = Number(element.textContent) + change;
    });
  };

  // Moves one card; true when the server took it. A single card says why
  // it failed; a group reports once, after all of them.
  async function moveCard(card, column, announce = true) {
    const from = card.closest("[data-board-column]");
    const status = column.dataset.status;
    const stage = column.dataset.stage || "";
    const token = document.querySelector("meta[name=csrf-token]")?.content;
    let response;
    try {
      const send = window.Turbo?.fetch || window.fetch;
      // POST with _method, as for task lists (the WAF refuses PATCH).
      response = await send(card.dataset.moveUrl, {
        method: "POST",
        credentials: "same-origin",
        headers: { "X-CSRF-Token": token, Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ _method: "patch", status, stage })
      });
    } catch {}
    if (!response?.ok) {
      const reason = response ? await response.text() : "";
      if (announce) showAlert(board.dataset.moveFailed.replace("%{error}", reason || response?.status || "-"));
      return false;
    }
    // The card goes to its place: golden (urgent) cards on top.
    const list = column.querySelector("[data-board-cards]");
    list.querySelector(".board-column__empty")?.remove();
    const golden = card.classList.contains("is-golden");
    const firstPlain = [...list.querySelectorAll("[data-board-card]")].find((other) => !other.classList.contains("is-golden"));
    golden ? list.prepend(card) : list.insertBefore(card, firstPlain || null);
    card.dataset.status = status;
    card.dataset.stage = stage;
    card.dataset.allowed = (transitions[status] || []).join(" ");
    count(from, -1);
    count(column, 1);
    return true;
  }
}

// The in-place edit form arrives in a Turbo frame after turbo:load, so its
// text area is set up to grow here.
document.addEventListener("turbo:frame-load", (event) => {
  event.target.querySelectorAll("textarea[data-autogrow]").forEach(autoGrow);
  setUpCodeCopy(event.target);
  if (event.target.id === "description-text") {
    setUpMailView();
    setUpLongRequest();
  }
});

// Turbo fires turbo:load after the first page and after every visit. If
// Turbo did not load (old browser, blocked module), set up the page once.
document.addEventListener("turbo:load", setUpPage);
document.addEventListener("DOMContentLoaded", () => {
  if (!window.Turbo) setUpPage();
});
