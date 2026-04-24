# band診断 本番前チェックリスト

## 1. 診断作成
- [ ] 作成画面に「バンド演奏診断」が表示される
- [ ] bandを選んで音源をアップロードできる
- [ ] 診断が completed になる

## 2. payload確認
- [ ] performance_type が band
- [ ] specific 6項目が保存されている
- [ ] quality_flags が保存されている
- [ ] quality_message が保存されている
- [ ] analysis_debug が保存されている

確認したい payload 例:

```json
{
  "performance_type": "band",
  "overall_score": 0,
  "pitch_score": 0,
  "rhythm_score": 0,
  "expression_score": 0,
  "specific": {
    "balance": 0,
    "tightness": 0,
    "groove": 0,
    "role_clarity": 0,
    "dynamics": 0,
    "cohesion": 0
  },
  "quality_flags": {
    "too_short": false,
    "too_quiet": false,
    "too_loud": false,
    "clipping_detected": false,
    "mostly_silent": false,
    "low_confidence": false
  },
  "quality_message": "",
  "analysis_debug": {}
}
```

## 3. 結果画面
- [ ] アンサンブル診断セクションが表示される
- [ ] specific 6項目がカード表示される
- [ ] quality_message がある場合、注意文が表示される
- [ ] development環境のみ analysis_debug が表示される
- [ ] development環境のみ Payload確認 が表示される
- [ ] 本番環境では analysis_debug が表示されない
- [ ] 本番環境では Payload確認 が表示されない

## 4. Premium
- [ ] Premiumユーザーに週間アドバイスが表示される
- [ ] 無料ユーザーにはPremium誘導が表示される
- [ ] band用の週間テーマが表示される

## 5. 低品質音源
- [ ] 短い音源で low_confidence になる
- [ ] 無音音源で mostly_silent になる
- [ ] 音割れ音源で clipping_detected になる

## 6. 導線
- [ ] 作成画面にbandの説明文が表示される
- [ ] 作成画面に推奨音源の案内が表示される
- [ ] LPにband診断の説明が表示される
- [ ] Premium案内にband向け週間アドバイスの説明が含まれる

## 7. 既存診断への影響
- [ ] vocal診断が動く
- [ ] guitar診断が動く
- [ ] bass診断が動く
- [ ] drums診断が動く
- [ ] keyboard診断が動く
