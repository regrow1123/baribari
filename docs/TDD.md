# TDD - 바리바리 (Technical Design Document)

## 1. 아키텍처 개요

```
┌─────────────────────────────────────────────┐
│          Flutter App (Web 우선, 채팅형)       │
│  ┌───────────┐  ┌───────────────┐           │
│  │  Chat UI   │  │  State Mgmt   │           │
│  │ (카톡 테마) │←→│  (Riverpod)   │           │
│  └───────────┘  └───────┬───────┘           │
│                         │                   │
│  ┌──────────────────────┴────────────────┐  │
│  │           Repository Layer            │  │
│  └──────┬──────────────┬─────────────────┘  │
│         │              │                    │
│  ┌──────┴──────┐ ┌─────┴──────────────┐    │
│  │  Drift      │ │  Supabase Client   │    │
│  │ (모바일 v2) │ │  (supabase_flutter) │    │
│  └─────────────┘ └─────┬──────────────┘    │
└─────────────────────────┼───────────────────┘
                          │
             ┌────────────┼────────────┐
             ▼                         ▼
┌──────────────────────┐  ┌──────────────────────────┐
│  Supabase (로컬)      │  │  Vercel                   │
│  ┌──────────────┐    │  │  ┌──────────────────────┐ │
│  │  PostgreSQL   │    │  │  │  Serverless Functions │ │
│  │  (채팅+여행DB)│    │  │  │  (LLM 호출+스트리밍)  │ │
│  └──────────────┘    │  │  └──────────┬───────────┘ │
│  ┌──────────────┐    │  │             ▼             │
│  │     Auth      │    │  │     Gemini       │
│  └──────────────┘    │  │                           │
│  ┌──────────────┐    │  │  ┌──────────────────────┐ │
│  │  Realtime     │    │  │  │  Flutter Web 호스팅   │ │
│  │  (선택, v2)   │    │  │  └──────────────────────┘ │
│  └──────────────┘    │  └──────────────────────────┘
└──────────────────────┘
```

## 2. 기술 스택

| 레이어 | 기술 | 선택 이유 |
|--------|------|-----------|
| UI Framework | Flutter 3.x (Web 우선) | 크로스 플랫폼, 웹+모바일 동일 코드 |
| 상태관리 | Riverpod | 타입 안전, 테스트 용이 |
| 서버 DB | Supabase PostgreSQL (로컬) | 이미 운영 중, BaaS |
| 인증 | Supabase Auth | 이메일/소셜 로그인 |
| 오프라인 캐시 | Drift (v2 모바일) | 모바일 빌드 시 추가 |
| LLM 백엔드 | Vercel Serverless Functions (TypeScript) | 콜드 스타트 빠름, 스트리밍 지원 |
| 웹 호스팅 | Vercel | Flutter Web 배포 |
| 라우팅 | go_router | 웹 URL 지원 |
| LLM | Gemini Flash | 구조화 출력 + 스트리밍 |

## 3. 데이터 모델

### 3.1 Supabase 테이블

```sql
-- 여행 (= 채팅방)
CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  title TEXT NOT NULL,              -- "도쿄 3박 4일"
  destination TEXT,
  start_date DATE,
  end_date DATE,
  travel_style TEXT[],
  budget_krw INTEGER,
  status TEXT DEFAULT 'planning',   -- planning / active / completed
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 채팅 메시지
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL,               -- 'user' / 'assistant' / 'system'
  content TEXT NOT NULL,            -- 텍스트 메시지
  message_type TEXT DEFAULT 'text', -- 'text' / 'itinerary_card' / 'packing_card' / 'system'
  metadata JSONB,                   -- 카드 데이터 (일정/준비물 JSON)
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 일정
CREATE TABLE itinerary_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  day_number INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  time_slot TEXT,
  transport TEXT,
  estimated_cost_krw INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 준비물
CREATE TABLE packing_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  is_checked BOOLEAN DEFAULT false,
  order_index INTEGER NOT NULL
);

-- 파일 첨부
CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  packing_item_id UUID REFERENCES packing_items(id) ON DELETE SET NULL,
  message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,          -- 'image/jpeg', 'application/pdf' 등
  file_size INTEGER NOT NULL,       -- bytes
  storage_path TEXT NOT NULL,       -- Supabase Storage 경로
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_messages_trip_id ON messages(trip_id, created_at);
CREATE INDEX idx_itinerary_trip_id ON itinerary_items(trip_id, day_number, order_index);
CREATE INDEX idx_packing_trip_id ON packing_items(trip_id, order_index);
CREATE INDEX idx_attachments_trip_id ON attachments(trip_id);
CREATE INDEX idx_attachments_packing_item ON attachments(packing_item_id);

-- RLS
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE itinerary_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE packing_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own trips"
  ON trips FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users own messages"
  ON messages FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "Users own itinerary"
  ON itinerary_items FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

CREATE POLICY "Users own packing"
  ON packing_items FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));

ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own attachments"
  ON attachments FOR ALL
  USING (trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid()));
```

