"""Capture the real app UI using isolated example data, never project sessions."""
import io,json,subprocess,tempfile,threading,wave
from pathlib import Path
from urllib.parse import urlparse
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
tracks=[{'id':'demo1','title':'Evening piano','ext':'.mp3','kind':'audio','missing':False},{'id':'demo2','title':'Acoustic session','ext':'.mp4','kind':'video','videoHeight':1080,'missing':False},{'id':'demo3','title':'Morning melody','ext':'.wav','kind':'audio','missing':False}]
playlist={'id':'demo','name':'My music · Example','trackCount':3,'items':tracks}
media=io.BytesIO()
with wave.open(media,'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(8000);w.writeframes(b'\0\0'*8000*180)
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'player'),**kwargs)
    def log_message(self,*args):pass
    def send(self,data,kind='application/json'):
        content=json.dumps(data).encode() if kind=='application/json' else data
        self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(content)));self.end_headers();self.wfile.write(content)
    def do_PUT(self):
        self.rfile.read(int(self.headers.get('Content-Length',0)));self.send({})
    def do_GET(self):
        path=urlparse(self.path).path
        if path=='/api/playlists':return self.send([playlist])
        if path=='/api/playlists/demo':return self.send(playlist)
        if path=='/api/session':return self.send({'playlistId':'demo','trackId':'demo1','currentTime':0,'wasPlaying':False,'repeat':'all','volume':75,'savedAt':1,'trimUrlForm':{'source_kind':'video','mode':'full','format':'mp4','quality':'1080','url':'https://www.youtube.com/watch?v=EXAMPLE0001','volume':'1'}})
        if path=='/api/cookies':return self.send([])
        if path=='/api/accounts':return self.send([])
        if path=='/api/media':return self.send(media.getvalue(),'audio/wav')
        if path=='/':
            html=(ROOT/'player/index.html').read_text(encoding='utf-8')
            if 'url' in self.path:html=html.replace('</head>', '<style>.download-form{zoom:.84}</style></head>')
            extra="""<script type='module'>setTimeout(()=>{if(location.search.includes('url'))document.querySelector('[data-view="url"]').click();document.querySelector('#toastHost').replaceChildren();},1000);</script>"""
            return self.send(html.replace('</body>',extra+'</body>').encode(),'text/html; charset=utf-8')
        super().do_GET()
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    for view in ('playlist','url'):
        destination=ROOT/'store-assets'/f'trim-{view}-1280x800.png'
        with tempfile.TemporaryDirectory(prefix='trim-store-') as profile:
            result=subprocess.run(['C:/Program Files/Google/Chrome/Application/chrome.exe','--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--window-size=1280,800','--force-device-scale-factor=1','--virtual-time-budget=4000','--user-data-dir='+profile,'--screenshot='+str(destination),f'http://127.0.0.1:{server.server_port}/?{view}'],capture_output=True,timeout=60)
            if not destination.exists():raise RuntimeError('Screenshot failed')
        with Image.open(destination) as im:
            assert im.size==(1280,800)
            im.convert('RGB').save(destination)
        print(destination)
finally:server.shutdown();server.server_close()
