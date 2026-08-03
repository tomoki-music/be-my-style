(function () {
  'use strict';

  var NAME_CANDIDATES = ['氏名', 'お名前', '名前', '姓名', 'フルネーム'];
  var KEY_CANDIDATES = ['鍵の数'];
  var SOUL_CANDIDATES = ['魂の数'];
  var MISSION_CANDIDATES = ['使命数'];
  var NOTATION_CANDIDATES = ['数秘表記'];
  var NUMEROLOGY_COLUMN_NAMES = ['鍵の数', '魂の数', '使命数', '数秘表記'];
  var STATUS_LABEL = {
    match: '一致',
    no_match: '未一致',
    duplicate: '重複・要確認',
  };
  var SUPPORTED_EXTENSIONS = ['.csv', '.tsv', '.txt'];

  function initialState() {
    return {
      a: { headers: [], rows: [], loaded: false },
      b: { headers: [], rows: [], loaded: false },
      columns: {
        aName: -1, aKey: -1, aSoul: -1, aMission: -1, aNotation: -1,
        bName: -1,
      },
      hasConflict: false,
      duplicateColumnChoice: null,
      results: null,
      resultHeaders: null,
      overwriteIdxs: null,
      filter: 'all',
      search: '',
    };
  }

  var state = initialState();

  function el(id) { return document.getElementById(id); }

  // ---- generic helpers ----

  function clearChildren(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function setError(id, message) {
    el(id).textContent = message || '';
  }

  function fileExtension(name) {
    var idx = name.lastIndexOf('.');
    return idx === -1 ? '' : name.slice(idx).toLowerCase();
  }

  function readFileAsText(file) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onload = function () { resolve(String(reader.result)); };
      reader.onerror = function () { reject(reader.error); };
      reader.readAsText(file, 'UTF-8');
    });
  }

  // ---- input tabs (paste / file) ----

  document.querySelectorAll('.tab-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var target = btn.getAttribute('data-target');
      var mode = btn.getAttribute('data-input-mode');
      document.querySelectorAll('.tab-btn[data-target="' + target + '"]').forEach(function (b) {
        b.classList.toggle('active', b === btn);
      });
      document.querySelectorAll('.input-pane[data-target="' + target + '"]').forEach(function (pane) {
        pane.classList.toggle('hidden', pane.getAttribute('data-mode-pane') !== mode);
      });
    });
  });

  // ---- loading A / B ----

  function currentInputMode(target) {
    var active = document.querySelector('.tab-btn[data-target="' + target + '"].active');
    return active ? active.getAttribute('data-input-mode') : 'paste';
  }

  function loadInput(target) {
    var errorId = 'error-' + target;
    setError(errorId, '');

    var mode = currentInputMode(target);

    if (mode === 'file') {
      var fileInput = el('file-' + target);
      var file = fileInput.files && fileInput.files[0];
      if (!file) {
        setError(errorId, 'ファイルが選択されていません。');
        return;
      }
      var ext = fileExtension(file.name);
      if (SUPPORTED_EXTENSIONS.indexOf(ext) === -1) {
        setError(errorId, '対応していないファイル形式です（.csv / .tsv / .txt のみ対応しています）。');
        return;
      }
      var loadBtn = el('load-' + target + '-btn');
      var originalLabel = loadBtn.textContent;
      loadBtn.disabled = true;
      loadBtn.textContent = '読み込み中...';
      readFileAsText(file).then(function (text) {
        applyParsedInput(target, text, ext === '.tsv' ? '\t' : null);
      }).catch(function () {
        setError(errorId, '文字コードの読み込みに失敗しました。UTF-8で保存し直してから再度お試しください。');
      }).then(function () {
        loadBtn.disabled = false;
        loadBtn.textContent = originalLabel;
      });
      return;
    }

    var textarea = el('paste-' + target);
    var text = textarea.value;
    applyParsedInput(target, text, null);
  }

  function applyParsedInput(target, text, forcedDelimiter) {
    var errorId = 'error-' + target;

    if (!text || text.trim() === '') {
      setError(errorId, target === 'a' ? '元データAが未入力です。' : '反映先データBが未入力です。');
      return;
    }

    var delimiter = forcedDelimiter || CSVUtil.detectDelimiter(text);
    var parsed;
    try {
      parsed = CSVUtil.parseDelimited(text, delimiter);
    } catch (e) {
      setError(errorId, 'CSVの解析に失敗しました。データの形式をご確認ください。');
      return;
    }

    if (!parsed.headers || parsed.headers.length === 0) {
      setError(errorId, 'ヘッダー行が見つかりませんでした。1行目に列名が入っているかご確認ください。');
      return;
    }

    if (parsed.headers.length === 1 && parsed.headers[0].trim() === '' && parsed.rows.length === 0) {
      setError(errorId, '空のファイルです。');
      return;
    }

    state[target] = { headers: parsed.headers, rows: parsed.rows, loaded: true };
    renderPreview(target);
    setError(errorId, '');

    if (state.a.loaded && state.b.loaded) {
      showColumnStep();
    }
  }

  function renderPreview(target) {
    var data = state[target];
    var previewEl = el('preview-' + target);
    clearChildren(previewEl);

    var summary = document.createElement('div');
    summary.textContent = data.rows.length + ' 行を読み込みました。';
    previewEl.appendChild(summary);

    var headerLine = document.createElement('div');
    headerLine.className = 'preview-headers';
    headerLine.textContent = '列: ' + data.headers.join(' / ');
    previewEl.appendChild(headerLine);
  }

  el('load-a-btn').addEventListener('click', function () { loadInput('a'); });
  el('load-b-btn').addEventListener('click', function () { loadInput('b'); });

  // ---- column selection ----

  function populateSelect(selectEl, headers, guessedIndex) {
    clearChildren(selectEl);
    var placeholder = document.createElement('option');
    placeholder.value = '-1';
    placeholder.textContent = '-- 選択してください --';
    selectEl.appendChild(placeholder);

    headers.forEach(function (header, idx) {
      var opt = document.createElement('option');
      opt.value = String(idx);
      opt.textContent = header && header.trim() !== '' ? header : '(列名なし・' + (idx + 1) + '列目)';
      selectEl.appendChild(opt);
    });

    selectEl.value = String(guessedIndex);
  }

  function showColumnStep() {
    var aHeaders = state.a.headers;
    var bHeaders = state.b.headers;

    var guessAName = NumerologyMatcher.guessColumnIndex(aHeaders, NAME_CANDIDATES);
    var guessAKey = NumerologyMatcher.guessColumnIndex(aHeaders, KEY_CANDIDATES);
    var guessASoul = NumerologyMatcher.guessColumnIndex(aHeaders, SOUL_CANDIDATES);
    var guessAMission = NumerologyMatcher.guessColumnIndex(aHeaders, MISSION_CANDIDATES);
    var guessANotation = NumerologyMatcher.guessColumnIndex(aHeaders, NOTATION_CANDIDATES);
    var guessBName = NumerologyMatcher.guessColumnIndex(bHeaders, NAME_CANDIDATES);

    populateSelect(el('col-a-name'), aHeaders, guessAName);
    populateSelect(el('col-a-key'), aHeaders, guessAKey);
    populateSelect(el('col-a-soul'), aHeaders, guessASoul);
    populateSelect(el('col-a-mission'), aHeaders, guessAMission);
    populateSelect(el('col-a-notation'), aHeaders, guessANotation);
    populateSelect(el('col-b-name'), bHeaders, guessBName);

    updateColumnsFromSelects();
    updateConflictPanel();

    el('step-columns').classList.remove('hidden');
    el('step-run').classList.remove('hidden');
  }

  function updateColumnsFromSelects() {
    state.columns.aName = parseInt(el('col-a-name').value, 10);
    state.columns.aKey = parseInt(el('col-a-key').value, 10);
    state.columns.aSoul = parseInt(el('col-a-soul').value, 10);
    state.columns.aMission = parseInt(el('col-a-mission').value, 10);
    state.columns.aNotation = parseInt(el('col-a-notation').value, 10);
    state.columns.bName = parseInt(el('col-b-name').value, 10);
  }

  ['col-a-name', 'col-a-key', 'col-a-soul', 'col-a-mission', 'col-a-notation', 'col-b-name'].forEach(function (id) {
    el(id).addEventListener('change', updateColumnsFromSelects);
  });

  function updateConflictPanel() {
    var existing = NUMEROLOGY_COLUMN_NAMES.filter(function (name) {
      return state.b.headers.indexOf(name) !== -1;
    });
    state.hasConflict = existing.length > 0;
    el('conflict-panel').classList.toggle('hidden', !state.hasConflict);
    if (!state.hasConflict) {
      state.duplicateColumnChoice = null;
    }
  }

  document.querySelectorAll('input[name="dup-column-choice"]').forEach(function (radio) {
    radio.addEventListener('change', function () {
      state.duplicateColumnChoice = radio.value;
    });
  });

  // ---- run match ----

  function validateBeforeMatch() {
    setError('error-columns', '');

    if (!state.a.loaded) {
      setError('error-columns', '元データAが未入力です。');
      return false;
    }
    if (!state.b.loaded) {
      setError('error-columns', '反映先データBが未入力です。');
      return false;
    }

    var c = state.columns;
    if (c.aName < 0) {
      setError('error-columns', 'データAの氏名列が選択されていません。');
      return false;
    }
    if (c.aKey < 0 || c.aSoul < 0 || c.aMission < 0 || c.aNotation < 0) {
      setError('error-columns', 'データAの数秘列（鍵の数・魂の数・使命数・数秘表記）が不足しています。');
      return false;
    }
    if (c.bName < 0) {
      setError('error-columns', 'データBの氏名列が選択されていません。');
      return false;
    }
    if (state.hasConflict && !state.duplicateColumnChoice) {
      setError('error-columns', 'データBに既存の数秘列があります。上書きするか新しい列名で追加するかを選択してください。');
      return false;
    }
    return true;
  }

  function buildResultHeaders() {
    var headers = state.b.headers.slice();
    var overwriteIdxs = [-1, -1, -1, -1];
    var appendNames = [];

    NUMEROLOGY_COLUMN_NAMES.forEach(function (name, i) {
      var existingIdx = headers.indexOf(name);
      if (existingIdx !== -1 && state.duplicateColumnChoice === 'overwrite') {
        overwriteIdxs[i] = existingIdx;
      } else if (existingIdx !== -1 && state.duplicateColumnChoice === 'rename') {
        var newName = name + '(数秘)';
        while (headers.indexOf(newName) !== -1 || appendNames.indexOf(newName) !== -1) {
          newName += '_2';
        }
        appendNames.push(newName);
      } else {
        appendNames.push(name);
      }
    });

    state.resultHeaders = headers.concat(appendNames, ['照合ステータス']);
    state.overwriteIdxs = overwriteIdxs;
  }

  function buildOutputRow(bRow, matchResult) {
    var row = bRow.slice();
    while (row.length < state.b.headers.length) row.push('');

    var appended = [];
    for (var i = 0; i < 4; i += 1) {
      var value = matchResult.values ? matchResult.values[i] : '';
      if (state.overwriteIdxs[i] !== -1) {
        row[state.overwriteIdxs[i]] = value;
      } else {
        appended.push(value);
      }
    }

    var statusLabel = STATUS_LABEL[matchResult.status];
    if (matchResult.status === 'duplicate') {
      statusLabel += '(候補' + matchResult.candidateCount + '件)';
    }

    return row.concat(appended, [statusLabel]);
  }

  function runMatch() {
    updateColumnsFromSelects();
    if (!validateBeforeMatch()) return;

    var c = state.columns;
    var sourceIndex = NumerologyMatcher.buildSourceIndex(
      state.a.rows,
      c.aName,
      [c.aKey, c.aSoul, c.aMission, c.aNotation]
    );
    var matchResults = NumerologyMatcher.matchTargetRows(state.b.rows, c.bName, sourceIndex);

    buildResultHeaders();

    state.results = state.b.rows.map(function (row, i) {
      var matchResult = matchResults[i];
      return {
        status: matchResult.status,
        candidateCount: matchResult.candidateCount,
        displayName: row[c.bName],
        outputRow: buildOutputRow(row, matchResult),
      };
    });

    state.filter = 'all';
    state.search = '';
    el('search-input').value = '';
    document.querySelectorAll('.filter-btn').forEach(function (b) {
      b.classList.toggle('active', b.getAttribute('data-filter') === 'all');
    });

    renderSummary();
    renderTable();

    el('step-summary').classList.remove('hidden');
    el('step-filter').classList.remove('hidden');
    el('step-table').classList.remove('hidden');
    el('step-export').classList.remove('hidden');
    setError('export-status', '');
    el('export-status').textContent = '';
  }

  el('run-match-btn').addEventListener('click', runMatch);

  // ---- summary ----

  function renderSummary() {
    var total = state.results.length;
    var matchCount = 0;
    var noMatchCount = 0;
    var duplicateCount = 0;

    state.results.forEach(function (r) {
      if (r.status === 'match') matchCount += 1;
      else if (r.status === 'no_match') noMatchCount += 1;
      else duplicateCount += 1;
    });

    var rate = total > 0 ? ((matchCount / total) * 100).toFixed(1) : '0.0';

    var tiles = [
      { label: 'Bの総件数', value: total },
      { label: '一致件数', value: matchCount },
      { label: '未一致件数', value: noMatchCount },
      { label: '重複・要確認件数', value: duplicateCount },
      { label: '一致率', value: rate + '%' },
    ];

    var container = el('summary-tiles');
    clearChildren(container);
    tiles.forEach(function (tile) {
      var div = document.createElement('div');
      div.className = 'summary-tile';
      var value = document.createElement('span');
      value.className = 'tile-value';
      value.textContent = String(tile.value);
      var label = document.createElement('span');
      label.className = 'tile-label';
      label.textContent = tile.label;
      div.appendChild(value);
      div.appendChild(label);
      container.appendChild(div);
    });
  }

  // ---- filter / search ----

  document.querySelectorAll('.filter-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      state.filter = btn.getAttribute('data-filter');
      document.querySelectorAll('.filter-btn').forEach(function (b) {
        b.classList.toggle('active', b === btn);
      });
      renderTable();
    });
  });

  el('search-input').addEventListener('input', function () {
    state.search = el('search-input').value;
    renderTable();
  });

  function filteredResults() {
    if (!state.results) return [];
    return state.results.filter(function (r) {
      if (state.filter !== 'all' && r.status !== state.filter) return false;
      if (state.search && String(r.displayName || '').indexOf(state.search) === -1) return false;
      return true;
    });
  }

  // ---- result table ----

  function renderTable() {
    var headers = state.resultHeaders;
    var theadRow = el('result-thead-row');
    clearChildren(theadRow);

    var thNo = document.createElement('th');
    thNo.textContent = '行番号';
    theadRow.appendChild(thNo);

    headers.forEach(function (h) {
      var th = document.createElement('th');
      th.textContent = h;
      theadRow.appendChild(th);
    });

    var tbody = el('result-tbody');
    clearChildren(tbody);

    var rows = filteredResults();
    var fragment = document.createDocumentFragment();

    rows.forEach(function (r, i) {
      var tr = document.createElement('tr');
      tr.className = 'row-' + r.status;

      var tdNo = document.createElement('td');
      tdNo.textContent = String(i + 1);
      tr.appendChild(tdNo);

      r.outputRow.forEach(function (cell, colIdx) {
        var td = document.createElement('td');
        if (colIdx === r.outputRow.length - 1) {
          var badge = document.createElement('span');
          badge.className = 'status-badge status-' + r.status;
          badge.textContent = STATUS_LABEL[r.status];
          td.appendChild(badge);
          if (r.status === 'duplicate') {
            td.appendChild(document.createTextNode(' (候補' + r.candidateCount + '件)'));
          }
        } else {
          td.textContent = cell;
        }
        tr.appendChild(td);
      });

      fragment.appendChild(tr);
    });

    tbody.appendChild(fragment);
    el('table-count').textContent = rows.length + ' / ' + state.results.length + ' 件を表示中';
  }

  // ---- download / copy ----

  function timestampForFilename() {
    var d = new Date();
    function pad(n) { return n < 10 ? '0' + n : String(n); }
    return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + '_' +
      pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
  }

  function triggerDownload(filename, text, mimeType) {
    var bom = '\uFEFF';
    var blob = new Blob([bom + text], { type: mimeType + ';charset=utf-8;' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  function outputRowsFor(statusFilter) {
    if (!state.results) return [];
    return state.results
      .filter(function (r) { return !statusFilter || r.status === statusFilter; })
      .map(function (r) { return r.outputRow; });
  }

  el('download-csv-btn').addEventListener('click', function () {
    var text = CSVUtil.stringifyDelimited(state.resultHeaders, outputRowsFor(null), ',');
    triggerDownload('numerology_result_' + timestampForFilename() + '.csv', text, 'text/csv');
  });

  el('download-tsv-btn').addEventListener('click', function () {
    var text = CSVUtil.stringifyDelimited(state.resultHeaders, outputRowsFor(null), '\t');
    triggerDownload('numerology_result_' + timestampForFilename() + '.tsv', text, 'text/tab-separated-values');
  });

  el('download-no-match-btn').addEventListener('click', function () {
    var text = CSVUtil.stringifyDelimited(state.resultHeaders, outputRowsFor('no_match'), ',');
    triggerDownload('numerology_result_no_match_' + timestampForFilename() + '.csv', text, 'text/csv');
  });

  el('download-duplicate-btn').addEventListener('click', function () {
    var text = CSVUtil.stringifyDelimited(state.resultHeaders, outputRowsFor('duplicate'), ',');
    triggerDownload('numerology_result_duplicate_' + timestampForFilename() + '.csv', text, 'text/csv');
  });

  function copyTextToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.focus();
      textarea.select();
      try {
        var ok = document.execCommand('copy');
        document.body.removeChild(textarea);
        ok ? resolve() : reject(new Error('copy command failed'));
      } catch (e) {
        document.body.removeChild(textarea);
        reject(e);
      }
    });
  }

  el('copy-btn').addEventListener('click', function () {
    if (!state.results) return;
    var text = CSVUtil.stringifyDelimited(state.resultHeaders, outputRowsFor(null), '\t');
    copyTextToClipboard(text).then(function () {
      el('export-status').textContent = 'クリップボードにコピーしました。スプレッドシートに貼り付けてください。';
    }).catch(function () {
      el('export-status').textContent = 'コピーに失敗しました。ブラウザのクリップボード権限をご確認ください。';
    });
  });

  // ---- reset ----

  el('reset-btn').addEventListener('click', function () {
    var confirmed = window.confirm('入力内容・照合結果をすべて消去します。よろしいですか？');
    if (!confirmed) return;

    state = initialState();

    el('paste-a').value = '';
    el('paste-b').value = '';
    el('file-a').value = '';
    el('file-b').value = '';
    clearChildren(el('preview-a'));
    clearChildren(el('preview-b'));
    setError('error-a', '');
    setError('error-b', '');
    setError('error-columns', '');
    el('export-status').textContent = '';
    el('search-input').value = '';

    document.querySelectorAll('input[name="dup-column-choice"]').forEach(function (r) { r.checked = false; });
    el('conflict-panel').classList.add('hidden');

    ['col-a-name', 'col-a-key', 'col-a-soul', 'col-a-mission', 'col-a-notation', 'col-b-name'].forEach(function (id) {
      clearChildren(el(id));
    });

    document.querySelectorAll('.filter-btn').forEach(function (b) {
      b.classList.toggle('active', b.getAttribute('data-filter') === 'all');
    });

    clearChildren(el('summary-tiles'));
    clearChildren(el('result-thead-row'));
    clearChildren(el('result-tbody'));
    el('table-count').textContent = '';

    ['step-columns', 'step-run', 'step-summary', 'step-filter', 'step-table', 'step-export'].forEach(function (id) {
      el(id).classList.add('hidden');
    });

    document.querySelectorAll('.tab-btn').forEach(function (btn) {
      btn.classList.toggle('active', btn.getAttribute('data-input-mode') === 'paste');
    });
    document.querySelectorAll('.input-pane').forEach(function (pane) {
      pane.classList.toggle('hidden', pane.getAttribute('data-mode-pane') !== 'paste');
    });
  });
})();
