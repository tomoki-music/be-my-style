'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { parseDelimited, detectDelimiter, stringifyDelimited } = require('../js/csv.js');

test('カンマ区切りCSVを読み込める', () => {
  const text = '氏名,鍵の数\n高橋 扶美,2\n伊藤 美穂,7';
  const { headers, rows } = parseDelimited(text, ',');
  assert.deepEqual(headers, ['氏名', '鍵の数']);
  assert.deepEqual(rows, [['高橋 扶美', '2'], ['伊藤 美穂', '7']]);
});

test('タブ区切りTSVを読み込める', () => {
  const text = '氏名\t鍵の数\n高橋 扶美\t2';
  const { headers, rows } = parseDelimited(text, '\t');
  assert.deepEqual(headers, ['氏名', '鍵の数']);
  assert.deepEqual(rows, [['高橋 扶美', '2']]);
});

test('セル内改行を保持できる', () => {
  const text = '氏名,メモ\n高橋 扶美,"1行目\n2行目"';
  const { rows } = parseDelimited(text, ',');
  assert.equal(rows[0][1], '1行目\n2行目');
});

test('セル内カンマを保持できる', () => {
  const text = '氏名,メモ\n高橋 扶美,"東京都,千代田区"';
  const { rows } = parseDelimited(text, ',');
  assert.equal(rows[0][1], '東京都,千代田区');
});

test('セル内ダブルクォートを保持できる', () => {
  const text = '氏名,メモ\n高橋 扶美,"""特別""対応"';
  const { rows } = parseDelimited(text, ',');
  assert.equal(rows[0][1], '"特別"対応');
});

test('日本語が文字化けしない', () => {
  const text = '氏名\n倉田 瑠美';
  const { rows } = parseDelimited(text, ',');
  assert.equal(rows[0][0], '倉田 瑠美');
});

test('空欄セルを維持する', () => {
  const text = '氏名,備考\n高橋 扶美,';
  const { rows } = parseDelimited(text, ',');
  assert.deepEqual(rows[0], ['高橋 扶美', '']);
});

test('末尾の改行があっても余分な空行が出ない', () => {
  const text = '氏名,鍵の数\n高橋 扶美,2\n';
  const { rows } = parseDelimited(text, ',');
  assert.equal(rows.length, 1);
});

test('detectDelimiter: タブが多い場合はタブと判定する', () => {
  assert.equal(detectDelimiter('氏名\t鍵の数\n高橋\t2'), '\t');
});

test('detectDelimiter: カンマが多い場合はカンマと判定する', () => {
  assert.equal(detectDelimiter('氏名,鍵の数\n高橋,2'), ',');
});

test('stringifyDelimited: 改行・カンマ・ダブルクォートを正しくエスケープする', () => {
  const headers = ['氏名', 'メモ'];
  const rows = [['高橋 扶美', '1行目\n2行目,"引用"']];
  const text = stringifyDelimited(headers, rows, ',');
  const reparsed = parseDelimited(text, ',');
  assert.deepEqual(reparsed.rows[0], rows[0]);
});

test('stringifyDelimited -> parseDelimited のラウンドトリップでTSVも復元できる', () => {
  const headers = ['お名前', '性別'];
  const rows = [['高橋\t扶美', '女性'], ['倉田　瑠美', '女性']];
  const text = stringifyDelimited(headers, rows, '\t');
  const reparsed = parseDelimited(text, '\t');
  assert.deepEqual(reparsed.headers, headers);
  assert.deepEqual(reparsed.rows, rows);
});
