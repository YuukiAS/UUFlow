# UUFlow

UUFlow は UU远程 向けの macOS ディスプレイ補助ツールです。現在のコントローラーを識別し、その機器専用の仮想ディスプレイを 1 台だけ作成します。セッション終了時には、ウインドウ、メインディスプレイ、物理ディスプレイのモードを復元します。

> UUFlow は UU远程 の公式ソフトウェアではありません。現在、公開済みの UUFlow バイナリ Release はありません。ソースからビルドしてインストールしてください。

[中文](README.md) · [English](README.en.md) · [開発](docs/development.md) · [仕組み](docs/how-it-works.md)

## 現在の機能

Phase 1 は完了し、凍結されています。

- OnePlus 12（`一加 12 全网通版`）は専用横画面だけを作成します。
- iPad Air M1（`iPad Air 5`）は iPad 専用画面だけを作成します。
- ThinkPad E16（`THINKPAD-E16`）は `1280×720` のコンピューター画面だけを作成します。
- MacBook Neo（`MacBook-Neo`）は `1408×881` の画面だけを作成し、セッション中だけ一時的にメインディスプレイになります。
- Legion Y9000P（`LEGION-Y9000P`）は明示的にバイパスします。
- 未認識、未登録、競合、無効、または欠落したルートでは仮想画面を作成しません。
- スマートフォンとタブレットではタッチ操作と App ライブラリを使い、コンピューター画面では通常のデスクトップ動作を保ちます。
- 終了時は元の物理メインディスプレイを先に復元し、解像度、HiDPI、リフレッシュレートを保持します。

keyboard mode、LOCAL / REMOTE、Alt+Tab、トラックパッド機能はまだ実装されていません。

## ソースからインストール

macOS 14 以降、Xcode/Swift 6、動作する UU远程 が必要です。

```bash
git clone https://github.com/YuukiAS/UUFlow.git
cd UUFlow
scripts/uuflow check
scripts/uuflow install
```

App は `/Applications/UUFlow.app` にインストールされます。現在の UU远程 コントローラーの読み取り、ウインドウ移動、タッチ変換には macOS のアクセシビリティ権限が必要です。

## 開発コマンド

```text
scripts/uuflow check             全ビルドとテスト
scripts/uuflow app               build/UUFlow.app を作成
scripts/uuflow install           /Applications/UUFlow.app へ安全に移行して起動
scripts/uuflow dist              署名・公証済みのローカル DMG を作成
scripts/uuflow remote-check uu   UU远程 互換性チェック
```

内部 Swift target は互換性のため `Snug`、`SnugCore`、`SnugSystem` のままです。bundle ID は `com.zephyr4123.snug`、既存データは `~/Library/Application Support/Snug` から引き続き読み取ります。これらは権限、画面 ID、ユーザーデータを守るための内部名であり、製品ブランドではありません。

UUFlow に実行時アップデーターはありません。起動時に上流の update feed へ接続したり、別の App を自動ダウンロードしたりしません。

## 上流プロジェクトとライセンス

UUFlow は [Snug](https://github.com/zephyr4123/snug) と、それ以前の [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) を基に開発されています。MIT ライセンスと著作権表示は [LICENSE](LICENSE) を参照してください。
