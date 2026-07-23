// chat_thread_panel_spec.js/chat_message_edit_spec.jsと同じ方針(Jest等未導入のため
// Node標準assertのみ使用)。DOM実行環境が無いため、doesNotThrow確認に加えて
// ソーステキストに対する静的チェックのみを行う。開閉・fetch・ハイライト・
// フォーカストラップ等の実際のDOM操作はブラウザでの実機確認で担保する。
//
// 実行方法:
//   node spec/javascript/chat_message_search_spec.js
//
// 対象: app/assets/javascripts/public/chat_rooms/chat_message_search.js

"use strict";

var assert = require("assert");
var fs = require("fs");
var path = require("path");

var TARGET_PATH = path.join(
  __dirname, "..", "..", "app", "assets", "javascripts", "public", "chat_rooms", "chat_message_search.js"
);
var source = fs.readFileSync(TARGET_PATH, "utf8");

var failures = 0;
var passed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log("PASS: " + name);
  } catch (e) {
    failures++;
    console.log("FAIL: " + name);
    console.log("  " + e.message);
  }
}

test("document未定義のNode.js環境で読み込んでも例外にならないこと", function () {
  assert.doesNotThrow(function () {
    require(TARGET_PATH);
  });
});

test("検索パネルのトリガー(.chat-search-trigger)を扱っていること", function () {
  assert.ok(source.indexOf(".chat-search-trigger") !== -1);
});

test("検索API呼び出し処理(fetch)が存在すること", function () {
  assert.ok(source.indexOf("fetch(") !== -1);
});

test("スレッド返信へのジャンプでwindow.ChatThreadPanel.openを利用すること(新しいジャンプ基盤を作らない)", function () {
  assert.ok(source.indexOf("window.ChatThreadPanel.open") !== -1 || source.indexOf("ChatThreadPanel.open") !== -1);
});

test("検索結果カードのメッセージID・ルートIDをdata属性(getAttribute)経由で安全に取得していること", function () {
  assert.ok(source.indexOf('getAttribute("data-search-message-id")') !== -1);
  assert.ok(source.indexOf('getAttribute("data-search-root-id")') !== -1);
});

test("ユーザーが入力した検索語(input.value)を直接innerHTMLへ挿入していないこと", function () {
  var innerHtmlAssignments = source.match(/\.innerHTML\s*=\s*[^;]+;/g) || [];
  assert.ok(innerHtmlAssignments.length > 0, "innerHTML代入が見つかりません");

  innerHtmlAssignments.forEach(function (assignment) {
    assert.ok(
      assignment.indexOf("query") === -1 && assignment.indexOf("input.value") === -1 && assignment.indexOf("+") === -1,
      "innerHTMLへユーザー入力を直接連結している可能性があります: " + assignment
    );
  });
});

test("検索結果本文(data.html)はサーバー側でレンダリングされたものをそのまま挿入するだけであること", function () {
  assert.ok(source.indexOf("body.innerHTML = data.html;") !== -1);
});

console.log("\n" + passed + " passed, " + failures + " failed");
process.exit(failures > 0 ? 1 : 0);
