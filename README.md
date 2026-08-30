# 影片轉 MP3

使用 Flutter 與 Dart 開發的 Android App，可在手機本機批量將影片音軌轉換為 MP3，不需將影片上傳至伺服器。

詳細功能與驗收範圍請參考 [MVP_SPEC.md](MVP_SPEC.md)。

## MVP 功能

- 使用 Android 系統檔案選擇器一次挑選多個影片。
- 個別設定輸出檔名，整批套用 128、192 或 320 kbps 音質。
- 使用 FFmpeg 在裝置本機依序轉換，避免同時處理多個影片造成記憶體壓力。
- 顯示逐檔與整批進度，並支援取消整個批次。
- 自動避開同名輸出檔案。
- 每個完成項目都可個別播放或分享 MP3。
- 單一檔案失敗不會中止其他項目，並會顯示各自的錯誤原因。
- 自動忽略同一路徑的重複選取。
- 可切換淺色與暗黑模式，並在 App 關閉重啟後保留設定。

## 支援的來源格式

目前支援以下常見影片容器：

```text
MP4, MKV, MOV, AVI, WebM, M4V, 3GP, FLV, WMV,
MPEG, MPG, TS, MTS, M2TS
```

實際能否擷取音訊仍取決於影片內部使用的音訊編碼；若 FFmpeg 無法解碼或影片沒有音軌，該項目會顯示錯誤，批次中的其他影片仍會繼續處理。

## 輸出位置

轉換期間先使用 App 暫存目錄，成功後透過 Android MediaStore 發布至手機的公共目錄：

```text
Download/MP3 Converter/
```

因此產生的 MP3 可直接在系統「檔案」App 的 Download 資料夾看到。若已有同名檔案，會自動加上 `(1)`、`(2)` 等流水號，不會覆蓋既有檔案。

舊版曾將輸出寫入 App 專屬 Downloads 目錄。新版首次開始轉換前會掃描該舊目錄，並將找到的 MP3 一併遷移至公共輸出資料夾。

## 開發環境

專案目前使用：

- Flutter 3.47.2
- Dart 3.13.2
- Android SDK 36
- Android 最低版本 API 24（Android 7.0）
- Java 17 或以上

本機 Flutter 與 Android SDK 可放在 `.tooling` 目錄；該目錄不會提交至 Git。也可以使用已安裝在系統中的 Flutter 與 Android SDK。

## 常用指令

若 Flutter 已加入 `PATH`：

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

若使用專案內的 Flutter SDK：

```powershell
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\dart.bat format --output=none --set-exit-if-changed lib test
.\.tooling\flutter\bin\flutter.bat analyze
.\.tooling\flutter\bin\flutter.bat test
.\.tooling\flutter\bin\flutter.bat build apk --debug
```

Debug APK 會輸出至：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 測試

測試分為：

- 檔名、音質、進度與狀態的單元測試。
- 單檔及批量控制器的成功、逐檔失敗、取消與重複項目測試。
- 單檔及批量畫面的空狀態、檔案清單、驗證訊息與完成狀態 Widget 測試。

任何功能修改都必須同步新增或更新相關測試，並在提交前確認格式化、靜態分析和完整測試通過。

## Android 裝置驗證

建立 APK 後，使用實體 Android 手機驗證以下流程：

1. 一次選擇至少三個不同格式且含音軌的影片。
2. 分別以 128、192、320 kbps 執行批量轉換。
3. 確認每個 MP3 都可播放及分享。
4. 取消一次進行中的批次，確認目前項目及排隊項目均取消，且沒有殘留損壞檔案。
5. 在正常影片之間加入無音軌或損壞的影片，確認其他影片仍會繼續轉換。
6. 重複選取同一檔案，確認清單不會重複加入。

## 已知技術風險

目前 FFmpeg Flutter 套件仍使用 Kotlin Gradle Plugin。它可在目前 Flutter 版本正常建置，但 Flutter 已警告未來版本將要求外掛遷移至 Built-in Kotlin。升級 Flutter 或 FFmpeg 套件時，必須重新執行完整 Android 建置與裝置驗證。
