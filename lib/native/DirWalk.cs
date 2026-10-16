using System;
using System.Collections.Generic;
using System.IO;

namespace Cg {
    public class DirStat {
        public long Bytes;
        public int Files;
        public int Dirs;
        public int Exe;
        public int Denied;
        public DateTime LastWrite = DateTime.MinValue;
        public List<string> ExePaths = new List<string>();
    }

    public static class DirWalk {
        public static DirStat Measure(string root, int maxExe, int budgetMs) {
            DirStat s = new DirStat();
            DateTime stop = DateTime.UtcNow.AddMilliseconds(budgetMs);
            Stack<string> st = new Stack<string>();
            st.Push(root);
            while (st.Count > 0) {
                if (DateTime.UtcNow > stop) { s.Denied++; break; }
                string d = st.Pop();
                DirectoryInfo di;
                try { di = new DirectoryInfo(d); } catch { s.Denied++; continue; }
                FileSystemInfo[] items;
                try { items = di.GetFileSystemInfos(); } catch { s.Denied++; continue; }
                foreach (FileSystemInfo it in items) {
                    try {
                        // ссылки (junction, symlink) не обходим: петли и чужие диски
                        if ((it.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        if ((it.Attributes & FileAttributes.Directory) != 0) { s.Dirs++; st.Push(it.FullName); continue; }
                        FileInfo f = (FileInfo)it;
                        s.Files++;
                        s.Bytes += f.Length;
                        if (f.LastWriteTimeUtc > s.LastWrite) s.LastWrite = f.LastWriteTimeUtc;
                        string ext = f.Extension.ToLowerInvariant();
                        if (ext == ".exe" || ext == ".dll" || ext == ".scr" || ext == ".ps1" || ext == ".vbs" || ext == ".js" || ext == ".bat" || ext == ".cmd") {
                            if (ext == ".exe" || ext == ".scr") {
                                s.Exe++;
                                if (s.ExePaths.Count < maxExe) s.ExePaths.Add(f.FullName);
                            }
                        }
                    } catch { s.Denied++; }
                }
            }
            return s;
        }
    }
}
