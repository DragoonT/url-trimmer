document.documentElement.dataset.trimPlaylistConnector = '1';
if(location.pathname==='/connect.html'){
 window.addEventListener('message',async event=>{
  if(event.source!==window||event.origin!==location.origin||event.data?.type!=='trim-playlist-connect')return;
  try{
   const result=await chrome.runtime.sendMessage({type:'connect',token:event.data.token});
   window.postMessage({type:'trim-playlist-connection',...result},location.origin);
  }catch(error){window.postMessage({type:'trim-playlist-connection',error:error.message},location.origin);}
 });
}

chrome.runtime.onMessage.addListener(message=>{if(message.type==='connection-error')window.postMessage({type:'trim-playlist-connection',error:message.error},location.origin);});
