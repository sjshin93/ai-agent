# UI Kit Guide

이 문서는 `frontend/lib/ui` 와 `frontend/lib/widgets/bs` 컴포넌트를 사용하는 방법을 간단히 정리합니다.

## 1) 기본 개념

- **Theme**: `BootstrapTheme.light()` 가 전체 기본 스타일을 제공합니다.
- **Tokens**: `BsTokens` 를 통해 여백/반경/hover 등 UI 디테일을 중앙에서 관리합니다.
- **Components**: `widgets/bs` 의 컴포넌트는 테마/토큰을 자동으로 따릅니다.

## 2) 적용 방법

`frontend/lib/app.dart` 에서 테마를 적용합니다.

```dart
MaterialApp(
  theme: BootstrapTheme.light(),
  // ...
)
```

## 3) 토큰 수정 가이드

`frontend/lib/ui/bootstrap_tokens.dart` 에서 값 변경 시 전체 컴포넌트가 같이 변경됩니다.

예:

```dart
final tokens = BsTokens(
  radiusSm: 6,
  radiusMd: 8,
  buttonPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  inputPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  cardPadding: const EdgeInsets.all(16),
  listItemPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  tabPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  badgePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  alertPadding: const EdgeInsets.all(12),
  toastPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  menuPadding: const EdgeInsets.all(4),
  menuElevation: 2,
  hoverOpacity: 0.08,
  pressedOpacity: 0.12,
  alertFillOpacity: 0.12,
  toastOpacity: 0.8,
  mutedOpacity: 0.6,
);
```

## 4) 컴포넌트 목록

### Buttons / Text / Inputs
- `BsButton`
- `BsText`
- `BsTextField`
- `BsSelect`
- `BsDropdown`

### Status / Layout
- `BsBadge`
- `BsAlert`
- `BsCard`

### Controls
- `BsCheckbox`
- `BsRadio`
- `BsSwitch`
- `BsTabs`

### Overlay
- `BsModal.showConfirm`
- `BsToast.show`

## 5) 사용 예시

```dart
// Button
BsButton(
  label: '확인',
  onPressed: () {},
);

// Text
BsText('제목', variant: BsTextVariant.title);

// Input
BsTextField(
  label: '이름',
  hintText: '입력하세요',
);

// Select
BsSelect<String>(
  label: '옵션',
  value: selected,
  items: const [
    DropdownMenuItem(value: 'A', child: Text('A')),
    DropdownMenuItem(value: 'B', child: Text('B')),
  ],
  onChanged: (v) => setState(() => selected = v),
);

// Dropdown menu
BsDropdown<String>(
  label: '메뉴',
  value: selected,
  items: const [
    PopupMenuItem(value: 'A', child: Text('A')),
    PopupMenuItem(value: 'B', child: Text('B')),
  ],
  onSelected: (v) => setState(() => selected = v),
);

// Badge
BsBadge(label: 'NEW', variant: BsVariant.success);

// Alert
BsAlert(message: '저장되었습니다.');

// Card
BsCard(
  child: Text('내용'),
);

// Checkbox
BsCheckbox(
  label: '동의합니다',
  value: checked,
  onChanged: (v) => setState(() => checked = v ?? false),
);

// Radio
BsRadio<String>(
  label: '옵션 A',
  value: 'A',
  groupValue: selectedRadio,
  onChanged: (v) => setState(() => selectedRadio = v ?? 'A'),
);

// Switch
BsSwitch(
  label: '알림',
  value: enabled,
  onChanged: (v) => setState(() => enabled = v),
);

// Tabs
BsTabs(
  tabs: const [Tab(text: 'Tab1'), Tab(text: 'Tab2')],
  views: const [Center(child: Text('A')), Center(child: Text('B'))],
);

// Modal
final ok = await BsModal.showConfirm(
  context,
  title: '확인',
  message: '진행할까요?',
);

// Toast
BsToast.show(context, message: '저장 완료');
```

## 6) 주의 사항

- `BsTokens` 기반으로 디자인을 조절하세요.
- 컴포넌트에 하드코딩 스타일을 넣지 않는 것을 권장합니다.
- `NotoSansCJKkr` 폰트를 실제로 쓰려면 폰트 파일을 추가하고 `pubspec.yaml`에 등록해야 합니다.
