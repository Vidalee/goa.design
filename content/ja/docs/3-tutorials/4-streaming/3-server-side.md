---
title: "サーバーサイドストリーミングの実装"
linkTitle: サーバーサイド
weight: 3
---

Goaの`StreamingResult` DSLを使用してサーバーストリーミングエンドポイントを
設計したら、次のステップは結果のストリーミングを処理するサーバーサイドロジックと、
ストリームを消費するクライアントサイドコードの両方を実装することです。
このガイドでは、Goaでストリーミングエンドポイントの両側を実装する方法を
説明します。

## サーバーサイドの実装

DSLでサーバーストリーミングメソッドを定義すると、Goaはサーバーが実装する
特定のストリームインターフェースを生成します。これらのインターフェースは、
ストリーミングデータをクライアントに送信することを容易にします。

### サーバーストリームインターフェース

以下のような設計を想定します：
```go
var _ = Service("logger", func() {
    Method("subscribe", func() {
        StreamingResult(LogEntry)
        HTTP(func() {
            GET("/logs/stream")
            Response(StatusOK)
        })
    })
})
```

サーバーストリームインターフェースには、データの送信とストリームの終了のための
メソッドが含まれます：

```go
// サーバーが満たすべきインターフェース
type ListServerStream interface {
    // "StoredBottle"のインスタンスをストリーミング
    Send(*LogEntry) error
    // ストリームを終了
    Close() error
}
```

### 主要なメソッド

- **Send:** 指定された型（`LogEntry`）のインスタンスをクライアントに送信します。
  このメソッドは複数回呼び出して、複数の結果をストリーミングできます。
- **Close:** ストリームを終了し、データ送信の終了を通知します。
  `Close`を呼び出した後、`Send`への後続の呼び出しはエラーになります。

### 実装例

以下はサーバーサイドストリーミングエンドポイントの実装例です：

```go
// ログエントリをクライアントにストリーミング
func (s *loggerSvc) Subscribe(ctx context.Context, stream logger.SubscribeServerStream) error {
    logEntries, err := loadLogEntries()
    if err != nil {
        return fmt.Errorf("ログエントリの読み込みに失敗: %w", err)
    }

    for _, logEntry := range logEntries {
        if err := stream.Send(logEntry); err != nil {
            return fmt.Errorf("ログエントリの送信に失敗: %w", err)
        }
    }

    return stream.Close()
}
```

### エラー処理

適切なエラー処理により、堅牢なストリーミング動作を確保します：

- 送信エラーを処理するために、常に`Send`の戻り値をチェックします
- クライアントが切断されたりコンテキストがキャンセルされた場合、`Send`メソッドはエラーを返します
- デバッグのために、エラーは適切なコンテキストでラップされていることを確認します
- 必要に応じて、一時的な障害に対するリトライロジックの実装を検討します

## クライアントサイドの実装

クライアントサイドの実装には、ストリーミングデータの受信と処理が含まれます。
Goaは、ストリームを消費しやすくするクライアントインターフェースを生成します。

### クライアントストリームインターフェース

生成されたクライアントインターフェースには、データの受信とストリームの処理のための
メソッドが含まれます：

```go
// クライアントがストリームを受信するために使用するインターフェース
type ListClientStream interface {
    // Recvはストリーム内の次の結果を返します
    Recv() (*LogEntry, error)
    // Closeはストリームを終了します
    Close() error
}
```

### クライアント実装例

以下はクライアント側でストリームを消費する方法です：

```go
func processLogEntryStream(client logger.Client) error {
    stream, err := client.List(context.Background())
    if err != nil {
        return fmt.Errorf("ストリームの開始に失敗: %w", err)
    }
    defer stream.Close()

    for {
        logEntry, err := stream.Recv()
        if err == io.EOF {
            // ストリームが終了
            return nil
        }
        if err != nil {
            return fmt.Errorf("ログエントリの受信エラー: %w", err)
        }

        // 受信したログエントリを処理
        processLogEntry(logEntry)
    }
}
```

### クライアントの主要な考慮事項

1. **ストリームの初期化:**
   - 生成されたクライアントメソッドを使用してストリームを作成
   - 処理を進める前に初期化エラーをチェック
   - 適切なクリーンアップを確保するために`defer stream.Close()`を使用

2. **データの受信:**
   - EOFまたはエラーが発生するまで、データを継続的に受信するループを使用
   - `io.EOF`を通常のストリーム終了条件として処理
   - アプリケーションのニーズに基づいて他のエラーを適切に処理

3. **リソース管理:**
   - 完了時に必ずストリームを終了
   - 必要に応じてコンテキストを介してタイムアウトやデッドラインを使用
   - 適切なエラー処理とロギングを実装

## まとめ

Goaでのストリーミングの実装には、データのサーバーサイドストリーミングと
ストリームのクライアントサイド消費の両方が含まれます。これらのパターンと
エラー処理およびリソース管理のベストプラクティスに従うことで、APIの応答性と
スケーラビリティを向上させる堅牢なストリーミングエンドポイントを構築できます。

サーバーの実装は、データの効率的な送信とエラー処理に焦点を当て、クライアントの
実装は、ストリーミングデータの受信と処理のためのクリーンなインターフェースを
提供します。これらが組み合わさって、Goaサービスでリアルタイムまたは大規模な
データセットを処理するための強力なメカニズムを作成します。 