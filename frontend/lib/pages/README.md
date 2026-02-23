# Pages 구조 규칙

## 기본 구조
- `pages/<feature>/`에 화면과 로직을 모읍니다.
- 라우팅은 `lib/routes.dart`에서만 관리합니다.

## 서비스 규칙
- 화면에서 사용하는 서비스는 `pages/<feature>/services/`에 둡니다.
- 서비스 파일명은 `*Service.dart`로 통일합니다.
- 화면은 해당 feature의 서비스만 직접 참조합니다.

예시:
```
lib/
  pages/
    auth/
      login_page.dart
      services/
        HtOauthService.dart
    main/
      main_page.dart
      services/
        JiraService.dart
```

## 상태/뷰모델 규칙
- 화면별 상태/뷰모델은 `pages/<feature>/state/`에 둡니다.
- 파일명은 `*State.dart` 또는 `*ViewModel.dart` 중 하나로 통일합니다.
- 화면 위젯은 같은 feature의 상태/뷰모델만 직접 참조합니다.
