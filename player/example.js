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
