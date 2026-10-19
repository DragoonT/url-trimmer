import {
  showToast,
  openPrompt,
  openConfirm,
  initFileUpload,
  initDropdown,
  initCollapsiblePanels,
  createChoiceDropdown,
} from "./ui.js";
import { initSortableList } from "./dnd.js";
import { icon, setIcon, mountIcons } from "./icons.js";
import { addCreateCookieButton } from "./cookies.js";
import { exampleResponse, usesExample } from "./example.js";

const state = {
  playlists: [],
  currentPlaylistId: null,
  currentPlaylist: null,
  index: -1,
  shuffle: false,
  repeat: "off",
  volume: 100,
  videoQuality: "original",
};

const els = {
  playlistList: document.getElementById("playlistList"),
  playlistName: document.getElementById("playlistName"),
  trackList: document.getElementById("trackList"),
  nowTitle: document.getElementById("nowTitle"),
  nowMeta: document.getElementById("nowMeta"),
  nowBadge: document.getElementById("nowBadge"),
  video: document.getElementById("video"),
  audio: document.getElementById("audio"),
  videoStage: document.getElementById("videoStage"),
  audioArt: document.getElementById("audioArt"),
  playBtn: document.getElementById("playBtn"),
  prevBtn: document.getElementById("prevBtn"),
  nextBtn: document.getElementById("nextBtn"),
  repeatBtn: document.getElementById("repeatBtn"),
  shuffleBtn: document.getElementById("shuffleBtn"),
  progressTrack: document.getElementById("progressTrack"),
  progressFill: document.getElementById("progressFill"),
  progressThumb: document.getElementById("progressThumb"),
  volumeFill: document.getElementById("volumeFill"),
  volumeTrack: document.getElementById("volumeTrack"),
  volumeThumb: document.getElementById("volumeThumb"),
  timeCurrent: document.getElementById("timeCurrent"),
  timeTotal: document.getElementById("timeTotal"),
  newPlaylistBtn: document.getElementById("newPlaylistBtn"),
  renamePlaylistBtn: document.getElementById("renamePlaylistBtn"),
  deletePlaylistBtn: document.getElementById("deletePlaylistBtn"),
  addTrackBtn: document.getElementById("addTrackBtn"),
  trackTitle: document.getElementById("trackTitle"),
  fileInput: document.getElementById("fileInput"),
  filePath: document.getElementById("filePath"),
  fullscreenBtn: document.getElementById("fullscreenBtn"),
  qualityDropdown: document.getElementById("qualityDropdown"),
  qualityTrigger: document.getElementById("qualityTrigger"),
  qualityMenu: document.getElementById("qualityMenu"),
  qualityLabel: document.getElementById("qualityLabel"),
  qualityWarn: document.getElementById("qualityWarn"),
  volumeIcon: document.getElementById("volumeIcon"),
};

const SESSION_KEY = "playerSession";
let saveSessionTimer = null;
let lastSessionSaveAt = 0;
let reorderTimer = null;
let isScrubbingProgress = false;

const fileUpload = initFileUpload({
  zone: document.getElementById("fileUploadZone"),
  input: els.fileInput,
  list: document.getElementById("fileList"),
  titleEl: document.getElementById("fileUploadTitle"),
});

