/**
 * 氏名の正規化・照合ロジック。
 * あいまい一致（かな⇔漢字変換、旧字体/異体字の推測）は行わない。
 */
(function (global) {
  'use strict';

  // 半角/全角スペース・タブ・改行を除去し、前後の空白も除去する。
  // Unicode正規化(NFKC)のみ行い、文字種変換（かな⇔漢字等）は一切行わない。
  function normalizeName(raw) {
    if (raw == null) return '';
    let s = String(raw);
    if (typeof s.normalize === 'function') {
      s = s.normalize('NFKC');
    }
    s = s.replace(/[\s　]+/g, '');
    return s;
  }

  const STATUS = {
    MATCH: 'match',
    NO_MATCH: 'no_match',
    DUPLICATE: 'duplicate',
  };

  // 元データA（数秘診断済みデータ）から 正規化氏名 -> {count, values} のインデックスを作る。
  // 同一正規化氏名が複数件ある場合は count を増やし、誤爆を避けるため values は使わない（重複扱い）。
  function buildSourceIndex(rows, nameIdx, valueIdxs) {
    const index = new Map();
    for (let i = 0; i < rows.length; i += 1) {
      const row = rows[i];
      const rawName = row[nameIdx];
      const normalized = normalizeName(rawName);
      if (!normalized) continue;

      const values = valueIdxs.map(function (idx) {
        if (idx === -1 || idx == null) return '';
        return row[idx] != null ? row[idx] : '';
      });

      if (index.has(normalized)) {
        index.get(normalized).count += 1;
      } else {
        index.set(normalized, { count: 1, values: values });
      }
    }
    return index;
  }

  // 反映先データB(全行)を、元データAのインデックスと照合する。
  function matchTargetRows(rowsB, nameIdxB, sourceIndex) {
    return rowsB.map(function (row) {
      const rawName = row[nameIdxB];
      const normalized = normalizeName(rawName);

      if (!normalized || !sourceIndex.has(normalized)) {
        return { status: STATUS.NO_MATCH, values: null, candidateCount: 0 };
      }

      const entry = sourceIndex.get(normalized);
      if (entry.count > 1) {
        return { status: STATUS.DUPLICATE, values: null, candidateCount: entry.count };
      }

      return { status: STATUS.MATCH, values: entry.values, candidateCount: 1 };
    });
  }

  // ヘッダー配列から候補名リストに完全一致する列のインデックスを推測する。見つからなければ -1。
  function guessColumnIndex(headers, candidates) {
    const trimmed = headers.map(function (h) { return (h == null ? '' : String(h)).trim(); });
    for (let c = 0; c < candidates.length; c += 1) {
      const idx = trimmed.indexOf(candidates[c]);
      if (idx !== -1) return idx;
    }
    return -1;
  }

  const api = {
    STATUS: STATUS,
    normalizeName: normalizeName,
    buildSourceIndex: buildSourceIndex,
    matchTargetRows: matchTargetRows,
    guessColumnIndex: guessColumnIndex,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    global.NumerologyMatcher = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
