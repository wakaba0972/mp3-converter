# MP4 轉 MP3

使用 Flutter 與 Dart 開發的 Android App，可在手機本機將單一 MP4 的音軌轉換為 MP3，不需將影片上傳至伺服器。

詳細功能與驗收範圍請參考 [MVP_SPEC.md](MVP_SPEC.md)。

## MVP 功能

- 使用 Android 系統檔案選擇器挑選 MP4。
- 設定輸出檔名及 128、192、320 kbps 音質。
- 使用 FFmpeg 在裝置本機轉換。
- 顯示進度並支援取消轉換。
- 自動避開同名輸出檔案。
- 完成後播放或分享 MP3。
- 處理無音軌、損壞檔案、來源遺失及轉換失敗等情況。

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
- 轉換控制器的成功、失敗與取消測試。
- 初始畫面、檔案資訊、驗證訊息與完成畫面的 Widget 測試。

任何功能修改都必須同步新增或更新相關測試，並在提交前確認格式化、靜態分析和完整測試通過。

## Android 裝置驗證

建立 APK 後，使用實體 Android 手機驗證以下流程：

1. 選擇含音軌的 MP4。
2. 分別以 128、192、320 kbps 轉換。
3. 確認 MP3 可播放及分享。
4. 取消一次進行中的轉換，確認沒有殘留損壞檔案。
5. 使用無音軌或損壞的 MP4，確認 App 顯示錯誤且不會閃退。

## 已知技術風險

目前 FFmpeg Flutter 套件仍使用 Kotlin Gradle Plugin。它可在目前 Flutter 版本正常建置，但 Flutter 已警告未來版本將要求外掛遷移至 Built-in Kotlin。升級 Flutter 或 FFmpeg 套件時，必須重新執行完整 Android 建置與裝置驗證。