let onlinePreview=null,onlineSelection=new Set(),onlineLoading=false,onlineAdding=false;
function setOnlineLoadProgress(percent,visible=false){const bar=document.querySelector('#onlineLoadProgress');bar.hidden=!visible;bar.querySelector('div').style.width=`${Math.max(0,Math.min(100,Number(percent)||0))}%`;}
function clearOnlinePreview(){onlinePreview=null;onlineSelection.clear();document.querySelector('#onlinePreview').hidden=true;setOnlineLoadProgress(0,false);updatePlaylistActions();}
const sourceChoice=createChoiceDropdown(document.querySelector('#trackSourceSelect'),[['offline','Offline'],['online','Online']],'offline',()=>{
 document.querySelector('#offlineTrackFields').hidden=sourceChoice.value!=='offline';document.querySelector('#onlineTrackFields').hidden=sourceChoice.value!=='online';updatePlaylistActions();
});
const onlineCookieChoice=createChoiceDropdown(document.querySelector('#onlineTrackCookies'),[['','No cookies']],'',clearOnlinePreview);
const playbackChoice=createChoiceDropdown(document.querySelector('#onlinePlaybackSelect'),[['video','Video'],['audio','Audio only']],'video');
const onlineSelectionChoice=createChoiceDropdown(document.querySelector('#onlineSelectionSelect'),[['single','Single video'],['all','Entire playlist']],'single',renderOnlineChoices);
const onlineUrl=document.querySelector('#onlineTrackUrl');onlineUrl.addEventListener('input',clearOnlinePreview);
async function refreshOnlineCookies(){try{const names=await api('/api/cookies');onlineCookieChoice.fill([['','No cookies'],...names.map(name=>[name,name])]);}catch(error){showToast(error.message,'error');}}
onlineCookieChoice.trigger.addEventListener('click',refreshOnlineCookies);refreshOnlineCookies();
addCreateCookieButton(document.querySelector('#onlineTrackCookies'), async name=>{onlineCookieChoice.select(name);clearOnlinePreview();await refreshOnlineCookies();});
function renderOnlineChoices(){
 const list=document.querySelector('#onlineTrackChoices');list.replaceChildren();onlineSelection.clear();
 if(!onlinePreview)return;
 const all=onlineSelectionChoice.value==='all'||!onlinePreview.is_playlist;
 document.querySelector('#onlineSelectionType').hidden=!onlinePreview.is_playlist;
 for(const item of onlinePreview.items){
  if(all&&item.available)onlineSelection.add(item.index);
  const row=document.createElement('button');row.type='button';row.className='playlist-choice';row.setAttribute('role','radio');row.setAttribute('aria-checked',String(all&&item.available));row.disabled=!item.available||all;
  const check=document.createElement('span');check.className='choice-check';check.innerHTML=icon('check');const label=document.createElement('span');label.textContent=item.title+(item.available?'':' · Unavailable');row.append(check,label);list.append(row);
  row.onclick=()=>{onlineSelection.clear();onlineSelection.add(item.index);list.querySelectorAll('[aria-checked]').forEach(button=>button.setAttribute('aria-checked',String(button===row)));updateOnlineCount();};
 }
 updateOnlineCount();
}
function updateOnlineCount(){document.querySelector('#onlineSelectionCount').textContent=onlineSelection.size+' selected · URLs only, no media files saved';updatePlaylistActions();}
document.querySelector('#loadOnlineUrl').onclick=async()=>{
 if(onlineLoading)return;const url=onlineUrl.value.trim(),cookies=onlineCookieChoice.value;const status=document.querySelector('#onlineLoadStatus');
 clearOnlinePreview();onlineLoading=true;document.querySelector('#loadOnlineUrl').disabled=true;status.textContent='Preparing URL · 0%';setOnlineLoadProgress(0,true);
 try{
  const response=await api('/api/downloads/preview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({url,cookies,auth_source:'cookie'})});
  let job;do{await new Promise(resolve=>setTimeout(resolve,350));job=await api('/api/downloads/'+response.id);const percent=job.percent??0;status.textContent=`${job.message||'Loading URL'} · ${percent}%`;setOnlineLoadProgress(percent,true);}while(job.status==='running');
  if(job.status==='error')throw Error(job.message);
  if(url!==onlineUrl.value.trim()||cookies!==onlineCookieChoice.value){status.textContent='URL or cookies changed. Load again.';return;}
  onlinePreview={...job,id:response.id};document.querySelector('#onlinePreview').hidden=false;renderOnlineChoices();status.textContent=`${job.title} · 100%`;setOnlineLoadProgress(100,true);
 }catch(error){status.textContent=error.message;setOnlineLoadProgress(0,false);showToast(error.message,'error');}
 finally{onlineLoading=false;document.querySelector('#loadOnlineUrl').disabled=false;updatePlaylistActions();}
};
function networkState(){
 const connection=navigator.connection||navigator.mozConnection||navigator.webkitConnection;
 if(!navigator.onLine)return {kind:'offline',label:'Offline'};
 if(connection?.type==='ethernet')return {kind:'lan',label:'LAN'};
 const effective=connection?.effectiveType||'';
 const downlink=Number(connection?.downlink);
 const kind=effective==='slow-2g'||effective==='2g'||(Number.isFinite(downlink)&&downlink<1)?'poor':effective==='3g'||(Number.isFinite(downlink)&&downlink<5)?'fair':'strong';
 return {kind,label:kind==='strong'?'Wi-Fi':kind==='fair'?'Wi-Fi · fair':'Wi-Fi · poor'};
}
function renderNetworkStatus(status,state){
 status.className=`network-status network-${state.kind}`;
 status.innerHTML=`<span class="signal-bars" aria-hidden="true"><i></i><i></i><i></i><i></i></span><span>${state.label}</span>`;
 status.title='Connection status reported by your device. Signal quality uses the browser network estimate.';
}
function updateNetworkStatus(){
 const state=networkState();renderNetworkStatus(document.querySelector('#networkStatus'),state);
 document.querySelectorAll('.track-item[data-online="true"] .track-connection').forEach(badge=>renderNetworkStatus(badge,state));
}
window.addEventListener('online',updateNetworkStatus);window.addEventListener('offline',updateNetworkStatus);
(navigator.connection||navigator.mozConnection||navigator.webkitConnection)?.addEventListener?.('change',updateNetworkStatus);updateNetworkStatus();

function tracks() {
  return state.currentPlaylist?.items || [];
}

function currentTrack() {
  return tracks()[state.index] || null;
}

function mediaElement() {
  const track = currentTrack();
  return track?.kind === "video" ? els.video : els.audio;
}

function allMediaElements() {
  return [els.video, els.audio];
}

function formatTime(seconds) {
  if (!Number.isFinite(seconds)) return "0:00";
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${String(secs).padStart(2, "0")}`;
}

function setRepeatMode(mode) {
  state.repeat = mode;
  els.repeatBtn.classList.remove("repeat-off", "repeat-all", "repeat-one");
  if (mode === "off") {
    els.repeatBtn.classList.add("repeat-off");
    els.repeatBtn.title = "Repeat off";
    setIcon(els.repeatBtn, "repeat");
  } else if (mode === "all") {
    els.repeatBtn.classList.add("repeat-all");
    els.repeatBtn.title = "Repeat playlist";
    setIcon(els.repeatBtn, "repeat");
  } else {
    els.repeatBtn.classList.add("repeat-one");
    els.repeatBtn.title = "Repeat one";
    setIcon(els.repeatBtn, "repeat1");
  }
  saveSession();
}

function cycleRepeat() {
  const order = ["off", "all", "one"];
  setRepeatMode(order[(order.indexOf(state.repeat) + 1) % order.length]);
}

function updateProgress(current, total) {
  const pct = total ? (current / total) * 100 : 0;
  els.progressFill.style.width = `${pct}%`;
  els.progressTrack.style.setProperty("--pct", `${pct}%`);
  els.timeCurrent.textContent = formatTime(current);
  els.timeTotal.textContent = formatTime(total);
}

function updateVolumeUI(value) {
  els.volumeFill.style.width = `${value}%`;
  els.volumeTrack.style.setProperty("--pct", `${value}%`);
}

function ratioFromTrack(track, clientX) {
  const rect = track.getBoundingClientRect();
  if (!rect.width) return 0;
  return Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
}

function bindScrubber(track, { onScrub, onEnd }) {
  if (!track) return;

  let pointerId = null;

  const scrub = (clientX) => onScrub(ratioFromTrack(track, clientX));

  const stop = () => {
    track.classList.remove("is-scrubbing");
    pointerId = null;
    onEnd?.();
  };

  track.addEventListener("pointerdown", (e) => {
    if (e.button !== 0) return;
    e.preventDefault();
    pointerId = e.pointerId;
    track.classList.add("is-scrubbing");
    track.setPointerCapture(e.pointerId);
    scrub(e.clientX);
  });

  track.addEventListener("pointermove", (e) => {
    if (pointerId == null || e.pointerId !== pointerId) return;
    e.preventDefault();
    scrub(e.clientX);
  });

  track.addEventListener("pointerup", (e) => {
    if (pointerId == null || e.pointerId !== pointerId) return;
    if (track.hasPointerCapture(e.pointerId)) {
      track.releasePointerCapture(e.pointerId);
    }
    scrub(e.clientX);
    stop();
  });

  track.addEventListener("pointercancel", (e) => {
    if (pointerId == null || e.pointerId !== pointerId) return;
    if (track.hasPointerCapture(e.pointerId)) {
      track.releasePointerCapture(e.pointerId);
    }
    stop();
  });
}

function sessionPayload() {
  const el = mediaElement();
  const track = currentTrack();
  return {
    playlistId: state.currentPlaylistId,
    trackId: track?.id || null,
    currentTime:
      el?.src && Number.isFinite(el.currentTime) ? el.currentTime : 0,
    wasPlaying: Boolean(el?.src && !el.paused),
    shuffle: state.shuffle,
    repeat: state.repeat,
    volume: state.volume,
    videoQuality: state.videoQuality,
  };
}

function pushSessionToServer(payload) {
  const body = JSON.stringify(payload);
  return usesExample().then((example) => {
    if (example) {
      exampleResponse("/api/session", { method: "PUT", body });
      lastSessionSaveAt = Date.now();
      return payload;
    }
    return fetch("/api/session", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body,
      keepalive: true,
    }).then((res) => {
      if (!res.ok) throw new Error("Session save failed");
      lastSessionSaveAt = Date.now();
      return res.json();
    });
  });
}

async function loadSession() {
  try {
    return await api("/api/session");
  } catch {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }
}

async function migrateLocalSession(serverSession) {
  if (await usesExample()) return serverSession;
  if (serverSession?.playlistId || serverSession?.trackId) {
    return serverSession;
  }
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return serverSession;
    const local = JSON.parse(raw);
    if (!local.playlistId && !local.trackId) return serverSession;
    return await pushSessionToServer({
      ...local,
      volume: Number(localStorage.getItem("volume") || state.volume),
      videoQuality: localStorage.getItem("videoQuality") || state.videoQuality,
    });
  } catch {
    return serverSession;
  }
}

function saveSession() {
  const payload = sessionPayload();
  pushSessionToServer(payload).catch(() => {
    localStorage.setItem(SESSION_KEY, JSON.stringify({ ...payload, savedAt: Date.now() }));
  });
}

function saveSessionDebounced() {
  clearTimeout(saveSessionTimer);
  saveSessionTimer = setTimeout(saveSession, 1500);
}

function bindSessionPersistence() {
  window.addEventListener("pagehide", saveSession);
  window.addEventListener("beforeunload", saveSession);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") {
      saveSession();
      return;
    }
    resumeFromSharedSession().catch(() => {});
  });
}

async function resumeFromSharedSession() {
  const session = await loadSession();
  if (!session?.savedAt || session.savedAt <= lastSessionSaveAt) return;
  if (session.volume != null) {
    state.volume = Number(session.volume) || 100;
    updateVolumeUI(state.volume);
    allMediaElements().forEach((media) => {
      media.volume = state.volume / 100;
    });
  }
  if (session.videoQuality) {
    state.videoQuality = session.videoQuality;
  }
  if (
    session.playlistId &&
    session.playlistId !== state.currentPlaylistId
  ) {
    await loadPlaylists(session.playlistId);
  }
  if (
    session.playlistId === state.currentPlaylistId &&
    session.trackId
  ) {
    const index = tracks().findIndex((track) => track.id === session.trackId);
    if (index >= 0 && !tracks()[index].missing) {
      const seekTime = Number(session.currentTime) || 0;
      const autoplay = Boolean(session.wasPlaying);
      await playIndex(index, seekTime, autoplay);
    }
  }
}

async function api(url, options = {}) {
  if (await usesExample()) return exampleResponse(url, options);
  const res = await fetch(url, options);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || "Request failed");
  return data;
}

function updatePlaylistActions() {
  const enabled = Boolean(state.currentPlaylistId);
  els.renamePlaylistBtn.disabled = !enabled;
  els.deletePlaylistBtn.disabled = !enabled;
  els.addTrackBtn.disabled = !enabled || (sourceChoice.value === 'online' && (onlineLoading || onlineAdding || !onlinePreview || !onlineSelection.size));
}

async function loadPlaylists(selectId = state.currentPlaylistId) {
  state.playlists = await api("/api/playlists");
  renderPlaylists();
  if (selectId && state.playlists.some((p) => p.id === selectId)) {
    await selectPlaylist(selectId);
  } else if (state.playlists.length) {
    await selectPlaylist(state.playlists[0].id);
  } else {
    state.currentPlaylistId = null;
    state.currentPlaylist = null;
    els.playlistName.textContent = "Select or create a playlist";
    renderTracks();
    updateQualityMenu(null);
    updatePlaylistActions();
    saveSession();
  }
}

function renderPlaylists() {
  els.playlistList.innerHTML = "";
  if (!state.playlists.length) {
    els.playlistList.innerHTML = `<div class="empty">No playlists yet.<br>Click + New to create one.</div>`;
    return;
  }

  state.playlists.forEach((playlist) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `playlist-item animate-fade-up${playlist.id === state.currentPlaylistId ? " active" : ""}`;
    btn.innerHTML = `
      <div class="playlist-icon">${icon("music")}</div>
      <div>
        <div class="track-name">${escapeHtml(playlist.name)}</div>
        <div class="track-type">${playlist.trackCount} tracks</div>
      </div>
    `;
    btn.addEventListener("click", () => selectPlaylist(playlist.id));
    els.playlistList.appendChild(btn);
  });
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function selectPlaylist(playlistId) {
  const changed = state.currentPlaylistId !== playlistId;
  state.currentPlaylistId = playlistId;
  state.currentPlaylist = await api(`/api/playlists/${playlistId}`);
  if (changed) {
    stopAll();
    state.index = -1;
  }
  els.playlistName.textContent = state.currentPlaylist.name;
  els.nowBadge.textContent = state.currentPlaylist.name;
  renderPlaylists();
  renderTracks();
  updateQualityMenu(currentTrack());
  updatePlaylistActions();
  saveSession();
}

function renderTracks() {
  els.trackList.innerHTML = "";
  const items = tracks();
  if (!state.currentPlaylistId) {
    els.trackList.innerHTML = `<div class="empty animate-fade-up">Create a playlist first.</div>`;
    return;
  }
  if (!items.length) {
    els.trackList.innerHTML = `<div class="empty animate-fade-up">No tracks yet.<br>Drag files above or add a path.</div>`;
    return;
  }

  items.forEach((track, index) => {
    const row = document.createElement("div");
    row.className = `track-item${index === state.index ? " active" : ""}`;
    row.dataset.index = String(index);
    row.dataset.id = track.id;
    row.dataset.online = String(track.source === 'online');
    row.innerHTML = `
      <div class="drag-handle" title="Drag to reorder">${icon("grip")}</div>
      <div class="track-index">${index + 1}</div>
      <button type="button" class="track-main">
        <div class="track-name">${escapeHtml(track.title)}</div>
        <div class="track-type ${track.missing ? "missing" : ""}">
          ${track.missing ? "missing · " : ""}${track.source === "online" ? "Online URL" : "Local file"} · ${track.kind || "audio"}
          ${track.videoHeight ? ` · ${track.videoHeight}p` : ""}
        </div>
      </button>
      <button type="button" class="remove-btn" title="Remove">${icon("x")}</button>
    `;

    row.querySelector(".track-main").addEventListener("click", () => {
      playIndex(Number(row.dataset.index));
    });
    row.querySelector(".remove-btn").addEventListener("click", async (e) => {
      e.stopPropagation();
      const ok = await openConfirm({
        title: "Remove track?",
        message: `Remove "${track.title}" from this playlist?`,
        variant: "danger",
        confirmLabel: "Remove",
      });
      if (!ok) return;
      const wasPlaying = Number(row.dataset.index) === state.index;
      await api(`/api/playlists/${state.currentPlaylistId}/items/${track.id}`, { method: "DELETE" });
      if (wasPlaying) {
        stopAll();
        state.index = -1;
        els.video.style.display = "none";
        els.audioArt.classList.remove("show", "playing");
        els.nowTitle.textContent = "No track selected";
        els.nowMeta.textContent = "Choose a track from the playlist";
        els.nowBadge.textContent = "";
        updatePlayButton(false);
      }
      await selectPlaylist(state.currentPlaylistId);
      await loadPlaylists(state.currentPlaylistId);
      showToast("Track removed", "success");
    });
    els.trackList.appendChild(row);
  });
}

function updateTrackActiveStates() {
  els.trackList.querySelectorAll(".track-item").forEach((row) => {
    row.classList.add("no-motion");
    row.classList.toggle("active", Number(row.dataset.index) === state.index);
  });
  requestAnimationFrame(() => {
    els.trackList.querySelectorAll(".track-item.no-motion").forEach((row) => {
      row.classList.remove("no-motion");
    });
  });
}

async function reorderTracks(fromIndex, toIndex) {
  if (fromIndex === toIndex) return;

  const items = [...tracks()];
  const [moved] = items.splice(fromIndex, 1);
  items.splice(toIndex, 0, moved);
  const playingId = currentTrack()?.id;

  state.currentPlaylist = { ...state.currentPlaylist, items };
  if (playingId) {
    state.index = items.findIndex((item) => item.id === playingId);
  }
  updateTrackActiveStates();

  clearTimeout(reorderTimer);
  reorderTimer = setTimeout(async () => {
    try {
      state.currentPlaylist = await api(
        `/api/playlists/${state.currentPlaylistId}/items/reorder`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ order: items.map((item) => item.id) }),
        },
      );
      if (playingId) {
        state.index = state.currentPlaylist.items.findIndex(
          (item) => item.id === playingId,
        );
      }
      saveSession();
    } catch (err) {
      showToast(err.message || "Could not reorder", "error");
      await selectPlaylist(state.currentPlaylistId);
    }
  }, 600);
}

initSortableList(els.trackList, {
  itemSelector: ".track-item",
  onReorder: reorderTracks,
});

function updateQualityMenu(track) {
  els.qualityMenu.innerHTML = "";
  if (!track || track.kind !== "video") {
    els.qualityTrigger.hidden = true;
    els.qualityWarn.hidden = true;
    return;
  }

  els.qualityTrigger.hidden = false;
  const qualities = track.qualities?.length
    ? track.qualities
    : [{ id: "original", label: "Source", available: true }];

  let activeLabel = "Source";

  qualities.forEach((q) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dropdown-item";
    btn.dataset.value = q.id;
    btn.textContent = q.label;
    if (q.available === false) {
      btn.classList.add("disabled");
      btn.disabled = true;
    }
    if (q.id === state.videoQuality && q.available !== false) {
      btn.classList.add("active");
      activeLabel = q.label;
    }
    els.qualityMenu.appendChild(btn);
  });

  const current = qualities.find((q) => q.id === state.videoQuality && q.available !== false);
  if (!current) {
    state.videoQuality = "original";
    saveSession();
    const source = qualities.find((q) => q.id === "original");
    activeLabel = source?.label || "Source";
    els.qualityMenu.querySelector('[data-value="original"]')?.classList.add("active");
  }

  els.qualityLabel.textContent = activeLabel.replace(/\s*—.*/, "").replace(/\s*\(.*/, "");
  els.qualityWarn.hidden = !(track.videoHeight && track.videoHeight < 720);
  if (!els.qualityWarn.hidden) {
    els.qualityWarn.textContent =
      `This file is ${track.videoHeight}p. Re-download with quality 720: python cut_url.py --config setlist.json --quality 720`;
  }
}

function showMediaMode(track) {
  if (track.kind === "video") {
    els.video.style.display = "block";
    els.audioArt.classList.remove("show", "playing");
    els.nowBadge.textContent = "Video";
    updateQualityMenu(track);
  } else {
    els.video.style.display = "none";
    els.audioArt.classList.add("show");
    els.nowBadge.textContent = "Audio";
    updateQualityMenu(null);
  }
}

function mediaUrl(track) {
  const quality =
    track.kind === "video" ? `&quality=${encodeURIComponent(state.videoQuality)}` : "";
  return `/api/media?playlist=${encodeURIComponent(state.currentPlaylistId)}&item=${encodeURIComponent(track.id)}${quality}`;
}

function stopAll() {
  allMediaElements().forEach((el) => {
    el.pause();
    el.removeAttribute("src");
    el.load();
  });
}

async function playIndex(index, seekTime = 0, autoplay = true) {
  const items = tracks();
  if (index < 0 || index >= items.length) return;
  const track = items[index];
  if (track.missing) return;
  if(track.source==='online'&&!navigator.onLine){showToast('You are offline. Connect to play this online track.','warning');return;}

  state.index = index;
  const url = mediaUrl(track);

  stopAll();
  showMediaMode(track);

  const el = track.kind === "video" ? els.video : els.audio;
  el.src = url;
  el.volume = state.volume / 100;

  els.nowTitle.textContent = track.title;
  const qualityNote =
    track.kind === "video" && state.videoQuality !== "original"
      ? ` · ${state.videoQuality}p`
      : track.videoHeight
        ? ` · ${track.videoHeight}p`
        : "";
  els.nowMeta.textContent = track.source === "online" ? `Online URL · ${track.kind} · Internet required` : `${(track.ext || "").toUpperCase()} · ${track.kind}${qualityNote}`;

  updateTrackActiveStates();

  const applySeek = () => {
    if (seekTime <= 0 || !Number.isFinite(el.duration)) return;
    el.currentTime = Math.min(seekTime, Math.max(0, el.duration - 0.25));
    updateProgress(el.currentTime, el.duration);
  };

  const waitForSeek = () =>
    new Promise((resolve) => {
      if (seekTime <= 0) {
        resolve();
        return;
      }
      if (el.readyState >= 1) {
        applySeek();
        resolve();
        return;
      }
      const timeout=setTimeout(()=>resolve(),30000);
      el.addEventListener('error',()=>{clearTimeout(timeout);resolve();},{once:true});
      el.addEventListener(
        "loadedmetadata",
        () => {
          clearTimeout(timeout);applySeek();
          resolve();
        },
        { once: true },
      );
    });

  try {
    await waitForSeek();
    if (autoplay) {
      await el.play();
      updatePlayButton(true);
      if (track.kind !== "video") els.audioArt.classList.add("playing");
    } else {
      updatePlayButton(false);
      els.audioArt.classList.remove("playing");
    }
    saveSession();
  } catch (err) {
    if (track.source !== "online" && track.kind === "video" && state.videoQuality !== "original") {
      showToast("Quality transcode failed — playing original", "warning");
      state.videoQuality = "original";
      saveSession();
      await playIndex(index, seekTime, autoplay);
      return;
    }
    updatePlayButton(false);
    els.audioArt.classList.remove("playing");
    saveSession();
    if(track.source==='online'&&err?.name!=='NotAllowedError'){
      const selected=state.videoQuality==='original'?'best available quality':`${state.videoQuality}p`;
      showToast(`Online ${selected} stream is unavailable. Choose Best available or a lower quality.`, 'error');
    }
    if (autoplay && err?.name === "NotAllowedError") {
      showToast("Click play to continue", "info");
    }
  }
}

function updatePlayButton(isPlaying) {
  setIcon(els.playBtn, isPlaying ? "pause" : "play");
  els.playBtn.classList.toggle("is-playing", isPlaying);
}

function getNextIndex(step = 1) {
  const items = tracks();
  if (!items.length) return -1;
  if (state.shuffle) {
    if (items.length === 1) return 0;
    let next = state.index;
    while (next === state.index) next = Math.floor(Math.random() * items.length);
    return next;
  }
  return (state.index + step + items.length) % items.length;
}

function handleTrackEnded() {
  if (state.repeat === "one") {
    playIndex(state.index);
    return;
  }
  const items = tracks();
  if (state.repeat === "all" || state.index < items.length - 1) {
    playIndex(getNextIndex(1));
    return;
  }
  updatePlayButton(false);
  els.audioArt.classList.remove("playing");
}

function bindMediaEvents(el) {
  el.addEventListener("timeupdate", () => {
    if (el !== mediaElement()) return;
    if (isScrubbingProgress) return;
    updateProgress(el.currentTime, el.duration);
    saveSessionDebounced();
  });
  el.addEventListener("loadedmetadata", () => {
    if (el !== mediaElement()) return;
    updateProgress(el.currentTime, el.duration);
    saveSessionDebounced();
  });
  el.addEventListener("ended", () => {
    if (el !== mediaElement()) return;
    handleTrackEnded();
  });
  el.addEventListener("play", () => {
    if (el === mediaElement()) {
      updatePlayButton(true);
      saveSession();
    }
  });
  el.addEventListener("pause", () => {
    if (el === mediaElement()) {
      updatePlayButton(false);
      saveSession();
    }
  });
}

function seekFromRatio(ratio) {
  const el = mediaElement();
  if (!el?.duration) return;
  const time = ratio * el.duration;
  el.currentTime = time;
  updateProgress(time, el.duration);
}

function setVolumeFromRatio(ratio) {
  const volume = Math.round(ratio * 100);
  state.volume = volume;
  updateVolumeUI(volume);
  allMediaElements().forEach((media) => {
    media.volume = volume / 100;
  });
  saveSessionDebounced();
}

bindScrubber(els.progressTrack, {
  onScrub: (ratio) => {
    isScrubbingProgress = true;
    seekFromRatio(ratio);
  },
  onEnd: () => {
    isScrubbingProgress = false;
    saveSession();
  },
});

bindScrubber(els.volumeTrack, {
  onScrub: setVolumeFromRatio,
});

async function toggleFullscreen() {
  if (!document.fullscreenElement) {
    await els.videoStage.requestFullscreen();
  } else {
    await document.exitFullscreen();
  }
}

initDropdown({
  root: els.qualityDropdown,
  trigger: els.qualityTrigger,
  menu: els.qualityMenu,
  onSelect: async (value, label) => {
    if (value === state.videoQuality) return;
    const track = currentTrack();
    const seek = mediaElement()?.currentTime || 0;
    state.videoQuality = value;
    els.qualityLabel.textContent = label.replace(/\s*\(.*\)/, "");
    saveSession();
    if (track?.kind === "video") {
      showToast(`Switching to ${label}`, "info");
      await playIndex(state.index, seek);
    }
  },
});

els.playBtn.addEventListener("click", async () => {
  const el = mediaElement();
  if (!el?.src) {
    if (tracks().length) await playIndex(0);
    return;
  }
  if (el.paused) {
    await el.play();
    if (currentTrack()?.kind !== "video") els.audioArt.classList.add("playing");
  } else {
    el.pause();
    els.audioArt.classList.remove("playing");
  }
});

els.prevBtn.addEventListener("click", () => {
  if (state.index <= 0) playIndex(tracks().length - 1);
  else playIndex(state.index - 1);
});
els.nextBtn.addEventListener("click", () => playIndex(getNextIndex(1)));
els.repeatBtn.addEventListener("click", cycleRepeat);
els.shuffleBtn.addEventListener("click", () => {
  state.shuffle = !state.shuffle;
  els.shuffleBtn.classList.toggle("active", state.shuffle);
  saveSession();
});
els.fullscreenBtn.addEventListener("click", toggleFullscreen);

els.newPlaylistBtn.addEventListener("click", async () => {
  const name = await openPrompt({
    title: "New playlist",
    label: "Playlist name",
    defaultValue: "My playlist",
    confirmLabel: "Create",
  });
  if (!name) return;
  const playlist = await api("/api/playlists", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  await loadPlaylists(playlist.id);
  showToast("Playlist created", "success");
});

els.renamePlaylistBtn.addEventListener("click", async () => {
  if (!state.currentPlaylistId) return;
  const name = await openPrompt({
    title: "Rename playlist",
    label: "New name",
    defaultValue: state.currentPlaylist?.name || "",
    confirmLabel: "Save",
  });
  if (!name) return;
  await api(`/api/playlists/${state.currentPlaylistId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  await loadPlaylists(state.currentPlaylistId);
  showToast("Playlist renamed", "success");
});

els.deletePlaylistBtn.addEventListener("click", async () => {
  if (!state.currentPlaylistId) return;
  const ok = await openConfirm({
    title: "Delete playlist?",
    message: `Delete "${state.currentPlaylist?.name}" and all its tracks?`,
    variant: "danger",
    confirmLabel: "Delete",
  });
  if (!ok) return;
  await api(`/api/playlists/${state.currentPlaylistId}`, { method: "DELETE" });
  state.currentPlaylistId = null;
  await loadPlaylists();
  showToast("Playlist deleted", "success");
});

els.addTrackBtn.addEventListener("click", async () => {
  if (!state.currentPlaylistId) return;
  const title = els.trackTitle.value.trim();
  if(sourceChoice.value==='online'){
   if(!onlinePreview||!onlineSelection.size||onlineAdding)return;
   onlineAdding=true;els.addTrackBtn.disabled=true;
   try{
    const result=await api(`/api/playlists/${state.currentPlaylistId}/online-items`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({preview_id:onlinePreview.id,indexes:[...onlineSelection],playback:playbackChoice.value,title})});
    clearOnlinePreview();els.trackTitle.value='';await selectPlaylist(state.currentPlaylistId);await loadPlaylists(state.currentPlaylistId);showToast(result.added+' online track(s) added','success');
   }catch(error){showToast(error.message,'error');}finally{onlineAdding=false;updatePlaylistActions();}
   return;
  }
  const files = fileUpload.getFiles();
  const path = els.filePath.value.trim();

  try {
    if (files.length) {
      els.addTrackBtn.disabled = true;
      let added = 0;
      for (const file of files) {
        const form = new FormData();
        form.append("file", file);
        const trackTitle =
          files.length === 1 && title
            ? title
            : file.name.replace(/\.[^.]+$/, "");
        form.append("title", trackTitle);
        await api(`/api/playlists/${state.currentPlaylistId}/items`, { method: "POST", body: form });
        added += 1;
      }
      els.trackTitle.value = "";
      fileUpload.clear();
      els.filePath.value = "";
      await selectPlaylist(state.currentPlaylistId);
      await loadPlaylists(state.currentPlaylistId);
      showToast(
        added === 1 ? "Track added" : `${added} tracks added`,
        "success",
      );
    } else if (path) {
      await api(`/api/playlists/${state.currentPlaylistId}/items`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path, title: title || path.split(/[\\/]/).pop() }),
      });
      els.trackTitle.value = "";
      fileUpload.clear();
      els.filePath.value = "";
      await selectPlaylist(state.currentPlaylistId);
      await loadPlaylists(state.currentPlaylistId);
      showToast("Track added", "success");
    } else {
      showToast("Pick file(s) or enter a file path", "warning");
      return;
    }
  } catch (err) {
    showToast(err.message || "Could not add track", "error");
  } finally {
    updatePlaylistActions();
  }
});

