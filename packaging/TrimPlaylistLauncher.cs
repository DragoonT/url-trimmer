using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string python = Path.Combine(dir, "pythonw.exe");
        string script = Path.Combine(dir, "pc", "app", "trim_playlist_app.py");
        if (!File.Exists(python) || !File.Exists(script))
        {
            MessageBox.Show("Trim Playlist is incomplete. Install it again.", "Trim Playlist");
            return;
        }
        ProcessStartInfo info = new ProcessStartInfo();
        info.FileName = python;
        info.Arguments = "\"" + script + "\"";
        info.WorkingDirectory = dir;
        info.UseShellExecute = false;
        Process.Start(info);
    }
}
