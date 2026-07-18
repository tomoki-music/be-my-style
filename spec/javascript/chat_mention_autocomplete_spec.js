// このリポジトリにはJS用の自動テストフレームワーク(Jest等)が導入されていないため、
// Node.js標準の assert のみで書いた素のスクリプトとして用意した(package.json への
// テストコマンド追加やCI連携は今回のスコープ外。手動実行のみ想定)。
//
// 実行方法:
//   node spec/javascript/chat_mention_autocomplete_spec.js
//
// 対象: app/assets/javascripts/public/chat_rooms/chat_mention_autocomplete.js
// (position計算・メンション範囲追跡・内部記法変換の純粋関数群。DOM非依存)
"use strict";

var assert = require("assert");
var path = require("path");
var fns = require(
  path.join(__dirname, "..", "..", "app", "assets", "javascripts", "public", "chat_rooms", "chat_mention_autocomplete.js")
);

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

// ---- computeDropdownPosition(候補リスト位置計算) ----
test("十分な空間があれば下向きに表示される", function () {
  var pos = fns.computeDropdownPosition(
    { top: 100, bottom: 120, left: 50, right: 50 },
    { width: 220, height: 200 },
    { width: 1000, height: 800 }
  );
  assert.strictEqual(pos.openUpward, false);
  assert.strictEqual(pos.top, 120);
  assert.strictEqual(pos.left, 50);
});

test("画面下に十分な空間がない場合は上向きに表示される", function () {
  var pos = fns.computeDropdownPosition(
    { top: 700, bottom: 720, left: 50, right: 50 },
    { width: 220, height: 240 },
    { width: 1000, height: 800 }
  );
  assert.strictEqual(pos.openUpward, true);
  assert.strictEqual(pos.top, 700 - 240);
});

test("上にも十分な空間がなければ(狭い場合)下向きのまま", function () {
  var pos = fns.computeDropdownPosition(
    { top: 30, bottom: 50, left: 50, right: 50 },
    { width: 220, height: 240 },
    { width: 1000, height: 100 }
  );
  // spaceBelow(50) < height(240) だが spaceAbove(30) <= spaceBelow(50) なので下向きのまま
  assert.strictEqual(pos.openUpward, false);
});

test("右へはみ出す場合はビューポート内に補正される", function () {
  var pos = fns.computeDropdownPosition(
    { top: 100, bottom: 120, left: 900, right: 900 },
    { width: 220, height: 200 },
    { width: 1000, height: 800 }
  );
  assert.strictEqual(pos.left, 1000 - 220);
});

test("左へはみ出す場合は0に補正される", function () {
  var pos = fns.computeDropdownPosition(
    { top: 100, bottom: 120, left: -50, right: -50 },
    { width: 220, height: 200 },
    { width: 1000, height: 800 }
  );
  assert.strictEqual(pos.left, 0);
});

test("候補が多く最大高さを超える場合、topがビューポート内に収まる(内部はCSSのoverflow-yでスクロール)", function () {
  var pos = fns.computeDropdownPosition(
    { top: 10, bottom: 30, left: 50, right: 50 },
    { width: 220, height: 240 }, // CSSのmax-heightと一致させて呼び出す想定
    { width: 1000, height: 800 }
  );
  assert.ok(pos.top + 240 <= 800);
});

// ---- diffAndAdjustMentions(生の編集イベントに対するメンション範囲の追従・解除) ----
test("編集区間より前のメンションはそのまま", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 0, end: 7 }];
  var result = fns.diffAndAdjustMentions("@tomoki foo", "@tomoki foobar", mentions);
  assert.deepStrictEqual(result, mentions);
});

test("編集区間より後のメンションは追従してずれる", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 5, end: 12 }];
  var result = fns.diffAndAdjustMentions("hi @tomoki", "hi! @tomoki", mentions);
  assert.strictEqual(result.length, 1);
  assert.strictEqual(result[0].start, 6);
  assert.strictEqual(result[0].end, 13);
});

test("メンション文字列の途中を編集すると解除される", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 0, end: 7 }];
  var result = fns.diffAndAdjustMentions("@tomoki", "@tomoZki", mentions);
  assert.strictEqual(result.length, 0);
});

test("メンション文字列の一部を削除すると解除される", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 0, end: 7 }];
  var result = fns.diffAndAdjustMentions("@tomoki", "@tomok", mentions);
  assert.strictEqual(result.length, 0);
});

test("複数メンションのうち編集区間に重ならないものだけ残る", function () {
  var mentions = [
    { customerId: 1, username: "aaa", start: 0, end: 4 },
    { customerId: 2, username: "bbb", start: 10, end: 14 }
  ];
  var result = fns.diffAndAdjustMentions("@aaa X @bbb", "@aaa XXXXX @bbb", mentions);
  assert.strictEqual(result.length, 2);
  assert.strictEqual(result[0].start, 0);
  assert.strictEqual(result[1].start, 10 + (15 - 11));
});

