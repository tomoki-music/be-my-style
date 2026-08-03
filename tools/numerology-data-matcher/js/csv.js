/**
 * CSV / TSV の解析・生成ユーティリティ。
 * ブラウザ (<script> グローバル) と Node (CommonJS require) の両方から使えるようにしている。
 */
(function (global) {
  'use strict';

  function stripBom(text) {
    if (text.length > 0 && text.charCodeAt(0) === 0xfeff) {
      return text.slice(1);
    }
    return text;
  }

  // 区切り文字を問わず引用符 (") を解釈できる汎用パーサー。
  // セル内の改行・区切り文字・二重引用符 ("") をそのまま保持する。
  function parseDelimited(text, delimiter) {
    if (text == null || text === '') {
      return { headers: [], rows: [] };
    }

    const s = stripBom(String(text));
    const rows = [];
    let row = [];
    let field = '';
    let inQuotes = false;
    let i = 0;
    const len = s.length;

    while (i < len) {
      const ch = s[i];

      if (inQuotes) {
        if (ch === '"') {
          if (s[i + 1] === '"') {
            field += '"';
            i += 2;
          } else {
            inQuotes = false;
            i += 1;
          }
        } else {
          field += ch;
          i += 1;
        }
        continue;
      }

      if (ch === '"') {
        inQuotes = true;
        i += 1;
      } else if (ch === delimiter) {
        row.push(field);
        field = '';
        i += 1;
      } else if (ch === '\r') {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
        i += s[i + 1] === '\n' ? 2 : 1;
      } else if (ch === '\n') {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
        i += 1;
      } else {
        field += ch;
        i += 1;
      }
    }

    if (field.length > 0 || row.length > 0) {
      row.push(field);
      rows.push(row);
    }

    // 末尾の完全な空行（末尾改行由来）だけを除去する。
    while (
      rows.length > 0 &&
      rows[rows.length - 1].length === 1 &&
      rows[rows.length - 1][0] === ''
    ) {
      rows.pop();
    }

    if (rows.length === 0) {
      return { headers: [], rows: [] };
    }

    const headers = rows[0];
    const dataRows = rows.slice(1);
    return { headers: headers, rows: dataRows };
  }

  // 先頭数行のタブ/カンマ出現数を比較して区切り文字を推測する。
  function detectDelimiter(text) {
    if (!text) return ',';
    const sample = String(text).split(/\r\n|\r|\n/).slice(0, 5).join('\n');
    const tabCount = (sample.match(/\t/g) || []).length;
    const commaCount = (sample.match(/,/g) || []).length;
    return tabCount > commaCount ? '\t' : ',';
  }

  function fieldNeedsQuoting(field, delimiter) {
    return field.indexOf('"') !== -1 ||
      field.indexOf('\n') !== -1 ||
      field.indexOf('\r') !== -1 ||
      field.indexOf(delimiter) !== -1;
  }

  function escapeField(value, delimiter) {
    const str = value == null ? '' : String(value);
    if (fieldNeedsQuoting(str, delimiter)) {
      return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
  }

  function stringifyDelimited(headers, rows, delimiter) {
    const lines = [];
    lines.push(headers.map(function (h) { return escapeField(h, delimiter); }).join(delimiter));
    for (let r = 0; r < rows.length; r += 1) {
      const row = rows[r];
      lines.push(row.map(function (c) { return escapeField(c, delimiter); }).join(delimiter));
    }
    return lines.join('\r\n');
  }

  const api = {
    parseDelimited: parseDelimited,
    detectDelimiter: detectDelimiter,
    stringifyDelimited: stringifyDelimited,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    global.CSVUtil = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
