// chat_message_search_spec.js/chat_thread_panel_spec.jsと同じ方針(Jest等未導入のため
// Node標準assertのみ使用)。DOM実行環境が無いため、doesNotThrow確認に加えて
// ソーステキストに対する静的チェックのみを行う。開閉・fetch・ハイライト・
// フォーカストラップ等の実際のDOM操作はブラウザでの実機確認(system spec)で担保する。
//
// 実行方法:
//   node spec/javascript/chat_message_pin_spec.js
//
// 対象: app/assets/javascripts/public/chat_rooms/chat_message_pin.js

"use strict";

var assert = require("assert");
var fs = require("fs");
var path = require("path");

var TARGET_PATH = path.join(
  __dirname, "..", "..", "app", "assets", "javascripts", "public", "chat_rooms", "chat_message_pin.js"
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

test("ピン留め一覧パネルのトリガー(.chat-pin-trigger)を扱っていること", function () {
  assert.ok(source.indexOf(".chat-pin-trigger") !== -1);
});

test("ピン留め一覧取得・ピン留め/解除にfetchを使っていること", function () {
  assert.ok(source.indexOf("fetch(") !== -1);
});

test("ピン留め/解除(POST/DELETE)にCSRFトークンを付与していること", function () {
  assert.ok(source.indexOf("X-CSRF-Token") !== -1);
  assert.ok(source.indexOf("csrfToken()") !== -1);
});

test("ピン留め解除にDELETEメソッドを使っていること", function () {
  assert.ok(source.indexOf('"DELETE"') !== -1);
});

test("スレッド返信へのジャンプでwindow.ChatThreadPanel.openを利用すること(新しいジャンプ基盤を作らない)", function () {
  assert.ok(source.indexOf("window.ChatThreadPanel.open") !== -1 || source.indexOf("ChatThreadPanel.open") !== -1);
});

test("ピン結果カードのメッセージID・ルートIDをdata属性(getAttribute)経由で安全に取得していること", function () {
  assert.ok(source.indexOf('getAttribute("data-pin-message-id")') !== -1);
  assert.ok(source.indexOf('getAttribute("data-pin-root-id")') !== -1);
});

test("ユーザー由来の値をinnerHTMLへ直接連結していないこと", function () {
  var innerHtmlAssignments = source.match(/\.innerHTML\s*=\s*[^;]+;/g) || [];
  assert.ok(innerHtmlAssignments.length > 0, "innerHTML代入が見つかりません");

  innerHtmlAssignments.forEach(function (assignment) {
    assert.ok(
      assignment.indexOf("+") === -1,
      "innerHTMLへ文字列連結している可能性があります: " + assignment
    );
  });
});

test("ピン留め一覧の本文(data.html)はサーバー側でレンダリングされたものをそのまま挿入するだけであること", function () {
  assert.ok(source.indexOf("body.innerHTML = data.html;") !== -1);
});

test("メッセージ本体のピン留め/解除成功時、サーバーが返したHTML(data.html)でメッセージノードを置き換えること", function () {
  assert.ok(source.indexOf("messageScope.outerHTML = data.html;") !== -1);
});

console.log("\n" + passed + " passed, " + failures + " failed");
process.exit(failures > 0 ? 1 : 0);