### 3.2 Dart 모델

```dart
enum TripStatus { planning, active, completed }
enum MessageType { text, itineraryCard, packingCard, system }

class Trip {
  final String id;
  final String userId;
  final String title;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? travelStyle;
  final int? budgetKrw;
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Message {
  final String id;
  final String tripId;
  final String role;            // 'user' | 'assistant' | 'system'
  final String content;
  final MessageType messageType;
  final Map<String, dynamic>? metadata;  // 카드 JSON 데이터
  final DateTime createdAt;
}

class ItineraryItem {
  final String id;
  final String tripId;
  final int dayNumber;
  final int orderIndex;
  final String title;
  final String? description;
  final String? location;
  final String? timeSlot;
  final String? transport;
  final int? estimatedCostKrw;
  final String? notes;
}

class PackingItem {
  final String id;
  final String tripId;
  final String name;
  final String category;
  bool isChecked;
  final int orderIndex;
  final List<Attachment>? attachments;
}

class Attachment {
  final String id;
  final String tripId;
  final String? packingItemId;
  final String? messageId;
  final String fileName;
  final String fileType;        // MIME type
  final int fileSize;
  final String storagePath;     // Supabase Storage 경로
  final DateTime createdAt;

  String get url => supabase.storage.from('attachments').getPublicUrl(storagePath);
}
```

## 4. Vercel Serverless Functions

### 4.1 채팅 API (메인)
```
POST /api/chat

Headers:
  Authorization: Bearer <supabase_jwt>
  Content-Type: application/json

Request:
{
  "trip_id": "uuid",
  "message": "도쿄 3박 4일 맛집 위주로 짜줘",
  "history": [
    { "role": "assistant", "content": "안녕하세요! ..." },
    { "role": "user", "content": "도쿄 여행 가려고" }
  ]
}

Response: (Server-Sent Events 스트리밍)
data: {"type": "text", "content": "도쿄"}
data: {"type": "text", "content": " 맛집 여행"}
data: {"type": "text", "content": " 일정을 짜볼게요!"}
data: {"type": "itinerary", "data": { ... }}
data: {"type": "done"}
```

### 4.2 인증 검증
```typescript
// api/_lib/auth.ts
import { createClient } from '@supabase/supabase-js';

export async function verifyAuth(req: Request) {
  const token = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!token) throw new Error('Unauthorized');

  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) throw new Error('Invalid token');

  return user;
}
```

### 4.3 LLM 프롬프트 설계

```typescript
const SYSTEM_PROMPT = `당신은 "바리바리", 친근한 여행 플래너 AI입니다.

역할:
- 사용자와 대화하며 여행 일정과 준비물을 계획합니다
- 카카오톡 친구처럼 친근하고 캐주얼한 톤을 사용합니다
- 이모지를 적절히 사용합니다

일정 생성 시:
- 반드시 아래 JSON 형식으로 출력합니다
- 동선을 고려하여 효율적으로 배치합니다
- 현실적인 시간 배분을 합니다

일정 JSON 형식:
\`\`\`json
{"type": "itinerary", "data": {"days": [{"day": 1, "date": "2026-04-01", "items": [{"title": "...", "description": "...", "location": "...", "time_slot": "09:00-11:00", "transport": "...", "estimated_cost_krw": 0, "notes": "..."}]}]}}
\`\`\`

준비물 JSON 형식:
\`\`\`json
{"type": "packing", "data": {"categories": [{"name": "서류", "items": ["여권", "비자"]}]}}
\`\`\`

일반 대화는 자연스럽게 텍스트로 답변합니다.
JSON 블록 앞뒤로 자연스러운 설명을 추가합니다.`;
```

## 5. Supabase Storage (파일 저장)

### 5.1 버킷 구성
```sql
-- attachments 버킷 생성 (비공개)
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false);

