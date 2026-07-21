// @メンション候補のオートコンプリート。
//
// 入力欄(textarea)に見せるのは自然な `@username` のみ。DBへ保存する内部記法
// `[@username](customer:ID)` への変換はフォーム送信直前・プレビュー取得直前に
// このファイルが一元的に行う(サーバー側のChat::MarkdownRenderer/MentionParserの
// 記法は変更していない)。
//
// 位置計算・メンション範囲追跡・内部記法への変換・トリガー検出・候補の自分除外・
// 選択時の挿入内容の組み立ては副作用のない純粋関数として切り出し、Node.jsからも
// 読み込んで検証できるようにしている(このリポジトリにはJSの自動テスト基盤が無いため、
// `module.exports` ガードで簡易的にテスト可能にする)。

(function (root) {
  "use strict";

  // ===== 純粋関数群(DOM非依存、Node.jsからも呼び出し可能) =====

  // ドロップダウンの表示位置を計算する。
  // anchorRect: { top, bottom, left, right } ビューポート基準(getBoundingClientRect相当)
  // dropdownSize: { width, height }
  // viewport: { width, height }
  function computeDropdownPosition(anchorRect, dropdownSize, viewport) {
    var spaceBelow = viewport.height - anchorRect.bottom;
    var spaceAbove = anchorRect.top;
    var openUpward = spaceBelow < dropdownSize.height && spaceAbove > spaceBelow;

    var top = openUpward ? anchorRect.top - dropdownSize.height : anchorRect.bottom;
    if (top < 0) top = 0;
    if (top + dropdownSize.height > viewport.height) {
      top = Math.max(0, viewport.height - dropdownSize.height);
    }

    var left = anchorRect.left;
    if (left + dropdownSize.width > viewport.width) {
      left = viewport.width - dropdownSize.width;
    }
    if (left < 0) left = 0;

    return { top: top, left: left, openUpward: openUpward };
  }

  // oldValueとnewValueの共通prefix/suffix長を求める(単一編集区間の差分検出)。
  function computePrefixSuffix(oldValue, newValue) {
    var maxLen = Math.min(oldValue.length, newValue.length);
    var prefixLen = 0;
    while (prefixLen < maxLen && oldValue[prefixLen] === newValue[prefixLen]) {
      prefixLen++;
    }

    var maxSuffix = maxLen - prefixLen;
    var suffixLen = 0;
    while (
      suffixLen < maxSuffix &&
      oldValue[oldValue.length - 1 - suffixLen] === newValue[newValue.length - 1 - suffixLen]
    ) {
      suffixLen++;
    }

    return { prefixLen: prefixLen, suffixLen: suffixLen };
  }

  // 指定した編集区間[regionStart, regionEnd)がdelta分だけ長さを変えたときに、
  // 既存メンション範囲をどう追従・解除させるかの共通ロジック。
  // - 編集区間より完全に前にあるメンション: そのまま
  // - 編集区間より完全に後にあるメンション: deltaだけ位置をずらす
  // - 編集区間と重なるメンション: 解除(配列から除外)
  function shiftAndFilterMentions(mentions, regionStart, regionEnd, delta) {
    return mentions.reduce(function (acc, m) {
      if (m.end <= regionStart) {
        acc.push(m);
      } else if (m.start >= regionEnd) {
        acc.push({ customerId: m.customerId, username: m.username, start: m.start + delta, end: m.end + delta });
      }
      // それ以外(重なる場合)は解除して配列に含めない
      return acc;
    }, []);
  }

  // 生のinputイベント(タイプ・削除・貼り付け・ツールバー操作等、何が起きたか
  // 判別しない汎用編集)に対して、prefix/suffix差分からメンション範囲を追従・解除する。
  function diffAndAdjustMentions(oldValue, newValue, mentions) {
    if (oldValue === newValue) return mentions.slice();

    var ps = computePrefixSuffix(oldValue, newValue);
    var regionStart = ps.prefixLen;
    var regionEnd = oldValue.length - ps.suffixLen;
    var delta = newValue.length - oldValue.length;

    return shiftAndFilterMentions(mentions, regionStart, regionEnd, delta);
  }

  // 候補選択によるトークン挿入は編集区間が既知なので、diffに頼らず直接計算する
  // (「@to」→「@tomoki」のように新旧テキストが部分的に一致する場合、文字列差分だけでは
  // 編集区間の境界があいまいになり得るため、既知の置換はこちらを使う)。
  function applyKnownReplacement(mentions, regionStart, regionEnd, insertedLength) {
    var delta = insertedLength - (regionEnd - regionStart);
    return shiftAndFilterMentions(mentions, regionStart, regionEnd, delta);
  }

  // 表示用テキスト(自然な `@username`)と確定済みメンション範囲から、
  // DB保存用の内部記法 `[@username](customer:ID)` へ変換する。
  // 範囲外・重なり・改ざん(該当位置の文字列が実際の @username と不一致)は
  // 安全側に倒して変換せず、通常のテキストとしてそのまま残す。
  function buildSubmissionContent(visibleValue, mentions) {
    var sorted = mentions
      .slice()
      .filter(function (m) {
        return (
          m &&
          typeof m.start === "number" &&
          typeof m.end === "number" &&
          m.start >= 0 &&
          m.end <= visibleValue.length &&
          m.start < m.end
        );
      })
      .sort(function (a, b) {
        return a.start - b.start;
      });

    var result = "";
    var cursor = 0;

    sorted.forEach(function (m) {
      if (m.start < cursor) return; // 重なっている場合はこの範囲を無視

      var expected = "@" + m.username;
      var actual = visibleValue.slice(m.start, m.end);
      if (actual !== expected) return; // 改ざん・不一致は変換しない(通常テキストとして残す)

      result += visibleValue.slice(cursor, m.start);
      result += "[@" + m.username + "](customer:" + m.customerId + ")";
      cursor = m.end;
    });

    result += visibleValue.slice(cursor);
    return result;
  }

  // 候補一覧から自分自身を除外する(サーバー側の除外に加えたフロント側の二重防御)。
  // candidate.id/currentCustomerIdは文字列・数値どちらでも渡され得るため、
  // Stringへ揃えてから比較する(型不一致ですり抜けるのを防ぐ)。
  function filterOutSelf(items, currentCustomerId) {
    var list = Array.isArray(items) ? items : [];
    if (currentCustomerId === null || currentCustomerId === undefined || currentCustomerId === "") {
      return list.slice();
    }

    var selfId = String(currentCustomerId);
    return list.filter(function (item) {
      return item && String(item.id) !== selfId;
    });
  }

  // キャレット直前の "@トークン" を検出する。
  // "@"は先頭または空白直後で始まり、"@"からキャレットまでの間に空白や"]"を含まないこと。
  // DOM依存を避けるため、実DOMのtextareaだけでなく
  // { value, selectionStart, selectionEnd } の形を持つ任意のオブジェクトを受け取れる。
  function detectMentionTrigger(textarea) {
    var caret = textarea.selectionStart;
    if (caret !== textarea.selectionEnd) return null;

    var value = textarea.value;
    var textBeforeCaret = value.slice(0, caret);
    var atIndex = textBeforeCaret.lastIndexOf("@");
    if (atIndex === -1) return null;

    var precedingChar = atIndex === 0 ? "" : textBeforeCaret[atIndex - 1];
    if (precedingChar && !/\s/.test(precedingChar)) return null;

    var query = textBeforeCaret.slice(atIndex + 1);
    if (/[\s\]]/.test(query)) return null;
    if (query.length > 50) return null;

    return { start: atIndex, query: query };
  }

  // 検出したトリガーが、既に確定済み(選択済み)のメンション範囲の内側・直後にあるかを判定する。
  // 確定済みメンションの開始位置と一致するトリガーは、そのメンションのテキストの中に
  // キャレットが戻ってきたケース(削除等の編集を伴わない移動)なので、再度候補を開かない。
  function isWithinFinalizedMentionRange(mentions, triggerStart, caret) {
    return (mentions || []).some(function (m) {
      return m.start === triggerStart && caret <= m.end;
    });
  }

  // 候補選択によるtextareaへの挿入内容を組み立てる。
  // - 表示は自然な `@表示名` + 半角スペース1つ(選択直後のinputで同じ@名を再検索しないため、
  //   検索クエリとしては終了した状態にする)
  // - メンション範囲(start/end)は半角スペースを含めない(内部記法変換・改ざん検知と整合させるため)
  // - 挿入によって位置がずれる既存メンションはapplyKnownReplacementで追従・解除する
  function buildSelectionInsertion(oldValue, existingMentions, triggerStart, caret, item) {
    var token = "@" + item.name + " ";
    var newValue = oldValue.slice(0, triggerStart) + token + oldValue.slice(caret);

    var mentions = applyKnownReplacement(existingMentions, triggerStart, caret, token.length);
    var mentionEnd = triggerStart + token.length - 1; // 末尾の半角スペースはメンション範囲に含めない
    mentions.push({
      customerId: item.id,
      username: item.name,
      start: triggerStart,
      end: mentionEnd
    });

    return {
      newValue: newValue,
      mentions: mentions,
      newCaret: triggerStart + token.length
    };
  }

  // ドロップダウンを閉じた状態のUI状態(候補・選択中インデックス・検索クエリ・トリガー位置)。
  // closeDropdown()が復元すべき状態の契約をテスト可能にするために切り出している。
  function closedUiState() {
    return { open: false, items: [], activeIndex: -1, triggerStart: -1, query: "" };
  }

  var pureFunctions = {
    computeDropdownPosition: computeDropdownPosition,
    computePrefixSuffix: computePrefixSuffix,
    shiftAndFilterMentions: shiftAndFilterMentions,
    diffAndAdjustMentions: diffAndAdjustMentions,
    applyKnownReplacement: applyKnownReplacement,
    buildSubmissionContent: buildSubmissionContent,
    filterOutSelf: filterOutSelf,
    detectMentionTrigger: detectMentionTrigger,
    isWithinFinalizedMentionRange: isWithinFinalizedMentionRange,
    buildSelectionInsertion: buildSelectionInsertion,
    closedUiState: closedUiState
  };

  // Node.js(テスト用)からrequireできるようにする。ブラウザではmoduleが無いため無害。
  if (typeof module !== "undefined" && module.exports) {
    module.exports = pureFunctions;
  }

  if (typeof document === "undefined") return; // Node.jsから読み込まれた場合はここで終了

  // ===== ここからブラウザ専用: DOM操作・状態管理 =====

  var mentionStates = new WeakMap(); // textarea -> { mentions, lastValue }

  root.ChatMentions = root.ChatMentions || {};
  root.ChatMentions._pure = pureFunctions; // デバッグ・検証用に公開

  // フォーム送信・プレビュー取得の直前に呼び出し、内部記法へ変換した本文を返す。
  root.ChatMentions.getContentForSubmission = function (textarea) {
    var state = mentionStates.get(textarea);
    if (!state) return textarea.value;
    return buildSubmissionContent(textarea.value, state.mentions);
  };

  // Turbolinksはキャッシュ済みページの復元時に古いDOMノードを再利用することがあり、
  // 都度initMentionAutocompleteを呼び直すとイベントリスナー・body直下のドロップダウンDOM・
  // 検索タイマーが前ページ分と二重に残ってしまう。ページを離れる直前(turbolinks:before-cache)に
  // 必ず後始末してから次のページの初期化に入る。
  var activeCleanups = [];

  function cleanupAllInstances() {
    activeCleanups.forEach(function (cleanup) {
      cleanup();
    });
    activeCleanups = [];
  }

  document.addEventListener("turbolinks:before-cache", cleanupAllInstances);

  var SEARCH_DEBOUNCE_MS = 200;

  // turbolinks:load時の一括初期化に加え、スレッドパネルのようにページ遷移を伴わず
  // 動的に挿入されるtextarea向けにも公開する。戻り値のcleanup関数を
  // disposeTextarea()へ渡すと、そのtextarea分だけ個別に後始末できる
  // (cleanupAllInstances()はページ全体の全インスタンスを巻き込むため、
  // スレッドパネルの開閉のたびに呼ぶと本文入力欄のインスタンスまで壊れてしまう)。
  function initMentionAutocomplete(textarea, candidatesUrl, currentCustomerId) {
      var state = { mentions: [], lastValue: textarea.value };
      mentionStates.set(textarea, state);

      var dropdown = document.createElement("div");
      dropdown.className = "mention-autocomplete";
      dropdown.hidden = true;
      dropdown.setAttribute("role", "listbox");
      document.body.appendChild(dropdown);

      var ui = {
        open: false,
        items: [],
        activeIndex: -1,
        triggerStart: -1,
        query: "",
        searchTimer: null,
        requestToken: 0
      };

      function onBlur() {
        // クリック選択(mousedown)を先に処理させるため少し遅延して閉じる
        setTimeout(closeDropdown, 150);
      }

      textarea.addEventListener("input", onInput);
      textarea.addEventListener("keydown", onKeydown);
      textarea.addEventListener("keyup", onCaretMoveKey);
      textarea.addEventListener("click", checkTrigger);
      textarea.addEventListener("scroll", repositionIfOpen);
      textarea.addEventListener("blur", onBlur);

      document.addEventListener("click", onDocumentClick);
      document.addEventListener("turbolinks:before-visit", closeDropdown);

      wireFormSubmit(textarea);

      var cleanup = function () {
        textarea.removeEventListener("input", onInput);
        textarea.removeEventListener("keydown", onKeydown);
        textarea.removeEventListener("keyup", onCaretMoveKey);
        textarea.removeEventListener("click", checkTrigger);
        textarea.removeEventListener("scroll", repositionIfOpen);
        textarea.removeEventListener("blur", onBlur);
        document.removeEventListener("click", onDocumentClick);
        document.removeEventListener("turbolinks:before-visit", closeDropdown);

        clearTimeout(ui.searchTimer);
        window.removeEventListener("scroll", repositionIfOpen, true);
        window.removeEventListener("resize", repositionIfOpen);

        if (dropdown.parentNode) dropdown.parentNode.removeChild(dropdown);
        mentionStates.delete(textarea);
      };
      activeCleanups.push(cleanup);

      function onInput() {
        var newValue = textarea.value;
        if (newValue !== state.lastValue) {
          state.mentions = diffAndAdjustMentions(state.lastValue, newValue, state.mentions);
          state.lastValue = newValue;
        }
        checkTrigger();
      }

      function onCaretMoveKey(event) {
        var navigationKeys = ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"];
        if (navigationKeys.indexOf(event.key) !== -1) checkTrigger();
      }

      function checkTrigger() {
        var trigger = detectMentionTrigger(textarea);
        if (!trigger || isWithinFinalizedMentionRange(state.mentions, trigger.start, textarea.selectionStart)) {
          closeDropdown();
          return;
        }

        ui.triggerStart = trigger.start;
        ui.query = trigger.query;
        clearTimeout(ui.searchTimer);
        ui.searchTimer = setTimeout(function () {
          fetchCandidates(trigger.query);
        }, SEARCH_DEBOUNCE_MS);
      }

      function onKeydown(event) {
        if (!ui.open) return;

        switch (event.key) {
          case "ArrowDown":
            event.preventDefault();
            moveActive(1);
            break;
          case "ArrowUp":
            event.preventDefault();
            moveActive(-1);
            break;
          case "Enter":
          case "Tab":
            if (ui.activeIndex >= 0 && ui.items[ui.activeIndex]) {
              event.preventDefault();
              selectCandidate(ui.items[ui.activeIndex]);
            } else {
              closeDropdown();
            }
            break;
          case "Escape":
            event.preventDefault();
            closeDropdown();
            break;
        }
      }

      function onDocumentClick(event) {
        if (!ui.open) return;
        if (textarea.contains(event.target) || dropdown.contains(event.target)) return;
        closeDropdown();
      }

      function fetchCandidates(query) {
        var token = ++ui.requestToken;
        var url = candidatesUrl + "?q=" + encodeURIComponent(query);

        fetch(url, {
          headers: { "X-Requested-With": "XMLHttpRequest" },
          credentials: "same-origin"
        })
          .then(function (response) {
            return response.ok ? response.json() : [];
          })
          .then(function (data) {
            if (token !== ui.requestToken) return; // 古い(または選択・クローズ済みの)レスポンスは無視
            renderDropdown(filterOutSelf(Array.isArray(data) ? data : [], currentCustomerId));
          })
          .catch(function () {
            closeDropdown();
          });
      }

      function renderDropdown(items) {
        // APIレスポンス受信直後にも除外しているが、描画直前にもう一度除外する(二重防御)。
        items = filterOutSelf(items, currentCustomerId);

        ui.items = items;
        ui.activeIndex = items.length > 0 ? 0 : -1;
        dropdown.innerHTML = "";

        if (items.length === 0) {
          closeDropdown();
          return;
        }

        items.forEach(function (item, index) {
          var row = document.createElement("div");
          row.className = "mention-autocomplete-item" + (index === 0 ? " is-active" : "");
          row.dataset.index = String(index);
          row.setAttribute("role", "option");

          var avatar = document.createElement("img");
          avatar.className = "mention-autocomplete-avatar";
          avatar.src = item.avatar_url;
          avatar.alt = "";

          var names = document.createElement("div");
          names.className = "mention-autocomplete-names";

          var displayName = document.createElement("span");
          displayName.className = "mention-autocomplete-display-name";
          displayName.textContent = item.name;

          var username = document.createElement("span");
          username.className = "mention-autocomplete-username";
          username.textContent = "@" + item.name;

          names.appendChild(displayName);
          names.appendChild(username);

          row.appendChild(avatar);
          row.appendChild(names);
          row.addEventListener("mousedown", function (event) {
            // blurより先にmousedownが発火するのでpreventDefaultでフォーカス喪失を防ぐ
            // (モバイルのタップもmousedownとして届くため、クリック・タップ両方をここでカバーする)
            event.preventDefault();
            selectCandidate(item);
          });

          dropdown.appendChild(row);
        });

        dropdown.hidden = false;
        ui.open = true;
        textarea.setAttribute("aria-expanded", "true");
        positionDropdown();

        window.addEventListener("scroll", repositionIfOpen, true);
        window.addEventListener("resize", repositionIfOpen);
      }

      function moveActive(delta) {
        if (ui.items.length === 0) return;
        var next = ui.activeIndex + delta;
        if (next < 0) next = ui.items.length - 1;
        if (next >= ui.items.length) next = 0;
        ui.activeIndex = next;

        dropdown.querySelectorAll(".mention-autocomplete-item").forEach(function (row, index) {
          row.classList.toggle("is-active", index === next);
        });
        var activeRow = dropdown.querySelector(".mention-autocomplete-item.is-active");
        if (activeRow && activeRow.scrollIntoView) activeRow.scrollIntoView({ block: "nearest" });
      }

      // クリック・タップ・Enter・Tabのいずれの選択経路もここに集約する。
      // 半角スペースを末尾に挿入して現在の@検索クエリを終了させ、タイマー・進行中リクエストを
      // 破棄してから閉じるため、選択直後のinputイベントで同じ@名を再検索して
      // リストが再表示されることはない。
      function selectCandidate(item) {
        clearTimeout(ui.searchTimer);
        ui.requestToken++; // 応答待ちだった古いfetchの結果が後から届いても無視させる

        var result = buildSelectionInsertion(textarea.value, state.mentions, ui.triggerStart, textarea.selectionStart, item);
        state.mentions = result.mentions;
        state.lastValue = result.newValue;
        textarea.value = result.newValue;

        closeDropdown();

        textarea.focus();
        textarea.setSelectionRange(result.newCaret, result.newCaret);
        textarea.dispatchEvent(new Event("input")); // プレビュー等、既存のinputリスナーにも変更を伝える
      }

      function closeDropdown() {
        clearTimeout(ui.searchTimer);
        ui.requestToken++; // 進行中・待機中のfetchがあっても結果を無視させる

        var closed = closedUiState();
        ui.open = closed.open;
        ui.items = closed.items;
        ui.activeIndex = closed.activeIndex;
        ui.triggerStart = closed.triggerStart;
        ui.query = closed.query;

        dropdown.hidden = true;
        dropdown.innerHTML = "";
        textarea.setAttribute("aria-expanded", "false");

        window.removeEventListener("scroll", repositionIfOpen, true);
        window.removeEventListener("resize", repositionIfOpen);
      }

      function repositionIfOpen() {
        if (ui.open) positionDropdown();
      }

      function positionDropdown() {
        var anchorRect = getCaretViewportRect(textarea, ui.triggerStart);
        // 表示前にサイズを測るため、いったん可視状態で計測する
        dropdown.style.visibility = "hidden";
        dropdown.hidden = false;
        var size = { width: dropdown.offsetWidth, height: dropdown.offsetHeight };
        var viewport = { width: window.innerWidth, height: window.innerHeight };
        var pos = computeDropdownPosition(anchorRect, size, viewport);

        dropdown.style.top = pos.top + "px";
        dropdown.style.left = pos.left + "px";
        dropdown.style.visibility = "";
      }

      return cleanup;
  }

  function wireFormSubmit(textarea) {
    var form = textarea.closest("form");
    if (!form) return;

    form.addEventListener("submit", function () {
      textarea.value = root.ChatMentions.getContentForSubmission(textarea);
    });
  }

    // textarea内のキャレット位置を、スタイルを複製したミラー要素で概算し、
    // ビューポート基準の矩形(position: fixedの基準に使える形)へ変換する。
    function getCaretViewportRect(textarea, position) {
      var rect = textarea.getBoundingClientRect();
      var local = getCaretLocalPosition(textarea, position);
      var top = rect.top + local.top;
      var left = rect.left + local.left;
      return { top: top, bottom: top, left: left, right: left };
    }

    function getCaretLocalPosition(textarea, position) {
      var mirror = document.createElement("div");
      var style = getComputedStyle(textarea);
      var properties = [
        "boxSizing",
        "width",
        "paddingTop",
        "paddingRight",
        "paddingBottom",
        "paddingLeft",
        "borderTopWidth",
        "borderRightWidth",
        "borderBottomWidth",
        "borderLeftWidth",
        "fontFamily",
        "fontSize",
        "fontWeight",
        "lineHeight",
        "letterSpacing",
        "whiteSpace",
        "wordWrap"
      ];

      mirror.style.position = "absolute";
      mirror.style.visibility = "hidden";
      mirror.style.whiteSpace = "pre-wrap";
      mirror.style.wordWrap = "break-word";
      mirror.style.top = "0";
      mirror.style.left = "-9999px";

      properties.forEach(function (prop) {
        mirror.style[prop] = style[prop];
      });

      var textBefore = textarea.value.slice(0, Math.max(0, position));
      mirror.textContent = textBefore;

      var marker = document.createElement("span");
      marker.textContent = "​";
      mirror.appendChild(marker);

      document.body.appendChild(mirror);
      var top = marker.offsetTop - textarea.scrollTop + parseInt(style.lineHeight || "20", 10);
      var left = marker.offsetLeft - textarea.scrollLeft;
      document.body.removeChild(mirror);

    return { top: top, left: Math.max(0, left) };
  }

  document.addEventListener("turbolinks:load", function () {
    cleanupAllInstances(); // 保険(before-cacheを経ずに再初期化される経路があっても二重化させない)

    if (!document.URL.match(/chat_rooms/)) return;

    document.querySelectorAll(".chat-rooms-show-container").forEach(function (container) {
      var candidatesUrl = container.dataset.mentionCandidatesUrl;
      if (!candidatesUrl) return;

      // ログイン中ユーザーのID。候補一覧からの自分自身の除外に使う
      // (サーバー側でも除外しているが、フロント描画直前にも二重に除外する)。
      var currentCustomerId = container.dataset.currentCustomerId;

      // 各メッセージのインライン編集フォーム(.message-edit-form)内のtextareaは、
      // 編集ボタン押下時にchat_message_edit.js側が初めて初期化する
      // (非表示のまま自動初期化すると、実際に編集を開いた際の明示的な初期化と
      // 二重初期化になり、同一textareaにリスナー・ドロップダウンが二重に生成されてしまう)。
      container.querySelectorAll(".markdown-textarea").forEach(function (textarea) {
        if (textarea.closest(".message-edit-form")) return;
        initMentionAutocomplete(textarea, candidatesUrl, currentCustomerId);
      });
    });
  });

  // スレッドパネルなど、Turbolinksのページ遷移を伴わず動的に挿入されるtextarea用の公開API。
  // 戻り値のcleanup関数をdisposeTextarea()へ渡すことで、そのtextarea単体だけを
  // 後始末できる(cleanupAllInstances()は同一ページの全インスタンスを巻き込んでしまうため)。
  root.ChatMentions.initTextarea = function (textarea, candidatesUrl, currentCustomerId) {
    return initMentionAutocomplete(textarea, candidatesUrl, currentCustomerId);
  };

  root.ChatMentions.disposeTextarea = function (cleanup) {
    if (typeof cleanup !== "function") return;
    var idx = activeCleanups.indexOf(cleanup);
    if (idx !== -1) activeCleanups.splice(idx, 1);
    cleanup();
  };
})(typeof window !== "undefined" ? window : this);
