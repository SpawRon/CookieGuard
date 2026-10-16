using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
namespace Cg {
    public class DropArgs : EventArgs {
        public string[] Files { get; private set; }
        public DropArgs(string[] f) { Files = f; }
    }
    public class DropTarget {
        [DllImport("shell32.dll")] static extern void DragAcceptFiles(IntPtr h, bool accept);
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern uint DragQueryFile(IntPtr d, uint i, StringBuilder s, uint cch);
        [DllImport("shell32.dll")] static extern void DragFinish(IntPtr d);
        [DllImport("ole32.dll")] static extern int RevokeDragDrop(IntPtr h);
        [DllImport("user32.dll")] static extern bool ChangeWindowMessageFilterEx(IntPtr h, uint msg, uint action, IntPtr p);
        public event EventHandler<DropArgs> Dropped;
        public DropTarget(Window w) {
            IntPtr h = new WindowInteropHelper(w).Handle;
            HwndSource src = HwndSource.FromHwnd(h);
            src.AddHook(Hook);
            RevokeDragDrop(h);
            DragAcceptFiles(h, true);
            foreach (uint m in new uint[] { 0x0233, 0x0049, 0x004A }) ChangeWindowMessageFilterEx(h, m, 1, IntPtr.Zero);
        }
        IntPtr Hook(IntPtr h, int msg, IntPtr w, IntPtr l, ref bool handled) {
            if (msg != 0x0233) return IntPtr.Zero;
            uint n = DragQueryFile(w, 0xFFFFFFFF, null, 0);
            string[] files = new string[n];
            for (uint i = 0; i < n; i++) {
                StringBuilder sb = new StringBuilder(1024);
                DragQueryFile(w, i, sb, 1024);
                files[i] = sb.ToString();
            }
            DragFinish(w);
            handled = true;
            if (Dropped != null) Dropped(this, new DropArgs(files));
            return IntPtr.Zero;
        }
    }
}
