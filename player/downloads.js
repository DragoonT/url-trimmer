import {showToast, initDropdown} from './ui.js';
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
<div class="field"><span class="field-label">Platform account</span><div class="dropdown download-select" id="platformLogin"><button type="button" class="input dropdown-trigger" aria-haspopup="menu" aria-expanded="false"><span>Sign in to platform</span><span data-login-chevron></span></button><div class="dropdown-menu" role="menu"></div></div><span class="muted">Connect through the Account Connector extension in your browser. Sessions save locally; use Disconnect to remove a saved session.</span></div>
<label class="field">Cookies<input type="hidden" name="cookies" value=""><div id="cookieSelect"></div></label><label class="field">Volume multiplier<input class="input" name="volume" type="number" min="0" max="10" step="0.1" value="1"><span class="muted">1 = original volume · 2 = boost</span></label>
<p class="muted">Full downloads use each video's original title. Files save in output/; add them to your playlist using the file picker.</p>
<button class="btn btn-primary" type="submit">Start download</button><div class="download-progress" role="progressbar" aria-valuemin="0" aria-valuemax="100"><div class="bg-brand-gradient"></div></div><p id="downloadStatus" role="status"></p>
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
  const response=await fetch('/api/cookies',{cache:'no-store'});
  if(!response.ok)throw Error('Cookies request failed (HTTP '+response.status+')');
  const names=await response.json();
  if(!Array.isArray(names)||names.some(n=>typeof n!=='string'))throw Error('Invalid cookies response');
  if(!names.includes(form.elements.cookies.value))form.elements.cookies.value='';
  cookies.fill([['','No cookies'],...names.map(n=>[n,n])]);
  cookieStatus.textContent=names.length?names.length+' cookie files found':'No .txt files found in the server’s cookies folder.';
 }catch(e){cookieStatus.textContent=e.message;showToast(e.message,'error');}
 finally{cookieRequest=null;}})();
 return cookieRequest;
}
cookies.trigger.addEventListener('click',refreshCookies);
refreshCookies();

const app=document.querySelector('.app'),menu=document.querySelector('#appMenu'),switchButton=document.querySelector('#appSwitch');
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
form.onsubmit=async e=>{e.preventDefault();const button=form.querySelector('[type=submit]');button.disabled=true;
try {const data=Object.fromEntries(new FormData(form));data.playlist=form.elements.source_kind.value==='playlist';if(data.playlist)data.mode='full';
const response=await fetch('/api/downloads',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});const result=await response.json();if(!response.ok)throw Error(result.error);
let job;do{await new Promise(r=>setTimeout(r,750));job=await (await fetch('/api/downloads/'+result.id)).json();panel.querySelector('.download-progress div').style.width=(job.percent||0)+'%';panel.querySelector('.download-progress').setAttribute('aria-valuenow',job.percent||0);status.textContent=job.message+(job.percent!=null?' · '+Number(job.percent).toFixed(1)+'%':'')+(job.files?.length?' · '+job.files.length+' files saved':'');}while(job.status==='running');
if(job.status==='error')throw Error(job.message);showToast('Download complete','success');
}catch(err){status.textContent=err.message;showToast(err.message,'error');}finally{button.disabled=false;}};


// Persist the downloader separately from playback fields in the shared session.
let draftTimer, draftTouched=false, draftReady=false;
let draftWrites=Promise.resolve();
function downloadDraft(){return Object.fromEntries(new FormData(form));}
function saveDownloadDraft(){
 clearTimeout(draftTimer);
 if(!draftReady&&!draftTouched)return;
 const body=JSON.stringify({trimUrlForm:downloadDraft()});
 draftWrites=draftWrites.catch(()=>{}).then(async()=>{
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
  const response=await fetch('/api/session',{cache:'no-store'});
  if(!response.ok)throw Error('Could not restore Trim URL fields');
  const saved=(await response.json()).trimUrlForm;
  if(saved&&!draftTouched){
   for(const [name,value] of Object.entries(saved)){
    const input=form.elements.namedItem(name);
    if(!input||typeof value!=='string')continue;
    const select=selects[name];
    if(select&&!select.trigger.parentElement.querySelector(`[data-value="${CSS.escape(value)}"]`))continue;
    input.value=value;
    select?.syncLabel();
   }
   updateDownloadType();updateFormat();
   await refreshCookies();cookies.syncLabel();
  }
 }catch(error){showToast(error.message,'error');}
 finally{draftReady=true;}
})();


