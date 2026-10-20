const status = document.querySelector('#connectionStatus');
const button = document.querySelector('#connectRetry');
let token, timeout, needsReload = false;

async function start() {
  button.disabled = true;
  try {
    if (!token) {
      const r = await fetch('/api/accounts/connect', {method: 'POST', headers: {'Content-Type': 'application/json', 'X-Trim-Playlist': '1'}, body: JSON.stringify({platform: new URLSearchParams(location.search).get('platform')})});
      const data = await r.json().catch(() => ({}));
      if (!r.ok) throw Error(data.error || "Open Trim Playlist on this computer, then connect. The extension reaches the app while it is running.");
      token = data.token;
    }
    status.textContent = 'Contacting the browser extension…';
    window.postMessage({type: 'trim-playlist-connect', token}, location.origin);
    timeout = setTimeout(() => {
      status.textContent = 'Trim Playlist Account Connector was not detected. Install it, then reload this page.';
      needsReload = true;
      button.textContent = 'Reload connection page';
      button.disabled = false;
    }, 3000);
  } catch (error) {
    status.textContent = error.message;
    button.disabled = false;
  }
}

window.addEventListener('message', event => {
  if (event.source !== window || event.origin !== location.origin || event.data?.type !== 'trim-playlist-connection') return;
  clearTimeout(timeout);
  needsReload = false;
  button.textContent = 'Start connection';
  status.textContent = event.data.error || 'Sign in on the platform tab. Waiting for your account session…';
  button.disabled = !event.data.error;
});

button.onclick = () => needsReload ? location.reload() : start();
start();
