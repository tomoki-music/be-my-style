'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeName, buildSourceIndex, matchTargetRows, guessColumnIndex, STATUS } = require('../js/matcher.js');

test('normalizeName: 空白なし同士で一致', () => {
  assert.equal(normalizeName('高橋扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 半角スペースの有無が違っても一致', () => {
  assert.equal(normalizeName('高橋 扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 全角スペースの有無が違っても一致', () => {
  assert.equal(normalizeName('高橋　扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 前後に空白があっても一致', () => {
  assert.equal(normalizeName('  高橋扶美  '), normalizeName('高橋扶美'));
});

test('normalizeName: タブが含まれていても一致', () => {
  assert.equal(normalizeName('高橋\t扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 改行が含まれていても一致', () => {
  assert.equal(normalizeName('高橋\n扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 連続した空白があっても一致', () => {
  assert.equal(normalizeName('高橋   扶美'), normalizeName('高橋扶美'));
});

test('normalizeName: 異なる漢字は一致しない', () => {
  assert.notEqual(normalizeName('高橋扶美'), normalizeName('高橋芙美'));
});

test('normalizeName: 苗字だけ同じ場合は一致しない', () => {
  assert.notEqual(normalizeName('高橋扶美'), normalizeName('高橋一郎'));
});

test('normalizeName: 名前だけ同じ場合は一致しない', () => {
  assert.notEqual(normalizeName('高橋扶美'), normalizeName('伊藤扶美'));
});

// --- 照合ロジック ---

function makeSourceRows() {
  // ヘッダー: 氏名, 鍵の数, 魂の数, 使命数, 数秘表記
  return [
    ['高橋 扶美', '2', '3', '1', '2・3・M1'],
    ['伊藤 美穂', '7', '3', '9', '7・3・M9'],
    ['倉田 瑠美', '7', '7', '5', '7・7・M5'],
  ];
}

test('一致: Aの数秘4項目がBへ反映される', () => {
  const index = buildSourceIndex(makeSourceRows(), 0, [1, 2, 3, 4]);
  const rowsB = [['高橋扶美']];
  const results = matchTargetRows(rowsB, 0, index);
  assert.equal(results[0].status, STATUS.MATCH);
  assert.deepEqual(results[0].values, ['2', '3', '1', '2・3・M1']);
});

test('未一致: Aに存在しない氏名は数秘4項目が空になる', () => {
  const index = buildSourceIndex(makeSourceRows(), 0, [1, 2, 3, 4]);
  const rowsB = [['該当なし太郎']];
  const results = matchTargetRows(rowsB, 0, index);
  assert.equal(results[0].status, STATUS.NO_MATCH);
  assert.equal(results[0].values, null);
});

test('重複: Aに同じ正規化氏名が2件ある場合は重複扱いになる', () => {
  const rows = [
    ['山田 太郎', '1', '1', '1', '1・1・M1'],
    ['山田太郎', '2', '2', '2', '2・2・M2'],
  ];
  const index = buildSourceIndex(rows, 0, [1, 2, 3, 4]);
  const results = matchTargetRows([['山田 太郎']], 0, index);
  assert.equal(results[0].status, STATUS.DUPLICATE);
  assert.equal(results[0].values, null);
  assert.equal(results[0].candidateCount, 2);
});

test('重複: 数秘を自動反映しない（valuesはnull）', () => {
  const rows = [
    ['鈴木 花子', '1', '1', '1', '1・1・M1'],
    ['鈴木 花子', '2', '2', '2', '2・2・M2'],
  ];
  const index = buildSourceIndex(rows, 0, [1, 2, 3, 4]);
  const results = matchTargetRows([['鈴木花子']], 0, index);
  assert.equal(results[0].values, null);
});

test('重複件数が集計へ反映できる（candidateCountが件数と一致）', () => {
  const rows = [
    ['佐藤 次郎', '1', '1', '1', '1・1・M1'],
    ['佐藤 次郎', '2', '2', '2', '2・2・M2'],
    ['佐藤次郎', '3', '3', '3', '3・3・M3'],
  ];
  const index = buildSourceIndex(rows, 0, [1, 2, 3, 4]);
  const results = matchTargetRows([['佐藤 次郎']], 0, index);
  assert.equal(results[0].candidateCount, 3);
});

test('サンプルデータ: README記載の期待結果と一致する', () => {
  const index = buildSourceIndex(makeSourceRows(), 0, [1, 2, 3, 4]);
  const rowsB = [
    ['高橋扶美'],
    ['倉田　瑠美'],
    ['該当なし太郎'],
  ];
  const results = matchTargetRows(rowsB, 0, index);
  assert.equal(results[0].status, STATUS.MATCH);
  assert.deepEqual(results[0].values, ['2', '3', '1', '2・3・M1']);
  assert.equal(results[1].status, STATUS.MATCH);
  assert.deepEqual(results[1].values, ['7', '7', '5', '7・7・M5']);
  assert.equal(results[2].status, STATUS.NO_MATCH);
});

// --- 列名の自動推測 ---

test('guessColumnIndex: 氏名列候補から推測できる', () => {
  const headers = ['申込日', 'お名前', '性別'];
  const idx = guessColumnIndex(headers, ['氏名', 'お名前', '名前', '姓名', 'フルネーム']);
  assert.equal(idx, 1);
});

test('guessColumnIndex: 候補に一致しない場合は-1を返す', () => {
  const headers = ['申込日', '性別'];
  const idx = guessColumnIndex(headers, ['氏名', 'お名前', '名前', '姓名', 'フルネーム']);
  assert.equal(idx, -1);
});
