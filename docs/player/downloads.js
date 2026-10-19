import {showToast, initDropdown} from './ui.js';
import {addCreateCookieButton} from './cookies.js';
import {exampleHome, exampleResponse, usesExample} from './example.js';
import {icon} from './icons.js';
const panel=document.createElement('div');
panel.className='download-view';panel.hidden=true;
panel.innerHTML=`<form class="card download-form">
<div class="section-head"><h2>Trim URL</h2><button type="button" class="btn btn-ghost" id="downloadClose">Back to playlist</button></div>
<label class="field">Download type<select class="input" name="source_kind"><option value="video">Single video</option><option value="playlist">Entire playlist</option></select></label>
<label class="field"><span id="downloadUrlLabel">Video URL</span><input class="input" name="url" type="url" required placeholder="https://…"></label>
<label class="field" id="downloadMode">Mode<select class="input" name="mode"><option value="full">Full download</option><option value="trim">Trim</option></select></label>
<label class="field">Format<select class="input" name="format"><option value="mp4">MP4 video</option><option value="mp3">MP3 music</option></select></label>
<label class="field" id="downloadQuality">Video quality<select class="input" name="quality"><option value="best">Best available</option><option>1080</option><option>720</option><option>480</option><option>360</option></select></label>
<p class="muted" id="downloadPlaylist" hidden>Playlist downloads always use Full mode and each video’s original title.</p>
<label class="field" id="downloadAudioQuality" hidden>MP3 quality<select class="input" name="audio_quality"><option value="best">Best quality (VBR)</option><option value="320">320 kbps</option><option value="256">256 kbps</option><option value="192">192 kbps</option><option value="128">128 kbps</option><option value="96">96 kbps</option><option value="64">64 kbps</option></select></label>
<div id="downloadTrim" hidden><label class="field">Filename (optional)<input class="input" name="name" placeholder="Use original title"></label><label class="field">Start<input class="input" name="start" placeholder="0:00"></label><label class="field">End<input class="input" name="end" placeholder="3:30"></label></div>
<label class="field">Authentication<select class="input" name="auth_source"><option value="cookie">Cookie file</option><option value="extension">Extension account</option><option value="platform">Platform account</option><option value="none">No authentication</option></select></label>
<div id="authPlatform" hidden><label class="field">Platform<select class="input" name="platform"><option value="youtube">YouTube</option><option value="facebook">Facebook</option><option value="instagram">Instagram</option><option value="x">X / Twitter</option><option value="tiktok">TikTok</option><option value="twitch">Twitch</option></select></label><div id="accountList" class="account-list"></div><div id="extensionConnect"><a id="connectPlatform" class="btn btn-outline" target="_blank" rel="noopener noreferrer">Connect with the extension</a><p class="muted">Extension account is the browser connection. It uses Trim Playlist Account Connector and connects the same way as before.</p></div><div id="appSignInBox" hidden><button type="button" id="appSignIn" class="btn btn-outline">Sign in</button><p id="appSignInStatus" class="muted">Platform account signs in inside the Trim Playlist window, like the phone. It does not open a browser tab and it does not use the extension.</p></div></div>
<label class="field" id="authCookie">Cookies<input type="hidden" name="cookies" value=""><div id="cookieSelect"></div></label><label class="field">Volume multiplier<input class="input" name="volume" type="number" min="0" max="10" step="0.1" value="1"><span class="muted">1 = original volume · 2 = boost</span></label>
<p class="muted">Full downloads use each video's original title. Files save in output/; add them to your playlist using the file picker.</p>
<section id="playlistPicker" class="playlist-picker" hidden aria-label="Choose playlist items"></section><button class="btn btn-primary" type="submit">Start download</button><div class="download-progress" role="progressbar" aria-valuemin="0" aria-valuemax="100"><div class="bg-brand-gradient"></div></div><p id="downloadStatus" role="status"></p>
</form>`;
document.querySelector('.app').append(panel);
const form=panel.querySelector('form'),status=panel.querySelector('#downloadStatus');
function customSelect(input, options, host){
 const root=document.createElement('div');root.className='dropdown download-select';
 const trigger=document.createElement('button');trigger.type='button';trigger.className='input dropdown-trigger';trigger.setAttribute('aria-expanded','false');trigger.setAttribute('aria-haspopup','listbox');
 const label=document.createElement('span');trigger.append(label);trigger.insertAdjacentHTML('beforeend',icon('chevron-down'));
 const menu=document.createElement('div');menu.className='dropdown-menu';menu.setAttribute('role','listbox');root.append(trigger,menu);
 function syncLabel(){label.textContent=[...menu.children].find(b=>b.dataset.value===input.value)?.textContent||menu.firstChild?.textContent||'None';}
 function fill(values){menu.replaceChildren();values.forEach(([value,text])=>{const b=document.createElement('button');b.type='button';b.className='dropdown-item';b.dataset.value=value;b.textContent=text;b.setAttribute('role','option');menu.append(b);});label.textContent=values.find(([v])=>v===input.value)?.[1]||values[0]?.[1]||'None';}
 fill(options);initDropdown({root,trigger,menu,onSelect:(value,text)=>{input.value=value;label.textContent=text;input.dispatchEvent(new Event('change',{bubbles:true}));}});
 trigger.addEventListener('keydown',e=>{if(e.key==='Escape'){menu.classList.remove('open');trigger.setAttribute('aria-expanded','false');}if(e.key==='ArrowDown'){e.preventDefault();menu.classList.add('open');menu.querySelector('button')?.focus();}});
 menu.addEventListener('keydown',e=>{const buttons=[...menu.querySelectorAll('button')];let i=buttons.indexOf(document.activeElement);if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();buttons[(i+(e.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length]?.focus();}if(e.key==='Escape'){menu.classList.remove('open');trigger.focus();}});
 if(host)host.append(root);else input.after(root);return {fill,trigger,syncLabel,setDisabled(disabled){trigger.disabled=disabled;trigger.setAttribute('aria-disabled',String(disabled));if(disabled){menu.classList.remove('open');trigger.setAttribute('aria-expanded','false');}}};
}
const selects={};
for(const select of [...form.querySelectorAll('select')]){const options=[...select.options].map(o=>[o.value,o.textContent]);const input=document.createElement('input');input.type='hidden';input.name=select.name;input.value=select.value;select.replaceWith(input);selects[input.name]=customSelect(input,options);}
const cookies=customSelect(form.elements.cookies,[['','No cookies']],panel.querySelector('#cookieSelect'));
const cookieStatus=document.createElement('span');cookieStatus.className='muted';cookieStatus.setAttribute('role','status');panel.querySelector('#cookieSelect').after(cookieStatus);
let cookieRequest;
function refreshCookies(){
 if(cookieRequest)return cookieRequest;
 cookieStatus.textContent='Reading cookies folder…';
 cookieRequest=(async()=>{try{
  let names;
  if(await usesExample()) names=exampleResponse('/api/cookies');
  else {
   const response=await fetch('/api/cookies',{cache:'no-store'});
   if(!response.ok)throw Error('Cookies request failed (HTTP '+response.status+')');
   names=await response.json();
  }
  if(!Array.isArray(names)||names.some(n=>typeof n!=='string'))throw Error('Invalid cookies response');
  if(!names.includes(form.elements.cookies.value))form.elements.cookies.value='';
  cookies.fill([['','No cookies'],...names.map(n=>[n,n])]);
  cookieStatus.textContent=names.length?names.length+' cookie files found':(await usesExample()?'No cookie files yet. Create one with Manual .txt or Import .txt file.':'No .txt files found in the server’s cookies folder.');
 }catch(e){cookieStatus.textContent=e.message;showToast(e.message,'error');}
 finally{cookieRequest=null;}})();
 return cookieRequest;
}
cookies.trigger.addEventListener('click',refreshCookies);
refreshCookies();
addCreateCookieButton(panel.querySelector('#authCookie'), async name=>{form.elements.cookies.value=name;await refreshCookies();cookies.syncLabel();});

const app=document.querySelector('.app'),menu=document.querySelector('#appMenu'),switchButton=document.querySelector('#appSwitch');
const websiteHome=document.querySelector('#websiteHome');
if(websiteHome) websiteHome.href=exampleHome();
function selectView(view){const url=view==='url';app.classList.toggle('url-view',url);panel.hidden=!url;if(url)refreshCookies();document.querySelector('#appTitle').textContent=url?'Trim URL':'Trim Playlist';document.title=url?'Trim URL':'Trim Playlist';menu.hidden=true;switchButton.setAttribute('aria-expanded','false');}
switchButton.onclick=()=>{menu.hidden=!menu.hidden;switchButton.setAttribute('aria-expanded',String(!menu.hidden));};
menu.querySelectorAll('[data-view]').forEach(button=>button.onclick=()=>selectView(button.dataset.view));
document.addEventListener('click',event=>{if(!event.target.closest('.app-switch')){menu.hidden=true;switchButton.setAttribute('aria-expanded','false');}});
panel.querySelector('#downloadClose').onclick=()=>selectView('playlist');
function updateDownloadType(){
 const playlist=form.elements.source_kind.value==='playlist';
 if(playlist)form.elements.mode.value='full';
 selects.mode.fill(playlist?[['full','Full download']]:[['full','Full download'],['trim','Trim']]);
 selects.mode.setDisabled(playlist);
 panel.querySelector('#downloadUrlLabel').textContent=playlist?'Playlist URL':'Video URL';
 panel.querySelector('#downloadMode').hidden=false;
 panel.querySelector('#downloadPlaylist').hidden=!playlist;
 panel.querySelector('#downloadTrim').hidden=playlist||form.elements.mode.value!=='trim';
}
form.elements.source_kind.onchange=updateDownloadType;
form.elements.mode.onchange=updateDownloadType;
function updateFormat(){const audio=form.elements.format.value==='mp3';panel.querySelector('#downloadQuality').hidden=audio;panel.querySelector('#downloadAudioQuality').hidden=!audio;}
form.elements.format.onchange=updateFormat;
updateDownloadType();
updateFormat();
const picker=panel.querySelector('#playlistPicker');
let preview=null,busy=false;
function clearPreview(){form.querySelector('[type=submit]').disabled=busy;preview=null;picker.hidden=true;picker.replaceChildren();form.querySelector('[type=submit]').textContent='Start download';}
function requestData(){const data=Object.fromEntries(new FormData(form));data.playlist=data.source_kind==='playlist';if(data.playlist)data.mode='full';if(data.auth_source!=='cookie')data.cookies='';return data;}
form.addEventListener('input',clearPreview);form.addEventListener('change',clearPreview);
async function waitJob(id,progress){let job;do{await new Promise(r=>setTimeout(r,500));const r=await fetch('/api/downloads/'+id,{cache:'no-store'});if(!r.ok)throw Error('Could not read download progress');job=await r.json();progress(job);}while(job.status==='running');if(job.status==='error')throw Error(job.message);return job;}
function showPicker(result,data){
 preview={data,key:JSON.stringify(requestData()),selected:new Set()};picker.hidden=false;picker.replaceChildren();
 const heading=document.createElement('h3');heading.textContent=result.title;picker.append(heading);
 const hint=document.createElement('p');hint.className='muted';hint.textContent=data.mode==='trim'?'Choose one video to trim.':'Choose one or more videos to download. Nothing has been downloaded yet.';picker.append(hint);
 const count=document.createElement('p');count.className='muted';picker.append(count);
 const list=document.createElement('div');list.className='playlist-picker-list';picker.append(list);
 const submit=form.querySelector('[type=submit]');
 const sync=()=>{count.textContent=preview.selected.size+' selected · '+result.items.length+' items';submit.textContent='Download selected';submit.disabled=busy||!preview.selected.size;};
 for(const item of result.items){
  const row=document.createElement('button');row.type='button';row.className='playlist-choice';row.setAttribute('role','checkbox');row.setAttribute('aria-checked','false');row.disabled=!item.available;
  const check=document.createElement('span');check.className='choice-check';check.innerHTML=icon('check');
  const label=document.createElement('span');label.textContent=item.index+'. '+item.title+(item.available?'':' · Unavailable');row.append(check,label);list.append(row);
  row.onclick=()=>{if(data.mode==='trim'){preview.selected.clear();list.querySelectorAll('[aria-checked]').forEach(b=>b.setAttribute('aria-checked','false'));}else if(preview.selected.has(item.index)){preview.selected.delete(item.index);row.setAttribute('aria-checked','false');sync();return;}preview.selected.add(item.index);row.setAttribute('aria-checked','true');sync();};
 }
 const cancel=document.createElement('button');cancel.type='button';cancel.className='btn btn-ghost';cancel.textContent='Cancel selection';cancel.onclick=()=>{clearPreview();submit.disabled=false;status.textContent='Selection cancelled';};picker.append(cancel);sync();picker.scrollIntoView({behavior:'smooth',block:'nearest'});
}
form.onsubmit=async e=>{e.preventDefault();const button=form.querySelector('[type=submit]');if(busy)return;busy=true;button.disabled=true;let selecting=false;
 try{
  let data=requestData();
  if(!data.playlist&&!preview){
   status.textContent='Checking URL and loading playlist items…';
   const r=await fetch('/api/downloads/preview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});const response=await r.json();if(!r.ok)throw Error(response.error);
   const result=await waitJob(response.id,job=>status.textContent=job.message);
   if(JSON.stringify(data)!==JSON.stringify(requestData())){status.textContent='Settings changed. Click Start download again.';return;}
   if(result.is_playlist){showPicker(result,data);selecting=true;return;}
  }
  if(preview){if(preview.key!==JSON.stringify(requestData()))throw Error('Settings changed. Load the playlist again.');data={...preview.data,selected_items:[...preview.selected]};if(!data.selected_items.length)throw Error('Choose at least one video');}
  const r=await fetch('/api/downloads',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});const response=await r.json();if(!r.ok)throw Error(response.error);
  await waitJob(response.id,job=>{panel.querySelector('.download-progress div').style.width=(job.percent||0)+'%';panel.querySelector('.download-progress').setAttribute('aria-valuenow',job.percent||0);status.textContent=job.message+(job.percent!=null?' · '+Number(job.percent).toFixed(1)+'%':'')+(job.files?.length?' · '+job.files.length+' files saved':'');});
  clearPreview();showToast('Download complete','success');
 }catch(error){status.textContent=error.message;showToast(error.message,'error');}
 finally{busy=false;button.disabled=selecting?!preview?.selected.size:false;}
};

// Persist the downloader separately from playback fields in the shared session.
let draftTimer, draftTouched=false, draftReady=false;
let draftWrites=Promise.resolve();
function downloadDraft(){return Object.fromEntries(new FormData(form));}
function saveDownloadDraft(){
 clearTimeout(draftTimer);
 if(!draftReady&&!draftTouched)return;
 const body=JSON.stringify({trimUrlForm:downloadDraft()});
 draftWrites=draftWrites.catch(()=>{}).then(async()=>{
  if(await usesExample()){exampleResponse('/api/session',{method:'PUT',body});return;}
  const response=await fetch('/api/session',{method:'PUT',headers:{'Content-Type':'application/json'},body,keepalive:true});
  if(!response.ok)throw Error('Could not save Trim URL fields');
 });
 draftWrites.catch(error=>showToast(error.message,'error'));
}
function draftChanged(){draftTouched=true;clearTimeout(draftTimer);draftTimer=setTimeout(saveDownloadDraft,250);}
form.addEventListener('input',draftChanged);
form.addEventListener('change',draftChanged);
form.addEventListener('submit',saveDownloadDraft);
window.addEventListener('pagehide',saveDownloadDraft);
document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden')saveDownloadDraft();});
(async()=>{
 try{
  let saved;
  if(await usesExample()) saved=exampleResponse('/api/session').trimUrlForm;
  else {
   const response=await fetch('/api/session',{cache:'no-store'});
   if(!response.ok)throw Error('Could not restore Trim URL fields');
   saved=(await response.json()).trimUrlForm;
  }
  if(saved&&!draftTouched){
   for(const [name,value] of Object.entries(saved)){
    const input=form.elements.namedItem(name);
    if(!input||typeof value!=='string')continue;
    const select=selects[name];
    if(select&&!select.trigger.parentElement.querySelector(`[data-value="${CSS.escape(value)}"]`))continue;
    input.value=value;
    select?.syncLabel();
   }
   updateDownloadType();updateFormat();updateAuthentication();
   await refreshCookies();cookies.syncLabel();
  }
 }catch(error){showToast(error.message,'error');}
 finally{draftReady=true;}
})();


// Only the chosen authentication method and platform are displayed.
const accountList=panel.querySelector('#accountList'),connectLink=panel.querySelector('#connectPlatform');
let accountPolling=false,connectingPlatform=null;const accountVersions=new Map();
function updateAuthentication(){
 const source=form.elements.auth_source.value;
 const account=source==='extension'||source==='platform';
 panel.querySelector('#authPlatform').hidden=!account;
 panel.querySelector('#extensionConnect').hidden=source!=='extension';
 panel.querySelector('#appSignInBox').hidden=source!=='platform';
 panel.querySelector('#authCookie').hidden=source!=='cookie';
 connectLink.href='/connect.html?platform='+encodeURIComponent(form.elements.platform.value);
 if(account)refreshAccounts();
}
form.elements.auth_source.onchange=updateAuthentication;
form.elements.platform.onchange=()=>{accountList.replaceChildren();updateAuthentication();};
connectLink.onclick=()=>{connectingPlatform={platform:form.elements.platform.value,previous:accountVersions.get(form.elements.platform.value)||0};};
panel.querySelector('#appSignIn').onclick=async()=>{
 const platform=form.elements.platform.value;
 connectingPlatform={platform,previous:accountVersions.get(platform)||0};
 const statusLine=panel.querySelector('#appSignInStatus');
 if(!window.pywebview?.api?.sign_in){statusLine.textContent='Platform account signs in inside the Trim Playlist app window. In a browser, use Extension account.';return;}
 statusLine.textContent='Opening sign-in in the app window…';
 try{const result=await window.pywebview.api.sign_in(platform);if(result&&result.error)throw Error(result.error);}
 catch(error){statusLine.textContent=error.message||'Could not open sign-in';}
};
async function refreshAccounts(){
 if(accountPolling||!['extension','platform'].includes(form.elements.auth_source.value))return;accountPolling=true;
 try{
  const r=await fetch('/api/accounts',{cache:'no-store'});if(!r.ok)throw Error('Could not load account connection');
  const accounts=await r.json();const account=accounts.find(a=>a.platform===form.elements.platform.value);accountList.replaceChildren();if(!account)return;
  const row=document.createElement('div');row.className='account-row';const text=document.createElement('span');text.textContent=account.name+' · '+(account.connected?'Signed in (saved session)':'Not connected');row.append(text);
  if(account.connected){const button=document.createElement('button');button.type='button';button.className='btn btn-ghost';button.textContent='Disconnect';button.onclick=async()=>{button.disabled=true;try{const r=await fetch('/api/accounts/'+account.platform,{method:'DELETE',headers:{'X-Trim-Playlist':'1'}});if(!r.ok)throw Error('Could not disconnect');accountPolling=false;await refreshAccounts();}catch(error){showToast(error.message,'error');button.disabled=false;}};row.append(button);}
  accountList.append(row);
  if(account.connected&&connectingPlatform?.platform===account.platform&&account.updatedAt!==connectingPlatform.previous){connectingPlatform=null;showToast(account.name+' session connected','success');}
  accountVersions.set(account.platform,account.updatedAt);
 }catch(error){accountList.textContent=error.message;}finally{accountPolling=false;}
}
updateAuthentication();
setInterval(()=>{if(app.classList.contains('url-view')&&document.visibilityState==='visible')refreshAccounts();},2500);