test("絵文字(サロゲートペア)を含む編集でも位置がJS文字列長基準で一貫していること", function () {
  // 🎵は2コードユニット。JS文字列操作は常にUTF-16単位で一貫しているため、
  // 変換をブラウザ(JS)側だけで完結させる設計により、Ruby側のコードポイント基準との
  // ズレを気にせず自己無矛盾に位置追従できることを確認する。
  var before = "🎵 @tomoki";
  assert.strictEqual(before.length, 10); // 🎵=2 + " "=1 + "@tomoki"=7
  assert.strictEqual(before.slice(3, 10), "@tomoki");
  var mentions = [{ customerId: 1, username: "tomoki", start: 3, end: 10 }];
  var after = "🎵🎵 @tomoki"; // 先頭にもう1つ🎵(2コードユニット)を追加
  var result = fns.diffAndAdjustMentions(before, after, mentions);
  assert.strictEqual(result.length, 1);
  assert.strictEqual(result[0].start, 5);
  assert.strictEqual(result[0].end, 12);
  assert.strictEqual(after.slice(result[0].start, result[0].end), "@tomoki");
});

// ---- applyKnownReplacement(候補選択によるトークン挿入) ----
test("候補選択によるトークン挿入で後続メンションが追従する", function () {
  var mentions = [{ customerId: 2, username: "other", start: 10, end: 16 }];
  // triggerStart=0, caret=3 ("@to"を"@tomoki"に置換、+4文字)
  var result = fns.applyKnownReplacement(mentions, 0, 3, 7);
  assert.strictEqual(result[0].start, 14);
  assert.strictEqual(result[0].end, 20);
});

// ---- buildSubmissionContent(表示テキスト→内部記法への変換) ----
test("単一メンションを内部記法へ変換できる", function () {
  var content = fns.buildSubmissionContent("@tomoki よろしく", [
    { customerId: 123, username: "tomoki", start: 0, end: 7 }
  ]);
  assert.strictEqual(content, "[@tomoki](customer:123) よろしく");
});

test("複数メンションを内部記法へ変換できる", function () {
  var text = "@aaa さん @bbb さん";
  var content = fns.buildSubmissionContent(text, [
    { customerId: 1, username: "aaa", start: 0, end: 4 },
    { customerId: 2, username: "bbb", start: 8, end: 12 }
  ]);
  assert.strictEqual(content, "[@aaa](customer:1) さん [@bbb](customer:2) さん");
});

test("改ざんされた開始・終了位置(範囲外)は無視される", function () {
  var content = fns.buildSubmissionContent("@tomoki", [
    { customerId: 123, username: "tomoki", start: 0, end: 999 }
  ]);
  assert.strictEqual(content, "@tomoki");
});

test("改ざんされた文字列(該当位置が実際の@usernameと不一致)は無視される", function () {
  var content = fns.buildSubmissionContent("@hacker", [
    { customerId: 123, username: "tomoki", start: 0, end: 7 }
  ]);
  assert.strictEqual(content, "@hacker");
});

test("日本語ユーザー名でも正しく変換できる", function () {
  var content = fns.buildSubmissionContent("@今泉智貴 お願いします", [
    { customerId: 5, username: "今泉智貴", start: 0, end: 5 }
  ]);
  assert.strictEqual(content, "[@今泉智貴](customer:5) お願いします");
});

test("既存の内部記法を含む投稿はそのまま(このJSでは変換対象にしない=互換性)", function () {
  var content = fns.buildSubmissionContent("[@tomoki](customer:123) hi", []);
  assert.strictEqual(content, "[@tomoki](customer:123) hi");
});

// ---- filterOutSelf(候補一覧からの自分自身の除外。サーバー側除外に加えたフロント側二重防御) ----
test("自分自身のidを持つ候補が除外される", function () {
  var items = [{ id: 1, name: "自分" }, { id: 2, name: "他人" }];
  var result = fns.filterOutSelf(items, 1);
  assert.deepStrictEqual(result, [{ id: 2, name: "他人" }]);
});

test("candidate.idが数値・currentCustomerIdが文字列でも型差を吸収して除外される", function () {
  var items = [{ id: 1, name: "自分" }, { id: 2, name: "他人" }];
  var result = fns.filterOutSelf(items, "1");
  assert.deepStrictEqual(result, [{ id: 2, name: "他人" }]);
});

test("candidate.idが文字列・currentCustomerIdが数値でも型差を吸収して除外される", function () {
  var items = [{ id: "1", name: "自分" }, { id: "2", name: "他人" }];
  var result = fns.filterOutSelf(items, 1);
  assert.deepStrictEqual(result, [{ id: "2", name: "他人" }]);
});

test("同名の別ユーザーはidが異なるため除外されない", function () {
  var items = [{ id: 1, name: "今泉智貴" }, { id: 2, name: "今泉智貴" }];
  var result = fns.filterOutSelf(items, 1);
  assert.deepStrictEqual(result, [{ id: 2, name: "今泉智貴" }]);
});

test("currentCustomerIdが未指定(null/undefined/空文字)の場合は絞り込まない", function () {
  var items = [{ id: 1, name: "A" }, { id: 2, name: "B" }];
  assert.deepStrictEqual(fns.filterOutSelf(items, null), items);
  assert.deepStrictEqual(fns.filterOutSelf(items, undefined), items);
  assert.deepStrictEqual(fns.filterOutSelf(items, ""), items);
});

