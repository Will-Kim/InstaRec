# InstaRec

InstaRec는 iOS와 Android에서 동작하는 실시간 오디오 녹음 앱입니다. 백그라운드에서 지속적으로 녹음하며, 체크 버튼이나 볼륨 버튼을 눌러 최근 60초(설정 가능)부터 현재까지의 오디오를 MP3 파일로 저장할 수 있습니다.

## 주요 기능

- 🎙️ **백그라운드 녹음**: 앱이 백그라운드에 있어도 지속적으로 오디오 녹음
- ⏰ **순환 버퍼**: 최근 60초(설정 가능)의 오디오를 메모리에 버퍼링
- 🔴 **즉시 캡처**: 체크 버튼이나 볼륨 버튼으로 즉시 녹음 시작/중지
- 💾 **MP3 저장**: WAV에서 MP3로 자동 변환하여 저장
- ⚙️ **버퍼 시간 조정**: 10초 단위로 버퍼 시간 조정 가능
- 📱 **크로스플랫폼**: iOS와 Android 모두 지원

## 설치 및 실행

### 사전 요구사항

- Node.js (16.0 이상)
- React Native CLI
- Android Studio (Android 개발용)
- Xcode (iOS 개발용, macOS만)

### 1. 의존성 설치

```bash
npm install
```

### 2. iOS 설정 (macOS만)

```bash
cd ios
pod install
cd ..
```

### 3. Android 실행

```bash
npx react-native run-android
```

### 4. iOS 실행 (macOS만)

```bash
npx react-native run-ios
```

## 사용법

1. **서비스 시작**: "서비스 시작" 버튼을 눌러 백그라운드 녹음을 시작합니다.
2. **캡처 시작**: "캡처 시작" 버튼을 누르거나 볼륨 버튼을 눌러 녹음을 시작합니다.
3. **캡처 종료**: "캡처 종료" 버튼을 누르거나 볼륨 버튼을 다시 눌러 녹음을 중지하고 파일을 저장합니다.
4. **버퍼 설정**: 버퍼 시간을 10초 단위로 조정할 수 있습니다.

## 기술 스택

- **React Native**: 크로스플랫폼 모바일 앱 개발
- **react-native-audio-recorder-player**: 오디오 녹음 및 재생
- **react-native-volume-manager**: 볼륨 버튼 이벤트 처리
- **react-native-fs**: 파일 시스템 접근
- **react-native-background-job**: 백그라운드 작업
- **react-native-ffmpeg**: 오디오 포맷 변환
- **react-native-keep-awake**: 화면 꺼짐 방지

## 권한 요구사항

### Android
- `RECORD_AUDIO`: 마이크 접근
- `WRITE_EXTERNAL_STORAGE`: 파일 저장
- `READ_EXTERNAL_STORAGE`: 파일 읽기
- `WAKE_LOCK`: 백그라운드 실행
- `FOREGROUND_SERVICE`: 포그라운드 서비스
- `FOREGROUND_SERVICE_MICROPHONE`: 마이크 포그라운드 서비스

### iOS
- `NSMicrophoneUsageDescription`: 마이크 접근
- `UIBackgroundModes`: 백그라운드 오디오 처리

## 아키텍처

### 순환 버퍼 시스템
- `CircularAudioBuffer` 클래스로 실시간 오디오 데이터 관리
- 설정된 시간(기본 60초)만큼의 오디오를 메모리에 버퍼링
- 새로운 데이터가 들어오면 오래된 데이터를 자동으로 덮어씀

### 백그라운드 서비스
- Android: `AudioRecordingService`로 포그라운드 서비스 구현
- iOS: `UIBackgroundModes`의 `audio` 모드 활용
- 앱이 백그라운드에 있어도 녹음 지속

### 볼륨 버튼 처리
- Android: `VolumeButtonReceiver`로 시스템 볼륨 이벤트 감지
- iOS: `VolumeManager`로 볼륨 변경 이벤트 처리
- 디바운싱으로 중복 이벤트 방지

## 파일 구조

```
InstaRec/
├── src/
│   └── components/
│       └── InstaRec.tsx          # 메인 컴포넌트
├── android/
│   └── app/src/main/java/com/instarec/
│       ├── MainActivity.java
│       ├── MainApplication.java
│       ├── AudioRecordingService.java
│       └── VolumeButtonReceiver.java
├── ios/
│   └── InstaRec/
│       ├── AppDelegate.h
│       ├── AppDelegate.mm
│       └── Info.plist
├── App.tsx
└── package.json
```

## 개발 노트

### 네이티브 모듈 구현 필요
현재 코드에는 일부 네이티브 모듈이 시뮬레이션 모드로 구현되어 있습니다. 실제 프로덕션 환경에서는 다음 네이티브 모듈들을 구현해야 합니다:

1. **실시간 오디오 캡처 모듈**
   - Android: `AudioRecord` API 사용
   - iOS: `AVAudioEngine` 사용

2. **볼륨 버튼 이벤트 모듈**
   - Android: `BroadcastReceiver` 구현
   - iOS: `VolumeManager` 네이티브 브리지

### 성능 최적화
- 메모리 사용량 최적화를 위해 버퍼 크기 조정
- 배터리 소모 최적화를 위한 효율적인 오디오 처리
- 백그라운드 실행 시 시스템 리소스 관리

## 문제 해결

### 일반적인 문제들

1. **권한 오류**: 앱 설정에서 마이크 권한이 허용되어 있는지 확인
2. **백그라운드 중지**: Android의 배터리 최적화 설정에서 앱을 제외
3. **볼륨 버튼 미작동**: 일부 기기에서는 볼륨 버튼 이벤트가 제한될 수 있음

### 디버깅
- React Native 디버거 사용
- 네이티브 로그 확인 (Android: `adb logcat`, iOS: Xcode Console)
- 메모리 사용량 모니터링

## 라이선스

MIT License

## 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 연락처

프로젝트에 대한 질문이나 제안사항이 있으시면 이슈를 생성해 주세요.


