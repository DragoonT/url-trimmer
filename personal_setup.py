"""Private local setup: bundled connector and validated cookie-file import."""
import http.cookiejar
import os
from pathlib import Path
import secrets
import shutil
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from app_paths import app_dir, resource_dir

FILES = ('manifest.json', 'background.js', 'bridge.js', 'README.md', 'icon128.png')
DOMAINS = ('youtube.com', 'facebook.com', 'instagram.com', 'x.com', 'twitter.com', 'tiktok.com', 'twitch.tv')

def prepare_connector(root, bundle):
    destination = Path(root) / 'browser-extension-personal'
    destination.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        shutil.copy2(Path(bundle) / name, destination / name)
    return destination

def import_cookies(root, source):
    jar = http.cookiejar.MozillaCookieJar(str(source))
    jar.load(ignore_discard=True, ignore_expires=True)
    cookies = [c for c in jar if any(c.domain.lstrip('.').lower() == d or c.domain.lstrip('.').lower().endswith('.' + d) for d in DOMAINS)
               and (c.expires in (None, 0) or not c.is_expired())]
    if not cookies:
        raise ValueError('No unexpired supported-platform cookies found. Export a fresh Netscape cookies.txt file from the signed-in platform.')
    folder = Path(root) / 'cookies'
    folder.mkdir(exist_ok=True)
    destination = folder / ('imported_' + secrets.token_hex(6) + '.txt')
    temporary = destination.with_suffix('.tmp')
    exported = http.cookiejar.MozillaCookieJar(str(temporary))
    for cookie in cookies:
        if cookie.expires == 0:
            cookie.expires = None
            cookie.discard = True
        exported.set_cookie(cookie)
    try:
        exported.save(ignore_discard=True, ignore_expires=True)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination

def main():
    root = app_dir()
    # This private setup belongs to the existing project, not an arbitrary folder.
    if not (root / 'playlist_server.py').is_file():
        messagebox.showerror('Trim Playlist', 'Keep this setup executable inside the url-trimmer project or its dist folder.')
        return
    window = tk.Tk()
    window.title('Trim Playlist — Personal Setup')
    window.geometry('600x370')
    window.configure(bg='#0e131c')
    style = ttk.Style(window)
    style.theme_use('clam')
    style.configure('TButton', background='#3276ff', foreground='white', padding=12)
    tk.Label(window, text='Trim Playlist Personal Setup', bg='#0e131c', fg='#eef2f8', font=('Segoe UI',18,'bold')).pack(pady=(26,12))
    tk.Label(window, text='Use the connector privately while store review is pending.', bg='#0e131c', fg='#a9b5c7', font=('Segoe UI',10)).pack()
    def prepare():
        try:
            folder = prepare_connector(root, resource_dir() / 'browser-extension')
            os.startfile(str(folder))
            messagebox.showinfo('Connector ready', 'In Helium: Extensions → Developer mode → Load unpacked.\nChoose the folder just opened, then reload the app’s connection page.\n\n' + str(folder))
        except Exception as error:
            messagebox.showerror('Setup failed', str(error))
    def choose_cookie():
        source = filedialog.askopenfilename(title='Choose exported Netscape cookies.txt', filetypes=[('Cookie text files','*.txt')])
        if not source:
            return
        try:
            destination = import_cookies(root, source)
            messagebox.showinfo('Cookies imported', 'Open Trim URL and select this file in Cookies:\n\n' + destination.name + '\n\nPrivate playlists must be accessible to the exported account. An invalid playlist URL cannot be fixed by cookies.')
        except Exception:
            messagebox.showerror('Import failed', 'Could not import this cookie file. Export a fresh Netscape cookies.txt file from the platform while signed in. Existing cookie files were not replaced.')
    ttk.Button(window, text='Prepare personal extension', command=prepare).pack(fill='x', padx=40, pady=(24,12))
    ttk.Button(window, text='Import a cookie file', command=choose_cookie).pack(fill='x', padx=40)
    tk.Label(window, text='Everything stays in this project. Existing sessions are not overwritten.', bg='#0e131c', fg='#a9b5c7', wraplength=510, font=('Segoe UI',10)).pack(pady=20)
    window.mainloop()

if __name__ == '__main__':
    main()
