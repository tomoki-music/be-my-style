// このリポジトリにはJS用の自動テストフレームワーク(Jest等)が導入されていないため、
// Node.js標準の assert のみで書いた素のスクリプトとして用意した(chat_mention_autocomplete_spec.js
// と同じ方針)。
//
// 実行方法:
//   node spec/javascript/chat_reply_composer_spec.js
//
// 対象: app/assets/javascripts/public/chat_rooms/chat_reply_composer.js
// このファイルはtextarea/hidden field/DOM生成を伴う処理が中心で、DOM非依存の純粋関数を
// 持たないため、ここでは「Node.js環境(document未定義)で読み込んでも例外にならないこと」
// (= typeof document === "undefined" のガードが正しく機能していること)のみを検証する。
// フォーカス・スクロール・hidden field更新・Turbolinksクリーンアップ等の実際のDOM操作は
// ブラウザでの実機確認で担保する(chat_message_scroll_highlight.js等、既存ファイルも同様)。

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
      path.join(__dirname, "..", "..", "app", "assets", "javascripts", "public", "chat_rooms", "chat_reply_composer.js")
    );
  });
});

console.log("\n" + passed + " passed, " + failures + " failed");
process.exit(failures > 0 ? 1 : 0);
