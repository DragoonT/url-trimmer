/** Custom dialogs and toasts (no native browser prompts) */

import { icon } from "./icons.js";

let toastId = 0;

export function showToast(message, kind = "info") {
  const host = document.getElementById("toastHost");
  if (!host) return;
  const id = ++toastId;
  const el = document.createElement("div");
  el.className = `toast toast-${kind}`;
  el.innerHTML = `
    <span class="toast-icon">${toastIcon(kind)}</span>
    <p class="toast-msg">${escapeHtml(message)}</p>
    <button type="button" class="toast-close" aria-label="Close">${icon("x")}</button>
  `;
  el.querySelector(".toast-close").addEventListener("click", () => el.remove());
  host.appendChild(el);
  setTimeout(() => el.remove(), 4500);
}

function toastIcon(kind) {
  if (kind === "success") return icon("check");
  if (kind === "error") return icon("circle-alert");
  if (kind === "warning") return icon("alert-triangle");
  return icon("info");
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function lockBody(lock) {
  document.body.style.overflow = lock ? "hidden" : "";
}

export function openPrompt({ title, message, label, defaultValue = "", confirmLabel = "Save", cancelLabel = "Cancel" }) {
  return new Promise((resolve) => {
    const overlay = createOverlay();
    overlay.innerHTML = `
      <div class="modal card" role="dialog" aria-modal="true">
        <div class="modal-head">
          <h3>${escapeHtml(title)}</h3>
          <button type="button" class="modal-close" aria-label="Close">${icon("x")}</button>
        </div>
        <div class="modal-body">
          ${message ? `<p class="muted modal-msg">${escapeHtml(message)}</p>` : ""}
          <label class="field">
            <span class="field-label">${escapeHtml(label || title)}</span>
            <input class="input" type="text" id="modalInput" value="${escapeHtml(defaultValue)}">
          </label>
        </div>
        <div class="modal-foot">
          <button type="button" class="btn btn-ghost" data-action="cancel">${escapeHtml(cancelLabel)}</button>
          <button type="button" class="btn btn-primary" data-action="confirm">${escapeHtml(confirmLabel)}</button>
        </div>
      </div>
    `;

    const input = overlay.querySelector("#modalInput");
    const close = (value) => {
      overlay.remove();
      lockBody(false);
      resolve(value);
    };

    overlay.querySelector(".modal-close").addEventListener("click", () => close(null));
    overlay.querySelector('[data-action="cancel"]').addEventListener("click", () => close(null));
    overlay.querySelector('[data-action="confirm"]').addEventListener("click", () => {
      const val = input.value.trim();
      close(val || null);
    });
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) close(null);
    });
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") close(input.value.trim() || null);
      if (e.key === "Escape") close(null);
    });

    document.body.appendChild(overlay);
    requestAnimationFrame(() => overlay.classList.add("open"));
    lockBody(true);
    input.focus();
    input.select();
  });
}

export function openConfirm({
  title,
  message,
  variant = "default",
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
}) {
  return new Promise((resolve) => {
    const overlay = createOverlay();
    const iconClass = variant === "danger" ? "confirm-icon danger" : "confirm-icon";
    overlay.innerHTML = `
      <div class="modal card confirm-modal" role="dialog" aria-modal="true">
        <div class="modal-body confirm-body">
          <div class="${iconClass}">${variant === "danger" ? icon("alert-triangle") : icon("info")}</div>
          <div>
            <h3 class="confirm-title">${escapeHtml(title)}</h3>
            ${message ? `<p class="muted modal-msg">${escapeHtml(message)}</p>` : ""}
          </div>
        </div>
        <div class="modal-foot">
          <button type="button" class="btn btn-ghost" data-action="cancel">${escapeHtml(cancelLabel)}</button>
          <button type="button" class="btn ${variant === "danger" ? "btn-danger" : "btn-primary"}" data-action="confirm">${escapeHtml(confirmLabel)}</button>
        </div>
      </div>
    `;

    const close = (value) => {
      overlay.remove();
      lockBody(false);
      resolve(value);
    };

    overlay.querySelector('[data-action="cancel"]').addEventListener("click", () => close(false));
    overlay.querySelector('[data-action="confirm"]').addEventListener("click", () => close(true));
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) close(false);
    });
    document.addEventListener(
      "keydown",
      function onEsc(e) {
        if (e.key === "Escape") {
          document.removeEventListener("keydown", onEsc);
          close(false);
        }
      },
      { once: true },
    );

    document.body.appendChild(overlay);
    requestAnimationFrame(() => overlay.classList.add("open"));
    lockBody(true);
  });
}

function createOverlay() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  return overlay;
}

function fileKey(file) {
  return `${file.name}:${file.size}:${file.lastModified}`;
}

