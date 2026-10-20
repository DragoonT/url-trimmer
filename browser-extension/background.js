const busy=new Set();
async function sessions(){return (await chrome.storage.session.get('connections')).connections||{};}
let mutations=Promise.resolve();
function mutate(fn){const result=mutations.catch(()=>{}).then(async()=>{const s=await sessions();const value=fn(s);await chrome.storage.session.set({connections:s});return value;});mutations=result;return result;}
function localPage(url){const u=new URL(url);if(u.protocol!=='http:'||!['127.0.0.1','localhost'].includes(u.hostname)||u.pathname!=='/connect.html')throw Error('Open connection from Trim Playlist');return u;}
async function request(job,options){const r=await fetch(job.origin+'/api/accounts/pair/'+encodeURIComponent(job.token),options);const data=await r.json();if(!r.ok)throw Error(data.error||'Connection failed');return data;}
async function begin(token,sender){
 const u=localPage(sender.tab?.url||'');
 if(typeof token!=='string'||!/^[-_A-Za-z0-9]{40,64}$/.test(token))throw Error('Invalid pairing token');
 const old=await sessions();if(old[token])return {waiting:true};
 const job={token,origin:u.origin,pairTab:sender.tab.id,expires:Date.now()+600000};
 const config=await request(job);
 const destinations={youtube:'https://www.youtube.com/',facebook:'https://www.facebook.com/login/',instagram:'https://www.instagram.com/accounts/login/',x:'https://x.com/i/flow/login',tiktok:'https://www.tiktok.com/login',twitch:'https://www.twitch.tv/login'};
 const scopes={youtube:[['youtube.com'],[]],facebook:[['facebook.com'],['c_user','xs']],instagram:[['instagram.com'],['ds_user_id','sessionid']],x:[['x.com','twitter.com'],['auth_token']],tiktok:[['tiktok.com'],['sessionid']],twitch:[['twitch.tv'],['auth-token']]};
 if(config.url!==destinations[config.platform]||JSON.stringify([config.domains,config.markers])!==JSON.stringify(scopes[config.platform]))throw Error('Unsupported platform scope');
 const tab=await chrome.tabs.create({url:config.url});
 Object.assign(job,{tabId:tab.id,platform:config.platform,domains:config.domains,markers:config.markers});
 await mutate(store=>{store[token]=job;});
 await chrome.alarms.create('trim-playlist-check',{periodInMinutes:0.5});
 return {waiting:true};
}
async function check(job){
 if(busy.has(job.token))return;busy.add(job.token);
 try{
  if(Date.now()>job.expires){await remove(job.token);return;}
  const tab=await chrome.tabs.get(job.tabId);
  if(!tab.url||tab.status!=='complete')return;
  const host=new URL(tab.url).hostname;
  if(!job.domains.some(d=>host===d||host.endsWith('.'+d)))return;
  const stores=await chrome.cookies.getAllCookieStores();const store=stores.find(s=>s.tabIds.includes(job.tabId));
  if(!store)return;
  const all=[];for(const domain of job.domains)all.push(...await chrome.cookies.getAll({domain,storeId:store.id}));
  const cookies=all.filter(c=>!c.partitionKey&&(!c.expirationDate||c.expirationDate>Date.now()/1000));
  const names=new Set(cookies.map(c=>c.name));let verified=false;
  if(job.platform==='youtube'){
   const result=await chrome.scripting.executeScript({target:{tabId:job.tabId},world:'MAIN',func:()=>window.ytcfg?.get('LOGGED_IN')===true});
   verified=result[0]?.result===true&&['SID','__Secure-1PSID','__Secure-3PSID'].some(n=>names.has(n));
  }else verified=job.markers.length>0&&job.markers.every(n=>names.has(n));
  if(!verified)return;
  await request(job,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({verified:true,cookies})});
  await remove(job.token);
  // Only close the two tabs this connection created; never touch existing tabs.
  await chrome.tabs.remove(job.tabId).catch(()=>{});
  await chrome.tabs.remove(job.pairTab).catch(()=>{});
 }catch(error){
  if(/expired|cancelled|No tab with id/i.test(error.message))await remove(job.token);
  else await chrome.tabs.sendMessage(job.pairTab,{type:'connection-error',error:error.message}).catch(()=>{});
 }finally{busy.delete(job.token);}
}
async function remove(token){const count=await mutate(s=>{delete s[token];return Object.keys(s).length;});if(!count)await chrome.alarms.clear('trim-playlist-check');}
async function checkAll(){for(const job of Object.values(await sessions()))await check(job);}
chrome.runtime.onMessage.addListener((message,sender,reply)=>{
 if(message.type!=='connect')return;
 begin(message.token,sender).then(reply,error=>reply({error:error.message}));return true;
});
chrome.tabs.onUpdated.addListener((id,change)=>{if(change.status==='complete')checkAll();});
chrome.tabs.onRemoved.addListener(async id=>{for(const job of Object.values(await sessions()))if(job.tabId===id||job.pairTab===id){await remove(job.token);await chrome.tabs.remove(job.tabId===id?job.pairTab:job.tabId).catch(()=>{});}});
chrome.cookies.onChanged.addListener(()=>checkAll());
chrome.alarms.onAlarm.addListener(alarm=>{if(alarm.name==='trim-playlist-check')checkAll();});
