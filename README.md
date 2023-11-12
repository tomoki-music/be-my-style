# <img src="#" alt="BeMyStyle Logo" width="50" height="50"> BeMyStyle
## <img src="#" alt="BeMyStyle Logo" width="40" height="40"> サイト概要
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> サイトテーマ
「BeMyStyle」は、趣味で音楽（セッションバンド演奏）を楽しみたい人に向けた、音楽人の為のコミュニティサイトです。

### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> このアプリに関する運営方針
このサイトは、「趣味」で音楽演奏を楽しみたい人の為に運営されます。
- 初心者歓迎: 音楽経験の浅い初心者の方にも安心してご利用頂けるよう、セッションを運営しております。
- 意見の尊重: コミュニティには色んな方が集まります。意見の違いを否定せず楽しみ、尊重できることを重要視しています。
- コミュニティの意義: コミュニティ内でバンドメンバーを見つける事は構いませんが、基本的にはコミュニティ内での活動はセッションとなります。
色んな人と色んな演奏体験を楽しんで頂けたらと思います。
​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> テーマを選んだ理由


​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> ターゲットユーザー
- バンド演奏初心者：
- 何か趣味を持ちたい人：
- 地域で貢献活動に興味ある方：


​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 主な利用シーン
- 休日のイベント参加：
- 興味のあるコミュニティ参加：
- 趣味の合うメンバーと繋がる：
- みんなの活動報告：


<!-- ## <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 設計書 -->

## <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 開発環境
- OS：Linux(CentOS)
- 言語：HTML,CSS,JavaScript,Ruby(3.1.2),SQL
- フレームワーク：Ruby on Rails
- JSライブラリ：jQuery
- クラウドストレージ：Amazon S3 EC2

### Required
* ImageMagick(v7.1.1-5)
sudo yum -y install libpng-devel libjpeg-devel libtiff-devel gcc-c++ git
git clone -b 7.1.1-5 --depth 1 https://github.com/ImageMagick/ImageMagick.git ImageMagick-7.1.1-5
cd ImageMagick-7.1.1-5
./configure
make
sudo make install
* ChromeDriver
* MySQL
* Node.js
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
