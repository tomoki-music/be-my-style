// chat_reply_composer_spec.js と同じ方針(Jest等未導入のためNode標準assertのみ使用)。
//
// 実行方法:
//   node spec/javascript/chat_thread_panel_spec.js
//
// 対象: app/assets/javascripts/public/chat_rooms/chat_thread_panel.js
// DOM非依存の純粋関数を持たないため、Node.js環境(document未定義)で読み込んでも
// 例外にならないことのみを検証する。開閉・fetch・ハイライト・フォーカストラップ等の
// 実際のDOM操作はブラウザでの実機確認で担保する。

"use strict";

var assert = require("assert");
var path = require("path");

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
    require(
      path.join(__dirname, "..", "..", "app", "assets", "javascripts", "public", "chat_rooms", "chat_thread_panel.js")
    );
  });
});

console.log("\n" + passed + " passed, " + failures + " failed");
process.exit(failures > 0 ? 1 : 0);
