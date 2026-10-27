// Page behaviour for Stopan. Plain JavaScript plus Turbo Drive (turbo-rails),
// which swaps the <body> on link clicks and form submits instead of loading
// a new page. This file runs once; setUpPage runs on every turbo:load.
// Listeners on document or window that belong to one page pass
// { signal: pageSignal }, so they are removed when the next page loads.
let pageAbort = null;
let pageSignal;

// Text areas grow with their text instead of scrolling. scrollHeight leaves
// out the border, which with border-box sizing would leave the box a pixel
// short. Without JavaScript the field keeps its normal scroll bar.
function autoGrow(textarea) {
  const minimum = textarea.offsetHeight;
  const grow = () => {
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

  document.querySelectorAll("form[data-confirm]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      if (form.dataset.confirmed === "true") return;
      event.preventDefault();
      if (!dialog) {
        if (window.confirm(form.dataset.confirm)) submitConfirmed(form);
        return;
      }
      pending = form;
      dialog.querySelector("[data-confirm-title]").textContent = form.dataset.confirmTitle || dialog.dataset.defaultTitle;
      dialog.querySelector("[data-confirm-body]").textContent = form.dataset.confirm;
      dialog.querySelector("[data-confirm-ok]").textContent = form.dataset.confirmButton || dialog.dataset.defaultButton;
      dialog.returnValue = "";
      dialog.showModal();
      dialog.querySelector("[data-confirm-cancel]").focus();
    });
  });

  if (!dialog) return;
  // Escape and the backdrop cancel; only the destructive button confirms.
  dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });
  dialog.addEventListener("close", () => {
    if (dialog.returnValue === "confirm" && pending) submitConfirmed(pending);
    pending = null;
  });
}

function submitConfirmed(form) {
  form.dataset.confirmed = "true";
  form.requestSubmit();
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
    if (button) button.textContent = internal ? button.dataset.internalLabel : button.dataset.publicLabel;
  };
  composer.querySelectorAll("[data-composer-mode]").forEach((radio) => radio.addEventListener("change", update));
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
      const box = menu.querySelector("summary").getBoundingClientRect();
      const below = box.bottom + 4 + list.offsetHeight <= window.innerHeight;
      list.style.top = `${below ? box.bottom + 4 : Math.max(8, box.top - 4 - list.offsetHeight)}px`;
      list.style.left = `${Math.max(8, Math.min(box.left, window.innerWidth - list.offsetWidth - 8))}px`;
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
}

// "Copy link" buttons copy the value of the field they name; the field
// itself is selected on focus, so copying also works by hand.
function setUpCopyButtons() {
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
      await copyText(text.innerText.trim());
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

function registerStreamActions() {
  if (!window.Turbo?.StreamActions) return;
  window.Turbo.StreamActions.notifications_refresh = scheduleNotificationsRefresh;
  window.Turbo.StreamActions.share_viewers = updateShareViewers;
}

registerStreamActions();

// Live page refreshes (specs/timeline.md, specs/sharing.md) never throw
// away work in progress: while the page is busy the refresh waits, a
// notice says so, and it runs once the page is idle (checked every second).
function pageIsBusy() {
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
function setUpTaskLists() {
  document.querySelectorAll("[data-task-path] input[type=checkbox][data-task-line]").forEach((box) => {
    box.disabled = false;
    box.addEventListener("change", async () => {
      const body = new FormData();
      body.append("line", box.dataset.taskLine);
      body.append("checked", box.checked ? "1" : "0");
      const token = document.querySelector("meta[name=csrf-token]")?.content;
      let ok = false;
      try {
        const send = window.Turbo?.fetch || window.fetch;
        const response = await send(box.closest("[data-task-path]").dataset.taskPath, {
          method: "PATCH", body, credentials: "same-origin", headers: { "X-CSRF-Token": token, Accept: "text/html" }
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
  setUpAssignMenus(document.querySelectorAll("details[data-assign-menu]"));
  setUpCopyButtons();
  setUpCopyBoxes();
  setUpDoubleClickEdit();
  setUpTaskLists();
  setUpDropdowns();

  // A sideways-scrolling tab row (queue views on phones) shows the current tab.
  document.querySelectorAll(".queue__views ul").forEach((row) => {
    const current = row.querySelector("[aria-current]");
    if (current && row.scrollWidth > row.clientWidth) row.scrollLeft = current.offsetLeft - row.offsetLeft - 16;
  });
  document.querySelectorAll("select[data-requester-organizations]").forEach(setUpRequesterOrganizations);

  // Theme and text size apply at once; the cookie keeps them for the next page.
  document.querySelectorAll("form[data-preference]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      const button = event.submitter;
      if (!button || !button.name) return;
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

  // Notices go after a few seconds (not while hovered or focused); alerts
  // stay until closed. Going: a sweep to the left, then the band closes
  // (specs/ui.md "Flash messages").
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.querySelectorAll("[data-flash]").forEach((flash) => {
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
      }, 450);
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
  });
}

// The in-place edit form arrives in a Turbo frame after turbo:load, so its
// text area is set up to grow here.
document.addEventListener("turbo:frame-load", (event) => {
  event.target.querySelectorAll("textarea[data-autogrow]").forEach(autoGrow);
});

// Turbo fires turbo:load after the first page and after every visit. If
// Turbo did not load (old browser, blocked module), set up the page once.
document.addEventListener("turbo:load", setUpPage);
document.addEventListener("DOMContentLoaded", () => {
  if (!window.Turbo) setUpPage();
});