allMediaElements().forEach(bindMediaEvents);
bindSessionPersistence();
initCollapsiblePanels(document);
mountIcons(document);
setIcon(els.shuffleBtn, "shuffle");
setIcon(els.prevBtn, "skip-back");
setIcon(els.nextBtn, "skip-forward");
setIcon(els.volumeIcon, "volume");
updatePlayButton(false);
updateVolumeUI(state.volume);

async function bootstrap() {
  if (await usesExample()) {
    const note = document.querySelector(".brand .muted");
    if (note) note.textContent = "Example player";
  }
  let session = await loadSession();
  session = await migrateLocalSession(session);
  lastSessionSaveAt = Number(session?.savedAt) || 0;

  if (session?.volume != null) {
    state.volume = Number(session.volume) || 100;
    updateVolumeUI(state.volume);
  }
  if (session?.videoQuality) {
    state.videoQuality = session.videoQuality;
  }

  if (session?.shuffle) {
    state.shuffle = true;
    els.shuffleBtn.classList.add("active");
  }
  setRepeatMode(session?.repeat || "off");

  await loadPlaylists(session?.playlistId || null);

  if (
    session?.playlistId &&
    session.playlistId === state.currentPlaylistId &&
    session.trackId
  ) {
    const index = tracks().findIndex((track) => track.id === session.trackId);
    if (index >= 0 && !tracks()[index].missing) {
      const seekTime = Number(session.currentTime) || 0;
      const autoplay = Boolean(session.wasPlaying);
      await playIndex(index, seekTime, autoplay);
      const el = mediaElement();
      if (seekTime > 2 && (!autoplay || (el && !el.paused))) {
        showToast("Continued where you left off", "info");
      }
      return;
    }
  }

  saveSession();
}

bootstrap();
