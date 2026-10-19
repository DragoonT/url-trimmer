"""Headless integration check of the actual UI with isolated API fixtures."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,os,shutil,threading,tempfile,subprocess,re,sys
def browser_path():
 found=shutil.which('chrome') or shutil.which('google-chrome') or shutil.which('chromium') or shutil.which('msedge')
 if found:return found
 roots=[os.environ.get('PROGRAMFILES'),os.environ.get('PROGRAMFILES(X86)'),os.environ.get('LOCALAPPDATA')]
 names=[r'Google\Chrome\Application\chrome.exe',r'Microsoft\Edge\Application\msedge.exe']
 if sys.platform=='darwin':
  candidates=['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome','/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']
 elif sys.platform=='win32':
  candidates=[os.path.join(root,name) for root in roots if root for name in names]
 else:
  candidates=['/usr/bin/google-chrome','/usr/bin/chromium','/usr/bin/chromium-browser']
 for path in candidates:
  if path and os.path.isfile(path):return path
 raise RuntimeError('Install Chrome or Edge, or put the browser on PATH, before running this check.')
ROOT=Path(__file__).resolve().parent.parent
SETUP="""<script>
const originalFetch=window.fetch.bind(window);window.sentDownloads=[];
window.fetch=async(url,options)=>{
 const payload=options?.body?JSON.parse(options.body):null;
 if(url==='/api/downloads/preview'&&options?.method==='POST')return new Response(JSON.stringify({id:'preview-job'}));
 if(url==='/api/downloads/preview-job')return new Response(JSON.stringify({status:'complete',is_playlist:true,title:'Example',items:[{index:1,title:'First',available:true},{index:2,title:'Deleted',available:false},{index:3,title:'Third',available:true}]}));
 if(url==='/api/downloads'&&options?.method==='POST'){sentDownloads.push(payload);return new Response(JSON.stringify({id:'download-job'}));}
 if(url==='/api/downloads/download-job')return new Response(JSON.stringify({status:'complete',percent:100,message:'Complete',files:['Example.mp3']}));
 return originalFetch(url,options);
};
</script>"""
CHECK="""<script type='module'>
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const assert=(value,message)=>{if(!value)throw Error(message);};
(async()=>{try{
 await sleep(1000);const form=document.querySelector('.download-form');
 const panels=document.querySelectorAll('.library .collapsible');assert(panels.length===2,'Both library panels collapsible');
 const title=document.querySelector('#trackTitle');title.value='Example retained input';
 const trackList=document.querySelector('#trackList');
 for(const panel of panels){panel.querySelector('.panel-toggle').click();assert(panel.classList.contains('collapsed'),'Heading closes panel');assert(getComputedStyle(panel.querySelector('.panel-content')).display==='none','Closed contents hidden');assert(document.querySelector('#trackTitle')===title&&title.value==='Example retained input','Input retained');assert(document.querySelector('#trackList')===trackList,'Track list retained');panel.querySelector('.panel-toggle').click();assert(!panel.classList.contains('collapsed'),'Heading reopens panel');}

 document.querySelector('.add-track-panel .panel-toggle').click();
 trackList.innerHTML=Array.from({length:30},(_,i)=>'<div class="track-item"><span>⋮</span><span>'+i+'</span><button class="track-main"><span class="track-name">ExampleLongUnbrokenTitle'.repeat(1)+' '+('LongTitle'.repeat(15))+'</span></button><button>x</button></div>').join('');
 const listBox=trackList.getBoundingClientRect(),panelBox=document.querySelector('.tracks-panel').getBoundingClientRect();
 assert(trackList.scrollHeight>trackList.clientHeight,'Track list has vertical scroll range');trackList.scrollTop=200;assert(trackList.scrollTop>0,'Track list scrolls');
 assert(listBox.bottom<=panelBox.bottom,'List stays inside panel');assert(trackList.scrollWidth<=trackList.clientWidth+1,'Long titles do not overflow horizontally');
 const change=(name,value)=>{form.elements[name].value=value;form.elements[name].dispatchEvent(new Event('change',{bubbles:true}));};
 assert(document.querySelector('#authPlatform').hidden,'Platform controls must start hidden');
 change('auth_source','platform');change('platform','facebook');await sleep(200);
 assert(document.querySelector('#authCookie').hidden,'Cookie controls hidden in platform mode');
 assert(document.querySelector('#accountList').textContent.includes('Facebook'),'Selected platform visible');
 assert(!document.querySelector('#accountList').textContent.includes('YouTube'),'Unselected platform hidden');
 change('auth_source','cookie');assert(document.querySelector('#authPlatform').hidden,'Platform hidden in cookie mode');
 const authDropdown=form.querySelector('input[name="auth_source"]').nextElementSibling, cookieDropdown=form.querySelector('input[name="cookies"]').nextElementSibling;
 authDropdown.querySelector('.dropdown-trigger').click();assert(authDropdown.querySelector('.dropdown-menu').classList.contains('open'),'Authentication dropdown opens');
 cookieDropdown.querySelector('.dropdown-trigger').click();assert(!authDropdown.querySelector('.dropdown-menu').classList.contains('open'),'Opening cookies closes authentication dropdown');assert(cookieDropdown.querySelector('.dropdown-menu').classList.contains('open'),'Cookie dropdown opens');
 document.body.click();
 form.elements.url.value='https://example.com/playlist';
 document.querySelector('[data-view="url"]').click();form.requestSubmit();
 await sleep(1000);assert(!document.querySelector('#playlistPicker').hidden,'Playlist picker visible');
 assert(sentDownloads.length===0,'Preview must not start downloads');
 const rows=document.querySelectorAll('.playlist-choice');assert(rows.length===3,'All playlist rows shown');assert(rows[1].disabled,'Unavailable item disabled');
 assert(form.querySelector('[type=submit]').disabled,'No item preselected');
 rows[2].click();form.requestSubmit();await sleep(1000);
 assert(sentDownloads.length===1,'One download request');
 assert(JSON.stringify(sentDownloads[0].selected_items)==='[3]','Only selected item submitted');
 assert(sentDownloads[0].playlist===false,'Selection must not request full playlist');
 change('source_kind','playlist');form.requestSubmit();await sleep(1000);
 assert(sentDownloads.length===2&&sentDownloads[1].playlist===true,'Entire playlist explicitly requested');
 const sourceTrigger=document.querySelector('#trackSourceSelect .dropdown-trigger');sourceTrigger.click();document.querySelector('#trackSourceSelect [data-value="online"]').click();
 assert(document.querySelector('#offlineTrackFields').hidden,'Offline fields hidden for online source');assert(!document.querySelector('#onlineTrackFields').hidden,'Online fields shown');
 document.querySelector('#onlineTrackUrl').value='https://example.com/playlist';document.querySelector('#loadOnlineUrl').click();await sleep(1200);
 assert(!document.querySelector('#onlinePreview').hidden,'Online URL loads a selectable preview');assert(document.querySelector('#onlineLoadProgress').querySelector('div').style.width==='100%','Online URL load shows completion percentage');assert(document.querySelectorAll('#onlineTrackChoices .playlist-choice').length===3,'Online picker lists every playlist entry');
 const onlineTrigger=document.querySelector('#onlineSelectionSelect .dropdown-trigger');onlineTrigger.click();document.querySelector('#onlineSelectionSelect [data-value="all"]').click();
 assert(document.querySelector('#onlineSelectionCount').textContent.startsWith('2 selected'),'Entire online playlist selects available tracks');
 assert(document.querySelector('#networkStatus').textContent.trim().startsWith('Wi-Fi'),'Track panel reports the current network status');
 document.body.insertAdjacentHTML('beforeend','<pre id="testResult">PASS: preview, selection, authentication, online tracks, status</pre>');
 }catch(error){document.body.insertAdjacentHTML('beforeend','<pre id="testResult">FAIL: '+error.message+'</pre>');}})();