export function initFileUpload({ zone, input, list, titleEl, onChange }) {
  let selectedFiles = [];

  function updateTitle() {
    if (!titleEl) return;
    if (!selectedFiles.length) {
      titleEl.textContent = "Drop files or click to upload";
      return;
    }
    if (selectedFiles.length === 1) {
      titleEl.textContent = selectedFiles[0].name;
      return;
    }
    titleEl.textContent = `${selectedFiles.length} files selected`;
  }

  function render() {
    if (!list) return;
    list.innerHTML = "";
    selectedFiles.forEach((file, index) => {
      const li = document.createElement("li");
      li.className = "file-chip animate-fade-up";
      li.style.animationDelay = `${Math.min(index * 30, 240)}ms`;
      li.innerHTML = `
        <span class="file-chip-icon">${icon("file")}</span>
        <div class="file-chip-text">
          <p class="file-chip-name">${escapeHtml(file.name)}</p>
          <p class="muted">${formatSize(file.size)}</p>
        </div>
        <button type="button" class="file-chip-remove" aria-label="Remove">${icon("x")}</button>
      `;
      li.querySelector(".file-chip-remove").addEventListener("click", (e) => {
        e.stopPropagation();
        selectedFiles = selectedFiles.filter((_, i) => i !== index);
        render();
        updateTitle();
        onChange?.(selectedFiles);
      });
      list.appendChild(li);
    });
    updateTitle();
  }

  function pick() {
    if (!input.disabled) input.click();
  }

  function setFiles(files) {
    selectedFiles = Array.from(files || []);
    render();
    onChange?.(selectedFiles);
  }

  function addFiles(files) {
    const incoming = Array.from(files || []);
    if (!incoming.length) return;
    const seen = new Set(selectedFiles.map(fileKey));
    for (const file of incoming) {
      const key = fileKey(file);
      if (seen.has(key)) continue;
      seen.add(key);
      selectedFiles.push(file);
    }
    render();
    onChange?.(selectedFiles);
  }

  zone.addEventListener("click", pick);
  zone.addEventListener("keydown", (e) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      pick();
    }
  });
  zone.addEventListener("dragover", (e) => {
    e.preventDefault();
    zone.classList.add("dragging");
  });
  zone.addEventListener("dragleave", () => zone.classList.remove("dragging"));
  zone.addEventListener("drop", (e) => {
    e.preventDefault();
    zone.classList.remove("dragging");
    if (e.dataTransfer.files?.length) addFiles(e.dataTransfer.files);
  });
  input.addEventListener("change", () => {
    if (input.files?.length) addFiles(input.files);
    input.value = "";
  });

  return {
    getFiles: () => [...selectedFiles],
    getFile: () => selectedFiles[0] || null,
    clear: () => {
      selectedFiles = [];
      input.value = "";
      render();
      onChange?.(selectedFiles);
    },
  };
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export function initDropdown({ root, trigger, menu, onSelect }) {
  const close = () => {
    menu.classList.remove("open");
    trigger.setAttribute("aria-expanded", "false");
  };

  trigger.addEventListener("click", (e) => {
    e.stopPropagation();
    const open = !menu.classList.contains("open");
    // Dropdown triggers stop propagation so the document click handler cannot
    // close a previously-open control. Do it here before opening this menu.
    document.querySelectorAll(".dropdown-menu.open").forEach((other) => {
      if (other === menu) return;
      other.classList.remove("open");
      other.parentElement?.querySelector(".dropdown-trigger")?.setAttribute("aria-expanded", "false");
    });
    menu.classList.toggle("open", open);
    trigger.setAttribute("aria-expanded", open ? "true" : "false");
  });

  menu.addEventListener("click", (e) => {
    const item = e.target.closest("[data-value]");
    if (!item || item.disabled || item.classList.contains("disabled")) return;
    menu.querySelectorAll("[data-value]").forEach((el) => el.classList.remove("active"));
    item.classList.add("active");
    close();
    onSelect?.(item.dataset.value, item.textContent.trim());
  });

  document.addEventListener("click", (e) => {
    if (!root.contains(e.target)) {
      close();
    }
  });
}

export function initCollapsiblePanels(root = document) {
  root.querySelectorAll('.collapsible').forEach(panel => {
    const button = panel.querySelector('.panel-toggle');
    const content = panel.querySelector('.panel-content');
    button.addEventListener('click', () => {
      const collapsed = panel.classList.toggle('collapsed');
      button.setAttribute('aria-expanded', String(!collapsed));
      content.hidden = collapsed;
    });
  });
}

export function createChoiceDropdown(host, choices, initial, onChange) {
  host.classList.add('dropdown', 'download-select');
  const trigger=document.createElement('button');trigger.type='button';trigger.className='input dropdown-trigger';trigger.setAttribute('aria-expanded','false');trigger.setAttribute('aria-haspopup','listbox');
  const label=document.createElement('span');trigger.append(label);trigger.insertAdjacentHTML('beforeend',icon('chevron-down'));
  const menu=document.createElement('div');menu.className='dropdown-menu';menu.setAttribute('role','listbox');host.append(trigger,menu);
  let value=initial;
  function fill(options){menu.replaceChildren();if(!options.some(([key])=>key===value))value=options[0]?.[0]||'';for(const [key,text] of options){const button=document.createElement('button');button.type='button';button.className='dropdown-item';button.dataset.value=key;button.textContent=text;button.setAttribute('role','option');menu.append(button);}label.textContent=options.find(([key])=>key===value)?.[1]||'';}
  fill(choices);
  initDropdown({root:host,trigger,menu,onSelect:(key,text)=>{value=key;label.textContent=text;onChange?.(key);}});
  trigger.addEventListener('keydown',event=>{if(event.key==='ArrowDown'){event.preventDefault();menu.classList.add('open');trigger.setAttribute('aria-expanded','true');menu.querySelector('button')?.focus();}});
  menu.addEventListener('keydown',event=>{const buttons=[...menu.children];const index=buttons.indexOf(document.activeElement);if(event.key==='ArrowDown'||event.key==='ArrowUp'){event.preventDefault();buttons[(index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length]?.focus();}if(event.key==='Escape'){menu.classList.remove('open');trigger.setAttribute('aria-expanded','false');trigger.focus();}});
  return {get value(){return value;},fill,trigger};
}