-- 유저 본인 파일만 접근
CREATE POLICY "Users can upload own files"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own files"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own files"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);
```

### 5.2 파일 경로 규칙
```
attachments/{user_id}/{trip_id}/{uuid}_{filename}
```

### 5.3 업로드 흐름
```
1. Flutter에서 파일 선택 (file_picker)
2. Supabase Storage에 직접 업로드 (supabase_flutter SDK)
3. attachments 테이블에 메타데이터 저장
4. packing_item_id 또는 message_id에 연결
5. UI에서 미리보기 표시 (이미지: 썸네일, PDF: 아이콘+파일명)
```

### 5.4 제한
- 파일 크기: 최대 10MB
- 허용 타입: image/jpeg, image/png, application/pdf
- 여행당 최대 파일 수: 50개

## 6. 배포 구조

### 5.1 프로젝트 레포 구조
```
baribari/
├── flutter_app/              # Flutter 소스
│   ├── lib/
│   ├── web/
│   ├── pubspec.yaml
│   └── ...
├── api/                      # Vercel Serverless Functions
│   ├── chat.ts               # 메인 채팅 API
│   ├── _lib/
│   │   ├── auth.ts           # JWT 검증
│   │   ├── llm.ts            # LLM 호출 래퍼
│   │   └── prompts.ts        # 프롬프트 관리
│   └── tsconfig.json
├── vercel.json
├── package.json
└── docs/
    ├── PRD.md
    └── TDD.md
```

### 5.2 vercel.json
```json
{
  "buildCommand": "cd flutter_app && flutter build web --release --web-renderer html",
  "outputDirectory": "flutter_app/build/web",
  "functions": {
    "api/**/*.ts": {
      "maxDuration": 30
    }
  },
  "rewrites": [
    { "source": "/api/(.*)", "destination": "/api/$1" },
    { "source": "/((?!api/).*)", "destination": "/index.html" }
  ]
}
```

### 5.3 환경변수

| 변수 | 위치 | 설명 |
|------|------|------|
| `SUPABASE_URL` | Vercel + Flutter | Supabase 프로젝트 URL |
| `SUPABASE_ANON_KEY` | Vercel + Flutter | Supabase 공개 키 |
| `SUPABASE_SERVICE_KEY` | Vercel only | 서버사이드 전용 |
| `GEMINI_API_KEY` | Vercel only | LLM API 키 |
| `LLM_MODEL` | Vercel only | 모델명 (gemini-2.0-flash 등) |

Flutter에서는 `--dart-define`으로 빌드 시 주입:
```bash
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## 7. 인증 흐름

### v1 (더미 유저)
```
[웹 접속] → 자동으로 더미 유저 세션 사용 → 채팅 목록
```
- Supabase에 더미 유저 1명 생성 (seed)
- RLS 정책은 유지 (v2 전환 대비)
- 앱 시작 시 더미 유저 UUID를 하드코딩 또는 환경변수로 주입

### v2 (실제 인증)
```
[웹 접속] → [Supabase Auth 세션 확인]
              │
        ┌─────┴─────┐
        │ 세션 있음   │ 세션 없음
        │ → 채팅 목록 │ → 로그인
        └───────────┘
              │
    [이메일/비밀번호 or Google/Kakao]
              │
    [JWT 발급 → RLS + Vercel API 인증]
```

## 8. 채팅 메시지 흐름

```
1. 유저 입력 → messages 테이블에 저장 (role='user')
2. 최근 메시지 N개 조회 → history 구성
3. POST /api/chat (SSE 스트리밍)
4. 스트리밍 텍스트 → UI에 실시간 표시
5. JSON 블록 감지 → 파싱 → 카드 UI로 렌더링
6. 완료 시 → messages 테이블에 저장 (role='assistant')
7. 일정/준비물 JSON → itinerary_items / packing_items에도 저장
```

## 9. UI 컴포넌트 설계

### 8.1 카카오톡 테마 토큰
```dart
class KakaoTheme {
  // 색상
  static const background = Color(0xFFB2C7D9);    // 채팅 배경
  static const myBubble = Color(0xFFFEE500);       // 내 말풍선
  static const otherBubble = Color(0xFFFFFFFF);    // 상대 말풍선
  static const sidebarBg = Color(0xFFFFFFFF);      // 사이드바
  static const headerBg = Color(0xFF3C1E1E);       // 상단 헤더
  static const primary = Color(0xFF391B1B);        // 주요 텍스트
  static const secondary = Color(0xFF999999);      // 보조 텍스트

  // 말풍선
  static const bubbleRadius = 16.0;
  static const bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  // 카드
  static const cardRadius = 12.0;
  static const cardShadow = BoxShadow(...);
}
```

### 8.2 메시지 위젯 트리
```
ChatScreen
├── AppBar (여행 제목, 메뉴)
├── MessageList (ListView)
│   ├── UserBubble (노란색, 오른쪽)
│   ├── AssistantBubble (흰색, 왼쪽)
│   │   ├── TextMessage (일반 텍스트)
│   │   ├── ItineraryCard (일정 카드 - 접기/펼치기)
│   │   └── PackingCard (준비물 체크리스트)
│   └── SystemMessage (중앙 회색 텍스트)
└── InputBar (텍스트 입력 + 전송 버튼)
```

