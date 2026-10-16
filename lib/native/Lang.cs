using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Cg {
    public static class Lang {
        class Tpl { public Regex Rx; public string En; public int Weight; public int Order; }

        static readonly object Gate = new object();
        static readonly Dictionary<string, string> Exact = new Dictionary<string, string>(StringComparer.Ordinal);
        static readonly Dictionary<string, List<Tpl>> ByPrefix = new Dictionary<string, List<Tpl>>(StringComparer.Ordinal);
        static readonly List<Tpl> AnyPrefix = new List<Tpl>();
        static readonly Dictionary<string, string> Memo = new Dictionary<string, string>(StringComparer.Ordinal);
        static readonly Regex Ph = new Regex(@"\{(\d+)(?:[,:][^}]*)?\}");
        static readonly Regex Sentences = new Regex(@"(?<=[.!?\u2026])\s+");
        static int Count;
        public static bool Loaded;

        static bool HasCyr(string s) {
            foreach (char c in s) if (c >= '\u0400' && c <= '\u04FF') return true;
            return false;
        }

        static string Unescape(string s) {
            if (s.IndexOf('\\') < 0) return s;
            StringBuilder b = new StringBuilder(s.Length);
            for (int i = 0; i < s.Length; i++) {
                char c = s[i];
                if (c == '\\' && i + 1 < s.Length) {
                    char n = s[i + 1];
                    if (n == 'n') { b.Append('\n'); i++; continue; }
                    if (n == 't') { b.Append('\t'); i++; continue; }
                    if (n == '\\') { b.Append('\\'); i++; continue; }
                }
                b.Append(c);
            }
            return b.ToString();
        }

        public static int LoadText(string text) {
            int n = 0;
            foreach (string raw in text.Split('\n')) {
                string line = raw.TrimEnd('\r');
                if (line.Length == 0 || line[0] == '#') continue;
                int tab = line.IndexOf('\t');
                if (tab <= 0) continue;
                string en = line.Substring(tab + 1).Trim('\t');
                if (en.Length == 0) continue;
                Add(Unescape(line.Substring(0, tab)), Unescape(en));
                n++;
            }
            Loaded = true;
            return n;
        }

        public static void Add(string ru, string en) {
            lock (Gate) {
                Exact[ru] = en;
                Memo.Clear();
                MatchCollection ms = Ph.Matches(ru);
                if (ms.Count == 0) return;
                // Подставленное значение не перешагивает ни строку, ни
                // конец предложения: иначе «{0} из {1}» проглатывает
                // полэкрана текста, и переводится он уже кусками.
                string any = ru.IndexOf('\n') >= 0 ? ".*?" : @"(?:(?![.!?…]\s)[^\n])*?";
                StringBuilder rx = new StringBuilder("^");
                HashSet<string> seen = new HashSet<string>();
                int pos = 0, lit = 0;
                foreach (Match m in ms) {
                    string piece = ru.Substring(pos, m.Index - pos);
                    lit += piece.Trim().Length;
                    // «Подпись: {0}» в конце строки годится и для пустого
                    // значения, у которого хвостовой пробел уже срезан.
                    bool last = m.Index + m.Length == ru.Length;
                    if (last && piece.EndsWith(" ")) rx.Append(Regex.Escape(piece.Substring(0, piece.Length - 1))).Append(" ?");
                    else rx.Append(Regex.Escape(piece));
                    string g = "p" + m.Groups[1].Value;
                    if (seen.Add(g)) rx.Append("(?<" + g + ">" + any + ")"); else rx.Append("\\k<" + g + ">");
                    pos = m.Index + m.Length;
                }
                string tail = ru.Substring(pos);
                lit += tail.Trim().Length;
                rx.Append(Regex.Escape(tail)).Append("$");
                if (lit < 3) return;
                Tpl t = new Tpl();
                t.Rx = new Regex(rx.ToString(), RegexOptions.Singleline | RegexOptions.CultureInvariant);
                t.En = en; t.Weight = lit; t.Order = Count++;
                string head = ru.Substring(0, ms[0].Index);
                List<Tpl> list;
                if (head.Length >= 2) {
                    string key = head.Substring(0, 2);
                    if (!ByPrefix.TryGetValue(key, out list)) { list = new List<Tpl>(); ByPrefix[key] = list; }
                } else list = AnyPrefix;
                list.Add(t);
                list.Sort(delegate (Tpl a, Tpl b) { int c = b.Weight.CompareTo(a.Weight); return c != 0 ? c : a.Order.CompareTo(b.Order); });
            }
        }

        public static string T(string s) {
            if (string.IsNullOrEmpty(s) || !HasCyr(s)) return s;
            string r;
            lock (Gate) { if (Memo.TryGetValue(s, out r)) return r; }
            r = Translate(s, 0);
            lock (Gate) { if (Memo.Count > 50000) Memo.Clear(); Memo[s] = r; }
            return r;
        }

        static string Translate(string s, int depth) {
            string r = One(s, depth);
            if (r != null) return r;
            if (s.IndexOf('\n') >= 0) {
                string[] lines = s.Split('\n');
                for (int i = 0; i < lines.Length; i++) {
                    string l = lines[i];
                    bool cr = l.EndsWith("\r");
                    if (cr) l = l.Substring(0, l.Length - 1);
                    lines[i] = Line(l, depth) + (cr ? "\r" : "");
                }
                return string.Join("\n", lines);
            }
            return Line(s, depth);
        }

        // Строка целиком: точное совпадение, затем шаблон. Пробелы
        // по краям не мешают: «  ключ » ищется как «ключ».
        static string One(string s, int depth) {
            if (!HasCyr(s)) return s;
            string r;
            if (Exact.TryGetValue(s, out r)) return r;
            int a = 0, b = s.Length;
            while (a < b && char.IsWhiteSpace(s[a])) a++;
            while (b > a && char.IsWhiteSpace(s[b - 1])) b--;
            if (a > 0 || b < s.Length) {
                string core = s.Substring(a, b - a);
                if (Exact.TryGetValue(core, out r)) return s.Substring(0, a) + r + s.Substring(b);
                r = Template(core, depth);
                if (r != null) return s.Substring(0, a) + r + s.Substring(b);
                return null;
            }
            return Template(s, depth);
        }

        static string Template(string s, int depth) {
            List<Tpl> pre = null;
            lock (Gate) { if (s.Length >= 2) ByPrefix.TryGetValue(s.Substring(0, 2), out pre); }
            Tpl best = null; Match bm = null;
            foreach (List<Tpl> list in new List<Tpl>[] { pre, AnyPrefix }) {
                if (list == null) continue;
                foreach (Tpl t in list) {
                    if (best != null && t.Weight <= best.Weight) break;
                    Match m = t.Rx.Match(s);
                    if (m.Success) { best = t; bm = m; break; }
                }
            }
            if (best == null) return null;
            Match mm = bm;
            string res = Ph.Replace(best.En, delegate (Match p) {
                Group g = mm.Groups["p" + p.Groups[1].Value];
                if (!g.Success) return p.Value;
                return depth < 5 ? Translate(g.Value, depth + 1) : g.Value;
            });
            // пустое значение в конце («Подпись:») не оставляет висячий пробел
            if (s.Length > 0 && !char.IsWhiteSpace(s[s.Length - 1])) res = res.TrimEnd();
            return res;
        }

        // Одна строка многострочного текста: маркер списка и отступ
        // отделяются, середина ищется целиком, а не найдена — по
        // предложениям.
        static string Line(string l, int depth) {
            if (!HasCyr(l)) return l;
            Match m = Regex.Match(l, @"^([\s\u2022\u00B7*\-\u2013\u2014>]*)(.*?)(\s*)$", RegexOptions.Singleline);
            string lead = m.Groups[1].Value, core = m.Groups[2].Value, trail = m.Groups[3].Value;
            if (core.Length == 0) return l;
            string r = One(core, depth);
            if (r != null) return lead + r + trail;
            string[] parts = Sentences.Split(core);
            bool any = false;
            for (int i = 0; i < parts.Length; i++) {
                string x = One(parts[i], depth) ?? List(parts[i], depth);
                if (x != null && x != parts[i]) { parts[i] = x; any = true; }
            }
            return any ? lead + string.Join(" ", parts) + trail : l;
        }

        // Перечисление через «; » (причины, заметки) — каждый пункт
        // отдельно. Через «, » — только если известен каждый пункт:
        // иначе полфразы осталось бы по-русски посреди английской.
        static string List(string s, int depth) {
            string[] p = s.Split(new string[] { "; " }, StringSplitOptions.None);
            if (p.Length > 1) {
                bool any = false;
                for (int i = 0; i < p.Length; i++) {
                    string x = One(p[i], depth) ?? Commas(p[i], depth);
                    if (x != null && x != p[i]) { p[i] = x; any = true; }
                }
                return any ? string.Join("; ", p) : null;
            }
            return Commas(s, depth);
        }

        static string Commas(string s, int depth) {
            string[] p = s.Split(new string[] { ", " }, StringSplitOptions.None);
            if (p.Length < 2) return null;
            for (int i = 0; i < p.Length; i++) {
                string x = One(p[i], depth);
                if (x == null) return null;
                p[i] = x;
            }
            return string.Join(", ", p);
        }
    }

    public class LangConverter : System.Windows.Data.IValueConverter {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture) {
            string s = value as string;
            return s == null ? value : Lang.T(s);
        }
        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) {
            return value;
        }
    }
}
