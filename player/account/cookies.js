import { exampleResponse, usesExample } from "../example/example.js";
import { icon } from "../ui/icons.js";
import { showToast } from "../ui/ui.js";

const HEADER = "# Netscape HTTP Cookie File\n";

function overlay() {
  const node = document.createElement("div");
  node.className = "modal-overlay";
  document.body.append(node);
  document.body.style.overflow = "hidden";
  requestAnimationFrame(() => node.classList.add("open"));
  return node;
}

function closeOverlay(node) {
  node.remove();
  document.body.style.overflow = "";
}

function tidyName(name) {
  const leaf = String(name || "").trim().replaceAll("\\", "/").split("/").pop() || "cookies";
  const stem = leaf.toLowerCase().endsWith(".txt") ? leaf.slice(0, -4) : leaf;
  return `${stem.trim() || "cookies"}.txt`;
}

function chooseKind() {
  return new Promise((resolve) => {
    const node = overlay();
    node.innerHTML = `
      <div class="modal card cookie-kind-modal" role="dialog" aria-modal="true">
        <div class="modal-head"><h3>Create cookie file</h3><button type="button" class="modal-close" aria-label="Close">${icon("x")}</button></div>
        <div class="modal-body cookie-choices">
          <p class="muted modal-msg">Choose how to add the cookie file.</p>
          <button type="button" class="btn btn-outline" data-kind="manual">Manual .txt</button>
          <button type="button" class="btn btn-outline" data-kind="import">Import .txt file</button>
        </div>
      </div>`;
    const finish = (value) => { closeOverlay(node); resolve(value); };
    node.querySelector(".modal-close").onclick = () => finish(null);
    node.querySelector('[data-kind="manual"]').onclick = () => finish("manual");
    node.querySelector('[data-kind="import"]').onclick = () => finish("import");
    node.addEventListener("click", (event) => { if (event.target === node) finish(null); });
  });
}

function askName() {
  return new Promise((resolve) => {
    const node = overlay();
    node.innerHTML = `
      <div class="modal card" role="dialog" aria-modal="true">
        <div class="modal-head"><h3>Cookie file name</h3><button type="button" class="modal-close" aria-label="Close">${icon("x")}</button></div>
        <div class="modal-body"><label class="field"><span class="field-label">File name</span><input class="input" value="cookies"></label></div>
        <div class="modal-foot"><button type="button" class="btn btn-ghost" data-action="cancel">Cancel</button><button type="button" class="btn btn-primary" data-action="edit">Edit</button></div>
      </div>`;
    const input = node.querySelector("input");
    const finish = (value) => { closeOverlay(node); resolve(value); };
    node.querySelector(".modal-close").onclick = () => finish(null);
    node.querySelector('[data-action="cancel"]').onclick = () => finish(null);
    node.querySelector('[data-action="edit"]').onclick = () => finish(input.value);
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") finish(input.value);
      if (event.key === "Escape") finish(null);
    });
    node.addEventListener("click", (event) => { if (event.target === node) finish(null); });
    input.focus();
    input.select();
  });
}

function editText(filename, text) {
  return new Promise((resolve) => {
    const node = overlay();
    node.innerHTML = `
      <div class="modal card cookie-editor-modal" role="dialog" aria-modal="true">
        <div class="modal-head"><h3></h3><button type="button" class="modal-close" aria-label="Close">${icon("x")}</button></div>
        <div class="modal-body">
          <p class="muted modal-msg">Type the cookie file here, the same way you would in a text editor.</p>
          <textarea class="input cookie-text" spellcheck="false"></textarea>
        </div>
        <div class="modal-foot"><button type="button" class="btn btn-ghost" data-action="cancel">Cancel</button><button type="button" class="btn btn-primary" data-action="save">Save</button></div>
      </div>`;
    node.querySelector("h3").textContent = filename;
    const area = node.querySelector("textarea");
    area.value = text;
    const finish = (value) => { closeOverlay(node); resolve(value); };
    node.querySelector(".modal-close").onclick = () => finish(null);
    node.querySelector('[data-action="cancel"]').onclick = () => finish(null);
    node.querySelector('[data-action="save"]').onclick = () => finish(area.value);
    node.addEventListener("click", (event) => { if (event.target === node) finish(null); });
    area.focus();
  });
}

function pickFile() {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".txt,text/plain";
    let settled = false;
    const finish = (file) => { if (settled) return; settled = true; resolve(file); };
    input.addEventListener("change", () => finish(input.files?.[0] || null));
    window.addEventListener("focus", () => setTimeout(() => finish(input.files?.[0] || null), 400), { once: true });
    input.click();
  });
}

async function saveCookie(name, text) {
  if (await usesExample()) return exampleResponse("/api/cookies", { method: "POST", body: JSON.stringify({ name, text }) }).name;
  const response = await fetch("/api/cookies", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, text }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw Error(body.error || "Could not save the cookie file");
  return body.name;
}

async function openCookie(filename) {
  if (await usesExample()) {
    try {
      return exampleResponse(`/api/cookies/${encodeURIComponent(filename)}`).text;
    } catch (error) {
      if (error.status === 404) return null;
      throw error;
    }
  }
  const existing = await fetch(`/api/cookies/${encodeURIComponent(filename)}`, { cache: "no-store" });
  if (existing.ok) return (await existing.json()).text ?? HEADER;
  const body = await existing.json().catch(() => ({}));
  if (existing.status === 404 && body.error === "Cookies file not found") return null;
  throw Error(body.error || "Could not open the cookie file");
}

export async function createCookieFile() {
  try {
    const kind = await chooseKind();
    if (!kind) return null;
    if (kind === "import") {
      const file = await pickFile();
      if (!file) return null;
      if (file.size > 2_000_000) throw Error("Cookie file is too large");
      const name = await saveCookie(tidyName(file.name), await file.text());
      showToast(`Imported ${name}`, "success");
      return name;
    }
    const named = await askName();
    if (named == null) return null;
    const filename = tidyName(named);
    const edited = await editText(filename, (await openCookie(filename)) ?? HEADER);
    if (edited == null) return null;
    const name = await saveCookie(filename, edited);
    showToast(`Saved ${name}`, "success");
    return name;
  } catch (error) {
    showToast(error.message, "error");
    return null;
  }
}

export function addCreateCookieButton(anchor, onCreated) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "btn btn-outline cookie-create";
  button.textContent = "Create new";
  button.onclick = async () => {
    button.disabled = true;
    try {
      const name = await createCookieFile();
      if (name) await onCreated(name);
    } finally {
      button.disabled = false;
    }
  };
  anchor.after(button);
  return button;
}