test("APIレスポンスが配列でなくても例外にならず空配列を返す", function () {
  assert.deepStrictEqual(fns.filterOutSelf(null, 1), []);
  assert.deepStrictEqual(fns.filterOutSelf(undefined, 1), []);
});

// ---- detectMentionTrigger(キャレット直前の@トークン検出。DOM非依存、value/selectionStart/selectionEndのみ参照) ----
test("先頭の@からキャレットまでをクエリとして検出する", function () {
  var trigger = fns.detectMentionTrigger({ value: "@tom", selectionStart: 4, selectionEnd: 4 });
  assert.deepStrictEqual(trigger, { start: 0, query: "tom" });
});

test("空白直後の@のみトリガーになる(単語途中の@は無視)", function () {
  var trigger = fns.detectMentionTrigger({ value: "foo@bar", selectionStart: 7, selectionEnd: 7 });
  assert.strictEqual(trigger, null);
});

test("選択範囲がある(selectionStart!==selectionEnd)場合は検出しない", function () {
  var trigger = fns.detectMentionTrigger({ value: "@tom", selectionStart: 1, selectionEnd: 4 });
  assert.strictEqual(trigger, null);
});

test("@からキャレットまでに空白を含む場合は検出しない(選択確定済みメンションの直後など)", function () {
  var trigger = fns.detectMentionTrigger({ value: "@今泉 智貴 ", selectionStart: 7, selectionEnd: 7 });
  assert.strictEqual(trigger, null);
});

// ---- isWithinFinalizedMentionRange(確定済みメンション範囲内へのキャレット復帰を判定) ----
test("確定済みメンションの開始位置と一致し範囲内にキャレットがあれば true", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 0, end: 7 }];
  assert.strictEqual(fns.isWithinFinalizedMentionRange(mentions, 0, 5), true);
});

test("トリガー開始位置が確定済みメンションと一致しなければ false", function () {
  var mentions = [{ customerId: 1, username: "tomoki", start: 0, end: 7 }];
  assert.strictEqual(fns.isWithinFinalizedMentionRange(mentions, 10, 12), false);
});

test("確定済みメンションが無ければ false", function () {
  assert.strictEqual(fns.isWithinFinalizedMentionRange([], 0, 3), false);
});

// ---- buildSelectionInsertion(候補選択時の挿入内容組み立て。選択後にリストが残り続ける問題の修正の中核) ----
test("選択した表示名の末尾に半角スペースが1つ挿入される", function () {
  var result = fns.buildSelectionInsertion("@いま", [], 0, 3, { id: 5, name: "今泉智貴" });
  assert.strictEqual(result.newValue, "@今泉智貴 ");
});

test("メンション範囲(start/end)は末尾の半角スペースを含まない(内部記法変換と整合させるため)", function () {
  var result = fns.buildSelectionInsertion("@いま", [], 0, 3, { id: 5, name: "今泉智貴" });
  var mention = result.mentions[0];
  assert.strictEqual(mention.start, 0);
  assert.strictEqual(mention.end, 5); // "@今泉智貴".length
  assert.strictEqual(result.newValue.slice(mention.start, mention.end), "@今泉智貴");
});

test("挿入後のカーソル位置は半角スペースの直後になる", function () {
  var result = fns.buildSelectionInsertion("@いま", [], 0, 3, { id: 5, name: "今泉智貴" });
  assert.strictEqual(result.newCaret, "@今泉智貴 ".length);
});

test("選択直後、挿入したメンション範囲では新しい検索トリガーが検出されない(リスト再表示の防止)", function () {
  var result = fns.buildSelectionInsertion("@いま", [], 0, 3, { id: 5, name: "今泉智貴" });
  var trigger = fns.detectMentionTrigger({
    value: result.newValue,
    selectionStart: result.newCaret,
    selectionEnd: result.newCaret
  });
  assert.strictEqual(trigger, null);
});

test("挿入によって後続の既存メンションが追従する", function () {
  var existing = [{ customerId: 2, username: "other", start: 10, end: 16 }];
  var result = fns.buildSelectionInsertion("@to 続き @other 以降", existing, 0, 3, { id: 1, name: "tomoki" });
  // "@to"(3文字)を"@tomoki "(8文字)に置換 -> +5。既存メンションが先、新規メンションは末尾に追加される
  assert.strictEqual(result.mentions[0].start, 15);
  assert.strictEqual(result.mentions[0].end, 21);
});

// ---- closedUiState(ドロップダウンを閉じた状態のUI状態契約) ----
test("isOpen/candidates/activeIndex/query/triggerStartがすべて初期化された状態を返す", function () {
  assert.deepStrictEqual(fns.closedUiState(), {
    open: false,
    items: [],
    activeIndex: -1,
    triggerStart: -1,
    query: ""
  });
});

console.log("\n" + passed + " passed, " + failures + " failed");
process.exitCode = failures > 0 ? 1 : 0;
