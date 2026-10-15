// ============================================================
//  CookieGuard - Launcher.cs
//  Настоящий исполняемый файл программы.
//
//  Зачем он нужен, если логика на PowerShell: ярлык, ведущий
//  прямо на powershell.exe, в Windows 11 мигает чёрным окном
//  (терминал по умолчанию игнорирует флаг скрытия) и выглядит
//  как самодельщина. Этот файл — обычное оконное приложение
//  без консоли: оно просто запускает оболочку скрыто.
//
//  Собирается при установке штатным компилятором C#, который
//  есть в каждой Windows с .NET Framework. Стороннего ничего
//  не требуется.
// ============================================================

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

static class Launcher
{
    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string script = Path.Combine(exeDir, "CookieGuard.ps1");

            if (!File.Exists(script))
            {
                MessageBox.Show(
                    "Не найден файл CookieGuard.ps1 рядом с программой:\n" + script +
                    "\n\nПохоже, установка повреждена. Переустановите CookieGuard.",
                    "CookieGuard", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 2;
            }

            string psExe = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");
            if (!File.Exists(psExe)) psExe = "powershell.exe";

            string extra = "";
            foreach (string a in args) extra += " " + a;

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = psExe;
            psi.Arguments = "-STA -NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"" + extra;
            psi.WorkingDirectory = exeDir;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;                       // консоли не будет вовсе
            psi.WindowStyle = ProcessWindowStyle.Hidden;

            Process.Start(psi);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show("Не удалось запустить CookieGuard:\n\n" + ex.Message,
                "CookieGuard", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
