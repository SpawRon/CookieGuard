using System;
using System.Runtime.InteropServices;
namespace Cg { public class CertProp {
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct BLOB { public int cbData; public System.IntPtr pbData; }
[System.Runtime.InteropServices.DllImport("crypt32.dll", SetLastError = true)]
public static extern bool CertSetCertificateContextProperty(System.IntPtr ctx, int propId, int flags, ref BLOB data);
[System.Runtime.InteropServices.DllImport("crypt32.dll", SetLastError = true, EntryPoint = "CertSetCertificateContextProperty")]
public static extern bool CertClearProperty(System.IntPtr ctx, int propId, int flags, System.IntPtr data);
[System.Runtime.InteropServices.DllImport("crypt32.dll", SetLastError = true)]
public static extern bool CertGetCertificateContextProperty(System.IntPtr ctx, int propId, byte[] data, ref int cb);
public static byte[] Get(System.IntPtr ctx, int propId) {
    int cb = 0;
    if (!CertGetCertificateContextProperty(ctx, propId, null, ref cb) || cb == 0) return null;
    byte[] b = new byte[cb];
    if (!CertGetCertificateContextProperty(ctx, propId, b, ref cb)) return null;
    return b;
}
public static bool Set(System.IntPtr ctx, int propId, byte[] value) {
    if (value == null) return CertClearProperty(ctx, propId, 0, System.IntPtr.Zero);
    System.IntPtr p = System.Runtime.InteropServices.Marshal.AllocHGlobal(value.Length);
    try {
        System.Runtime.InteropServices.Marshal.Copy(value, 0, p, value.Length);
        BLOB bl = new BLOB(); bl.cbData = value.Length; bl.pbData = p;
        return CertSetCertificateContextProperty(ctx, propId, 0, ref bl);
    } finally { System.Runtime.InteropServices.Marshal.FreeHGlobal(p); }
}
} }
