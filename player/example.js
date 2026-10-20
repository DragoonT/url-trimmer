const STORE = "trim-example-player";

function emptyState() {
  return {
    playlists: [{ id: "example", name: "Example", items: [] }],
    cookies: {},
    session: {},
  };
}

function readState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORE) || "null");
    if (saved && Array.isArray(saved.playlists) && saved.cookies) return saved;
  } catch {
    /* keep a fresh example */
  }
  const fresh = emptyState();
  localStorage.setItem(STORE, JSON.stringify(fresh));
  return fresh;
}

function writeState(next) {
  localStorage.setItem(STORE, JSON.stringify(next));
}

const FILE_DB = "trim-example-files";

function fileDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(FILE_DB, 1);
    request.onupgradeneeded = () => request.result.createObjectStore("files");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export function saveExampleFile(id, file) {
  return fileDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction("files", "readwrite");
    tx.objectStore("files").put(file, id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  }));
}

export function deleteExampleFile(id) {
  return fileDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction("files", "readwrite");
    tx.objectStore("files").delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  }));
}

export function exampleFileUrl(id) {
  return fileDb().then((db) => new Promise((resolve, reject) => {
    const request = db.transaction("files", "readonly").objectStore("files").get(id);
    request.onsuccess = () => resolve(request.result ? URL.createObjectURL(request.result) : "");
    request.onerror = () => reject(request.error);
  }));
}

let decision;

export function usesExample() {
  if (!decision) {
    decision = new URLSearchParams(location.search).has("example") ? Promise.resolve(true) : probe();
  }
  return decision;
}

async function probe() {
  try {
    const response = await fetch("/api/playlists", { cache: "no-store" });
    const type = response.headers.get("content-type") || "";
    return !(response.ok || type.includes("json"));
  } catch {
    return true;
  }
}

export function exampleHome() {
  if (location.pathname.replaceAll("\\", "/").includes("/player/")) return new URL("../", location.href).href;
  return "https://dragoont.github.io/url-trimmer/";
}

function bodyOf(options) {
  if (!options?.body) return {};
  try {
    return JSON.parse(options.body);
  } catch {
    return {};
  }
}

export function exampleResponse(url, options = {}) {
  const data = readState();
  const method = String(options.method || "GET").toUpperCase();
  const path = url.split("?")[0].replace(/\/$/, "") || "/";
  const parts = path.split("/").filter(Boolean);

  if (path === "/api/playlists" && method === "GET") {
    return data.playlists.map((playlist) => ({ id: playlist.id, name: playlist.name, trackCount: playlist.items.length }));
  }
  if (path === "/api/playlists" && method === "POST") {
    const playlist = { id: "playlist-" + Date.now().toString(36), name: String(bodyOf(options).name || "New playlist").trim() || "New playlist", items: [] };
    data.playlists.push(playlist);
    writeState(data);
    return { id: playlist.id, name: playlist.name, trackCount: 0 };
  }
  if (parts[0] === "api" && parts[1] === "playlists" && parts.length === 3) {
    const id = decodeURIComponent(parts[2]);
    const playlist = data.playlists.find((item) => item.id === id);
    if (!playlist) throw Error("Playlist not found");
    if (method === "GET") return playlist;
    if (method === "PUT") {
      playlist.name = String(bodyOf(options).name || playlist.name);
      writeState(data);
      return playlist;
    }
    if (method === "DELETE") {
      data.playlists = data.playlists.filter((item) => item.id !== id);
      if (!data.playlists.length) data.playlists.push({ id: "example", name: "Example", items: [] });
      writeState(data);
      return {};
    }
  }
  if (parts[0] === "api" && parts[1] === "playlists" && parts[3] === "items" && method === "DELETE") {
    const playlist = data.playlists.find((item) => item.id === decodeURIComponent(parts[2]));
    if (playlist) playlist.items = playlist.items.filter((item) => item.id !== decodeURIComponent(parts[4]));
    writeState(data);
    return {};
  }
  if (parts[0] === "api" && parts[1] === "playlists" && parts[3] === "items" && method === "POST") {
    const playlist = data.playlists.find((item) => item.id === decodeURIComponent(parts[2]));
    if (!playlist) throw Error("Playlist not found");
    const body = bodyOf(options);
    if (body.source !== "browser" || !body.id) throw Error("On the website, choose the file. It stays in this browser and plays here.");
    playlist.items.push({
      id: String(body.id),
      title: String(body.title || body.name || "Track"),
      source: "browser",
      kind: body.kind === "video" ? "video" : "audio",
      ext: String(body.ext || ""),
      name: String(body.name || ""),
      missing: false,
    });
    writeState(data);
    return { id: body.id };
  }
  if (path === "/api/cookies" && method === "GET") return Object.keys(data.cookies).sort();
  if (path === "/api/cookies" && method === "POST") {
    const body = bodyOf(options);
    const name = String(body.name || "cookies.txt");
    data.cookies[name] = String(body.text ?? "");
    writeState(data);
    return { name };
  }
  if (parts[0] === "api" && parts[1] === "cookies" && parts.length === 3 && method === "GET") {
    const name = decodeURIComponent(parts[2]);
    if (!Object.prototype.hasOwnProperty.call(data.cookies, name)) {
      const error = Error("Cookies file not found");
      error.status = 404;
      throw error;
    }
    return { name, text: data.cookies[name] };
  }
  if (path === "/api/session" && method === "GET") return data.session || {};
  if (path === "/api/session" && method === "PUT") {
    data.session = { ...(data.session || {}), ...bodyOf(options) };
    writeState(data);
    return data.session;
  }
  throw Error("The example player shows the screens. Download the app to play files and download URLs.");
}