</script>"""
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT/'player'),**kw)
 def log_message(self,*a):pass
 def send(self,data,kind='application/json'):
  content=json.dumps(data).encode() if kind=='application/json' else data
  self.send_response(200);self.send_header('Content-Type',kind);self.end_headers();self.wfile.write(content)
 def do_PUT(self):self.rfile.read(int(self.headers.get('Content-Length',0)));self.send({})
 def do_GET(self):
  if self.path=='/':return self.send((ROOT/'player/index.html').read_text(encoding='utf-8').replace('</head>',SETUP+'</head>').replace('</body>',CHECK+'</body>').encode(),'text/html')
  if self.path.startswith('/api/accounts'):return self.send([{'platform':'youtube','name':'YouTube','connected':False,'updatedAt':0},{'platform':'facebook','name':'Facebook','connected':False,'updatedAt':0}])
  if self.path.startswith('/api/cookies'):return self.send(['example_cookie.txt'])
  if self.path.startswith('/api/playlists'):return self.send([])
  if self.path.startswith('/api/session'):return self.send({})
  super().do_GET()
server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with tempfile.TemporaryDirectory(prefix='trim-ui-test-') as profile:
  result=subprocess.run([browser_path(),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--window-size='+(sys.argv[1] if len(sys.argv)>1 else '1280,720'),'--virtual-time-budget=7000','--user-data-dir='+profile,'--dump-dom',f'http://127.0.0.1:{server.server_port}/'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
  match=re.search(r'<pre id="testResult">(.*?)</pre>',result.stdout)
  if not match:raise RuntimeError('UI test did not finish')
  print(match.group(1));assert match.group(1).startswith('PASS'),match.group(1)
finally:server.shutdown();server.server_close()