## 10. 오프라인 전략

### 9.1 웹 (v1)
- 온라인 전용 (Supabase 직접 조회)
- Service Worker로 정적 자산 캐싱 (PWA)
- 오프라인 시 "인터넷 연결이 필요합니다" 안내

### 9.2 모바일 (v2)
- Drift로 messages, itinerary_items, packing_items 로컬 캐싱
- 오프라인 열람 + 체크리스트 체크 가능
- 온라인 복귀 시 Supabase 동기화

## 11. 보안

- **JWT 검증**: Vercel Functions에서 모든 요청에 Supabase JWT 검증
- **RLS**: DB 레벨에서 유저별 데이터 격리
- **Rate Limiting**: Vercel Functions에 분당 10회 제한 (LLM 비용 방지)
- **Input Validation**: 메시지 길이 제한 (2000자), SQL injection 방지 (Supabase SDK 사용)
- **API Key 보호**: LLM API 키는 서버사이드(Vercel 환경변수)에만 존재

## 12. 프로젝트 구조 (Flutter)

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── supabase/             # Supabase 초기화, 클라이언트
│   ├── api/                  # Vercel API 호출 (SSE 스트리밍)
│   ├── router/               # go_router
│   └── theme/                # 카카오톡 테마 정의
├── features/
│   ├── auth/
│   │   ├── data/             # Supabase Auth
│   │   └── presentation/     # 로그인/회원가입 화면
│   ├── chat/
│   │   ├── data/             # MessageRepository, SSE 클라이언트
│   │   ├── domain/           # Message, 모델
│   │   └── presentation/
│   │       ├── chat_screen.dart
│   │       ├── widgets/
│   │       │   ├── user_bubble.dart
│   │       │   ├── assistant_bubble.dart
│   │       │   ├── itinerary_card.dart
│   │       │   ├── packing_card.dart
│   │       │   └── input_bar.dart
│   │       └── providers/
│   ├── trip/
│   │   ├── data/             # TripRepository
│   │   ├── domain/           # Trip 모델
│   │   └── presentation/     # 채팅 목록 (사이드바)
│   └── packing/
│       ├── data/             # PackingRepository
│       └── domain/           # PackingItem 모델
└── shared/
    ├── widgets/              # 공통 (로딩, 에러 등)
    └── utils/                # 날짜 포맷, JSON 파서 등
```

## 13. 에러 처리

| 상황 | 처리 |
|------|------|
| 네트워크 없음 | "인터넷 연결을 확인해주세요" 토스트 |
| LLM 응답 파싱 실패 | 원본 텍스트 말풍선으로 표시 + 로그 |
| LLM 타임아웃 (30초) | "응답이 느려요. 다시 시도할까요?" + 재시도 버튼 |
| Supabase 연결 실패 | 재시도 + 에러 메시지 |
| 인증 만료 | 자동 갱신 (supabase_flutter) |
| Rate limit 초과 | "잠시 후 다시 시도해주세요" (남은 시간 표시) |

## 14. 테스트 전략

| 레벨 | 대상 | 도구 |
|------|------|------|
| Unit | 모델, Repository, JSON 파싱 | flutter_test |
| Widget | 말풍선, 카드, 입력바 | flutter_test |
| Integration | 채팅 플로우 (mock API) | integration_test |
| API | Vercel Functions | vitest |

## 15. CI/CD

```
[GitHub Push]
  → Vercel 자동 배포 (프리뷰 + 프로덕션)
  → Flutter Web 빌드 + API Functions 배포
  → PR별 프리뷰 URL 생성
```

- **브랜치 전략**: main (프로덕션) / develop (개발) / feature/* (기능)
- **자동 테스트**: PR 시 unit + widget 테스트 실행

## 16. 개발 단계

| Phase | 내용 | 기간 |
|-------|------|------|
| **P1** | Flutter 프로젝트 셋업, Supabase 테이블/RLS, 더미 유저 seed, Vercel 초기 배포, 카톡 테마 기본 UI | 1주 |
| **P2** | 채팅 API (Vercel Functions + LLM), SSE 스트리밍, 메시지 저장/조회 | 1주 |
| **P3** | 일정 카드 + 준비물 카드 UI, JSON 파싱, 체크리스트 인터랙션 | 1주 |
| **P4** | 대화형 수정, 여행 목록 관리, UI 폴리시, PWA, 에러 처리 | 1주 |
| **P5** (v2) | 모바일 빌드, Drift 오프라인, 동기화, 지도 등 | 1주 |
