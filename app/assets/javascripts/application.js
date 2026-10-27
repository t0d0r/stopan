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

function registerStreamActions() {
  if (window.Turbo?.StreamActions) window.Turbo.StreamActions.notifications_refresh = scheduleNotificationsRefresh;
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

  // Notices fade out after a few seconds (not while hovered or focused);
  // alerts stay until closed.
  document.querySelectorAll("[data-flash]").forEach((flash) => {
    const dismiss = () => {
      flash.classList.add("is-leaving");
      setTimeout(() => flash.remove(), 400);
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

// Turbo fires turbo:load after the first page and after every visit. If
// Turbo did not load (old browser, blocked module), set up the page once.
document.addEventListener("turbo:load", setUpPage);
document.addEventListener("DOMContentLoaded", () => {
  if (!window.Turbo) setUpPage();
});