// Native target=_blank links use the system browser in the desktop runtime.
const loginRoot=panel.querySelector('#platformLogin');
const loginTrigger=loginRoot.querySelector('button');
const loginMenu=loginRoot.querySelector('.dropdown-menu');
loginRoot.querySelector('[data-login-chevron]').innerHTML=icon('chevron-down');
const platforms=[
 ['YouTube','https://www.youtube.com/'],
 ['Facebook','https://www.facebook.com/login/'],
 ['Instagram','https://www.instagram.com/accounts/login/'],
 ['X / Twitter','https://x.com/i/flow/login'],
 ['TikTok','https://www.tiktok.com/login'],
 ['Twitch','https://www.twitch.tv/login'],
];
for(const [name,url] of platforms){
 const link=document.createElement('a');link.className='dropdown-item';link.textContent=name;
 const keys={'YouTube':'youtube','Facebook':'facebook','Instagram':'instagram','X / Twitter':'x','TikTok':'tiktok','Twitch':'twitch'};
 link.href='/connect.html?platform='+keys[name];link.target='_blank';link.rel='noopener noreferrer';link.dataset.value=name;link.setAttribute('role','menuitem');loginMenu.append(link);
}
initDropdown({root:loginRoot,trigger:loginTrigger,menu:loginMenu});

const accountList=document.createElement('div');accountList.className='account-list';loginRoot.after(accountList);
const accountNote=document.createElement('span');accountNote.className='muted';accountNote.textContent='Signed-in status reflects the saved session checked during connection. A session can expire or be revoked by the platform.';accountList.after(accountNote);
let connectingPlatform=null,accountPolling=false;const accountVersions=new Map();
loginMenu.addEventListener('click',event=>{const link=event.target.closest('a');if(link){const platform=new URL(link.href).searchParams.get('platform');connectingPlatform={platform,previous:accountVersions.get(platform)||0};}});
async function refreshAccounts(){
 if(accountPolling)return;accountPolling=true;
 try{
  const response=await fetch('/api/accounts',{cache:'no-store'});if(!response.ok)throw Error('Could not load account connections');
  const accounts=await response.json();accountList.replaceChildren();
  for(const account of accounts){
   const row=document.createElement('div');row.className='account-row';
   const text=document.createElement('span');text.textContent=account.name+' · '+(account.connected?'Signed in (saved session)':'Not connected');row.append(text);
   if(account.connected){
    const button=document.createElement('button');button.type='button';button.className='btn btn-ghost';button.textContent='Disconnect';
    button.onclick=async()=>{button.disabled=true;try{const r=await fetch('/api/accounts/'+account.platform,{method:'DELETE',headers:{'X-Trim-Playlist':'1'}});if(!r.ok)throw Error('Could not disconnect');if(form.elements.cookies.value===account.filename){form.elements.cookies.value='';saveDownloadDraft();}await refreshCookies();accountPolling=false;await refreshAccounts();}catch(e){showToast(e.message,'error');button.disabled=false;}};row.append(button);
    if(connectingPlatform?.platform===account.platform&&account.updatedAt!==connectingPlatform.previous){await refreshCookies();form.elements.cookies.value=account.filename;cookies.syncLabel();saveDownloadDraft();connectingPlatform=null;showToast(account.name+' session connected','success');}
   }
   accountVersions.set(account.platform,account.updatedAt);accountList.append(row);
  }
 }catch(error){if(!accountList.children.length)accountList.textContent=error.message;}
 finally{accountPolling=false;}
}
refreshAccounts();
setInterval(()=>{if(app.classList.contains('url-view')&&document.visibilityState==='visible')refreshAccounts();},2500);
