// みんなのリクエスト欄(#event-request)向けの、初心者向け日本語ラベル付きMarkdown入力補助
// ツールバー。EasyMDE等の外部ライブラリは使わず、chat_markdown_composer.jsと同じ
// 「素のtextareaへ記法を挿入する」方式で完結させる。
//
// chat_markdown_composer.jsと違い、こちらはボタンにアイコンだけでなく日本語ラベルを
// 常時表示し、プレビューは常時分割表示ではなく「プレビュー」ボタン1つで編集⇔プレビューを
// 切り替えるトグル方式にする(要件の「押すとプレビュー、再度押すと編集画面へ戻れる」に対応)。
//
// data-markdown-toolbar-root を持つ要素を対象にquerySelectorAllで探索するため、
// #input_request というID文字列には依存しない(将来チャット以外の欄へ同じ構造で
// 展開しても、IDの重複を気にせず動く)。
(function () {
  'use strict';

  document.addEventListener('turbolinks:load', function () {
    document.querySelectorAll('[data-markdown-toolbar-root]').forEach(function (root) {
      initToolbar(root);
    });
  });

  window.RequestMarkdownToolbar = window.RequestMarkdownToolbar || {};
  window.RequestMarkdownToolbar.init = initToolbar;

  // 同じルート要素に対してinit()が複数回呼ばれても(turbolinks:loadの多重発火等)、
  // ボタンのイベントリスナーが重複登録されないようにする。
  function initToolbar(root) {
    if (!root || root.dataset.markdownToolbarInitialized === 'true') return;

    var textarea = root.querySelector('[data-markdown-toolbar-textarea]');
    var editPane = root.querySelector('.request-markdown-toolbar__pane--edit');
    var previewPane = root.querySelector('.request-markdown-toolbar__pane--preview');
    var previewBody = root.querySelector('.request-markdown-toolbar__preview-body');
    var previewBtn = root.querySelector('[data-md-action="preview"]');
    if (!textarea || !editPane || !previewPane || !previewBody || !previewBtn) return;

    root.dataset.markdownToolbarInitialized = 'true';

    root.querySelectorAll('.request-markdown-toolbar__btn').forEach(function (button) {
      button.addEventListener('click', function (event) {
        // type="button"のため通常はフォーム送信を引き起こさないが、
        // 誤送信防止の保険として明示的にも止めておく。
        event.preventDefault();

        var action = button.dataset.mdAction;
        if (action === 'preview') {
          togglePreview(root, textarea, editPane, previewPane, previewBody, previewBtn);
          return;
        }

        applyMarkdownAction(textarea, action);
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
      });
    });
  }

  function applyMarkdownAction(textarea, action) {
    switch (action) {
      case 'heading':
        applyHeadingLine(textarea);
        break;
      case 'bold':
        wrapSelection(textarea, '**', '**', '太字にする文字');
        break;
      case 'unordered-list':
        applyLinePrefixBlock(textarea, '- ', '項目');
        break;
      case 'ordered-list':
        applyOrderedListBlock(textarea);
        break;
      case 'quote':
        applyLinePrefixBlock(textarea, '> ', '引用する内容');
        break;
      case 'link':
        applyLink(textarea);
        break;
      default:
        break;
    }
  }

  // textareaのvalueへ、posの位置にtextだけを挿入する(他の部分は一切書き換えない)。
  function insertAt(textarea, pos, text) {
    var value = textarea.value;
    textarea.value = value.slice(0, pos) + text + value.slice(pos);
  }

  // chat_mention_autocomplete.js(#input_requestに接続済みの@メンションオートコンプリート)は
  // textareaのinputイベントごとに、直前の値との文字列差分(共通prefix/suffix比較)から
  // 「編集された区間」を検出し、その区間に重なるメンションのトラッキングを解除する
  // (安全側に倒し、以後は通常テキストとして扱う)。
  // insertAt()で1箇所だけへ挿入した直後に必ずこれを呼び、chat_mention_autocomplete.js側の
  // 直前値(state.lastValue)を都度更新させることで、複数回の挿入を「それぞれ独立した
  // 小さな挿入」として順番に認識させる(まとめて1回で差分を取らせると、間にあるメンションを
  // 巻き込んだ1つの大きな変更に見えてしまう)。
  function fireInput(textarea) {
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
  }

  // 太字: 選択中の文字列を**で囲む。未選択時はプレースホルダーを挿入し、
  // そのまま上書き入力できるようプレースホルダー部分を選択状態にする。
  //
  // 選択あり時は、選択文字列自体(@メンション本体を含みうる)を書き換えず、
  // (1)選択範囲の末尾へafterを挿入 → input発火 → (2)選択範囲の先頭へbeforeを挿入 → input発火
  // の順で「純粋な挿入」を2回行う(insertAt/fireInputのコメント参照)。
  // 末尾を先に処理するのは、先頭側の挿入位置(start)が末尾側の挿入によってずれないようにするため。
  function wrapSelection(textarea, before, after, placeholder) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;

    if (start === end) {
      // 新規テキストの挿入であり、既存文字列(メンション等)を書き換えないため
      // まとめて1回で挿入してよい。
      var value = textarea.value;
      textarea.value = value.slice(0, start) + before + placeholder + after + value.slice(end);
      fireInput(textarea);
      textarea.focus();
      textarea.setSelectionRange(start + before.length, start + before.length + placeholder.length);
      return;
    }

    insertAt(textarea, end, after);
    fireInput(textarea);
    insertAt(textarea, start, before);
    fireInput(textarea);

    textarea.focus();
    textarea.setSelectionRange(start + before.length, end + before.length);
  }

  // 見出し: カーソル(または選択範囲の開始位置)がある行の先頭に "## " を挿入する。
  // その行に既に "## " が付いている場合は不自然な二重付与を避けるため何もしない。
  // 未選択かつ行が空の場合のみ、"見出し"のプレースホルダーも合わせて挿入する。
  function applyHeadingLine(textarea) {
    var prefix = '## ';
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var value = textarea.value;
    var lineStart = value.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = value.indexOf('\n', start);
    if (lineEnd === -1) lineEnd = value.length;
    var line = value.slice(lineStart, lineEnd);

    if (line.indexOf(prefix) === 0) {
      textarea.focus();
      textarea.setSelectionRange(start, end);
      return;
    }

    var hasSelection = start !== end;

    if (!hasSelection && line.trim() === '') {
      var placeholder = '見出し';
      textarea.value = value.slice(0, lineStart) + prefix + placeholder + value.slice(lineEnd);
      textarea.focus();
      textarea.setSelectionRange(lineStart + prefix.length, lineStart + prefix.length + placeholder.length);
      return;
    }

    textarea.value = value.slice(0, lineStart) + prefix + value.slice(lineStart);
    textarea.focus();
    textarea.setSelectionRange(start + prefix.length, end + prefix.length);
  }

  // 箇条書き・引用など「選択範囲の各行の先頭に記号を追加する」系のボタン共通処理。
  // 複数行選択時は各行の先頭にprefixを追加し、未選択時はプレースホルダー付きの1行を挿入する。
  function applyLinePrefixBlock(textarea, prefix, placeholder) {
    applyPerLinePrefix(textarea, function () { return prefix; }, placeholder);
  }

  // 番号リスト: 選択範囲の各行に "1. " "2. " ... と連番を振る。未選択時は "1. 項目" を挿入する。
  function applyOrderedListBlock(textarea) {
    applyPerLinePrefix(textarea, function (lineIndex) { return (lineIndex + 1) + '. '; }, '項目');
  }

  // 箇条書き・番号リスト・引用の共通実装。
  // prefixForLine(lineIndex) は0始まりの行インデックスを受け取り、その行に挿入する
  // 文字列("- "、"1. "、"> "など)を返す。
  //
  // 複数行選択時、以前は選択範囲の各行をまとめて組み立て直して1回で置換していたが、
  // これだと選択範囲内(1行目の先頭〜最終行の末尾)の文字列がまるごと書き換わったと
  // chat_mention_autocomplete.jsの位置トラッキングに認識され、範囲内にある@メンションの
  // トラッキングが解除されてしまう(投稿後にメンションがリンク化されない)。
  // そのため、各行の先頭へ記号だけを個別に挿入し(行の本文はそのまま)、
  // 1回の挿入ごとにinput イベントを発火する(insertAt/fireInputのコメント参照)。
  //
  // 行は後ろ(最終行)から逆順に処理する。前の行の開始位置(lineStarts)は挿入前の座標で
  // 固定しておき、後ろの行から挿入していけば、まだ処理していない前の行の開始位置は
  // 後続の挿入で一切ずれない(逆に前から処理すると、後ろの行の開始位置をその都度
  // 挿入済み文字数ぶん補正し直す必要があり複雑になる)。
  function applyPerLinePrefix(textarea, prefixForLine, placeholder) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var value = textarea.value;

    if (start === end) {
      // 新規テキストの挿入であり、既存文字列(メンション等)を書き換えないため
      // まとめて1回で挿入してよい。
      var prefix = prefixForLine(0);
      textarea.value = value.slice(0, start) + prefix + placeholder + value.slice(end);
      fireInput(textarea);
      textarea.focus();
      textarea.setSelectionRange(start + prefix.length, start + prefix.length + placeholder.length);
      return;
    }

    var lineStart = value.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = value.indexOf('\n', end - 1);
    if (lineEnd === -1) lineEnd = value.length;

    var lines = value.slice(lineStart, lineEnd).split('\n');
    var lineStarts = [];
    var cursor = lineStart;
    lines.forEach(function (line) {
      lineStarts.push(cursor);
      cursor += line.length + 1; // 改行分
    });

    var totalInserted = 0;
    for (var i = lines.length - 1; i >= 0; i--) {
      var linePrefix = prefixForLine(i);
      insertAt(textarea, lineStarts[i], linePrefix);
      fireInput(textarea);
      totalInserted += linePrefix.length;
    }

    textarea.focus();
    textarea.setSelectionRange(lineStart, lineStart + (lineEnd - lineStart) + totalInserted);
  }

  // リンク: 選択文字列をリンク名として使い、[名前](https://)を挿入する。
  // 続けてURLを入力しやすいよう、挿入後は"https://"部分を選択状態にする
  // (prompt()はアクセシビリティ・操作性の理由で使わない)。
  //
  // 選択あり時は、選択文字列(リンク名として使う。@メンション本体を含みうる)自体を
  // 書き換えず、wrapSelectionと同じ「末尾へ挿入→先頭へ挿入」の2段階に分ける。
  function applyLink(textarea) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var url = 'https://';

    if (start === end) {
      var value = textarea.value;
      var label = 'リンク名';
      textarea.value = value.slice(0, start) + '[' + label + '](' + url + ')' + value.slice(end);
      fireInput(textarea);
      textarea.focus();
      var placeholderUrlStart = start + 1 + label.length + 2; // '[' + label + '('
      textarea.setSelectionRange(placeholderUrlStart, placeholderUrlStart + url.length);
      return;
    }

    var afterText = '](' + url + ')';
    var beforeText = '[';

    insertAt(textarea, end, afterText);
    fireInput(textarea);
    insertAt(textarea, start, beforeText);
    fireInput(textarea);

    textarea.focus();
    var urlStart = end + beforeText.length + 2; // '[' + 選択文字列 + '(' の後
    textarea.setSelectionRange(urlStart, urlStart + url.length);
  }

  // プレビュー: 押すたびに編集⇔プレビュー表示を切り替えるトグル。
  // 見た目・安全性を保存後の表示と一致させるため、常にRequests::MentionTextRenderer
  // (サーバー側の共通Markdown処理)をAjaxで呼び出す。クライアント側でのMarkdownパースは行わない。
  function togglePreview(root, textarea, editPane, previewPane, previewBody, previewBtn) {
    var showingPreview = previewBtn.getAttribute('aria-pressed') === 'true';

    if (showingPreview) {
      previewPane.hidden = true;
      editPane.hidden = false;
      previewBtn.setAttribute('aria-pressed', 'false');
      previewBtn.textContent = 'プレビュー';
      textarea.focus();
      return;
    }

    editPane.hidden = true;
    previewPane.hidden = false;
    previewBtn.setAttribute('aria-pressed', 'true');
    previewBtn.textContent = '編集に戻る';

    renderPreview(root, textarea, previewBody);
  }

  function renderPreview(root, textarea, previewBody) {
    // @メンションは入力欄では自然な@usernameのまま見せているため、プレビュー取得直前に
    // 内部記法([@username](customer:ID))へ一時変換してからMarkdownプレビューAPIへ送る
    // (chat_markdown_composer.jsの既存パターンと同じ)。
    var content = (window.ChatMentions && window.ChatMentions.getContentForSubmission)
      ? window.ChatMentions.getContentForSubmission(textarea)
      : textarea.value;

    if (!content.trim()) {
      previewBody.innerHTML = '<p class="markdown-preview-placeholder">プレビューする内容がありません</p>';
      return;
    }

    var previewUrl = root.dataset.previewUrl;
    if (!previewUrl) return;

    var csrfMeta = document.querySelector('meta[name="csrf-token"]');

    fetch(previewUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfMeta ? csrfMeta.content : '',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({ content: content })
    })
      .then(function (response) { return response.json(); })
      .then(function (data) {
        if (data.error || typeof data.html !== 'string') {
          previewBody.innerHTML = '<p class="markdown-preview-placeholder">プレビューを取得できませんでした</p>';
          return;
        }
        // サーバー側(Requests::MentionTextRenderer)でSanitize済みのHTMLのみを信頼して挿入する。
        previewBody.innerHTML = data.html;
      })
      .catch(function () {
        previewBody.innerHTML = '<p class="markdown-preview-placeholder">プレビューを取得できませんでした</p>';
      });
  }
})();
