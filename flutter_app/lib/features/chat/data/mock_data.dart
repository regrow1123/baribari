import '../domain/models.dart';

class MockData {
  static final trips = [
    Trip(
      id: '1',
      userId: 'dummy',
      title: '도쿄 3박 4일 🇯🇵',
      destination: 'Tokyo, Japan',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 4),
      travelStyle: ['관광', '맛집'],
      budgetKrw: 1500000,
      status: TripStatus.planning,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      lastMessage: '일정 짜볼게요! 🗓️',
    ),
    Trip(
      id: '2',
      userId: 'dummy',
      title: '방콕 4박 5일 🇹🇭',
      destination: 'Bangkok, Thailand',
      status: TripStatus.completed,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 25)),
      lastMessage: '좋은 여행 되셨나요? 😊',
    ),
  ];

  static final messages = <String, List<Message>>{
    '1': [
      Message(
        id: 'm1',
        tripId: '1',
        role: 'assistant',
        content: '안녕하세요! 여행 계획을 도와드릴게요 ✈️\n어디로 여행을 계획하고 계신가요?',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Message(
        id: 'm2',
        tripId: '1',
        role: 'user',
        content: '도쿄 3박 4일 여행 가려고! 맛집이랑 관광 위주로',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
      ),
      Message(
        id: 'm3',
        tripId: '1',
        role: 'assistant',
        content: '도쿄 좋죠! 😊 4월 1일부터 3박 4일, 맛집+관광 위주로 일정 짜볼게요!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
      ),
      Message(
        id: 'm4',
        tripId: '1',
        role: 'assistant',
        content: '일정을 짜봤어요! 어떠세요? 수정하고 싶은 부분 있으면 말씀해주세요 👇',
        messageType: MessageType.itineraryCard,
        metadata: {
          'days': [
            {
              'day': 1,
              'date': '2026-04-01',
              'items': [
                {
                  'title': '아사쿠사 센소지',
                  'description': '도쿄 대표 사찰, 나카미세 거리 구경',
                  'timeSlot': '09:00-11:00',
                  'transport': '긴자선 아사쿠사역',
                  'estimatedCostKrw': 0,
                },
                {
                  'title': '츠키지 아우터 마켓',
                  'description': '신선한 해산물과 길거리 음식',
                  'timeSlot': '12:00-14:00',
                  'transport': '히비야선 츠키지역',
                  'estimatedCostKrw': 25000,
                },
                {
                  'title': '시부야 스크램블 교차로',
                  'description': '하치코 동상 + 시부야 스카이',
                  'timeSlot': '15:00-17:00',
                  'transport': 'JR 야마노테선',
                  'estimatedCostKrw': 15000,
                },
                {
                  'title': '이자카야 저녁',
                  'description': '시부야 뒷골목 현지 이자카야',
                  'timeSlot': '18:00-20:00',
                  'transport': '도보',
                  'estimatedCostKrw': 35000,
                },
              ],
            },
            {
              'day': 2,
              'date': '2026-04-02',
              'items': [
                {
                  'title': '메이지 신궁',
                  'description': '하라주쿠 옆 평화로운 신사',
                  'timeSlot': '09:00-10:30',
                  'transport': 'JR 하라주쿠역',
                  'estimatedCostKrw': 0,
                },
                {
                  'title': '하라주쿠 & 오모테산도',
                  'description': '트렌디한 거리 쇼핑',
                  'timeSlot': '11:00-13:00',
                  'transport': '도보',
                  'estimatedCostKrw': 20000,
                },
                {
                  'title': '라멘 맛집',
                  'description': '후우우우진 라멘 본점',
                  'timeSlot': '13:30-14:30',
                  'transport': '도보',
                  'estimatedCostKrw': 12000,
                },
              ],
            },
          ],
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      ),
      Message(
        id: 'm5',
        tripId: '1',
        role: 'user',
        content: '준비물도 알려줘!',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Message(
        id: 'm6',
        tripId: '1',
        role: 'assistant',
        content: '도쿄 3박 4일 기준 준비물이에요! 🎒',
        messageType: MessageType.packingCard,
        metadata: {
          'categories': [
            {
              'name': '서류',
              'items': ['여권', '항공권 (e-티켓)', '호텔 바우처', '여행자보험 증서'],
            },
            {
              'name': '전자기기',
              'items': ['스마트폰 충전기', '보조배터리', '일본용 어댑터 (A타입)', '이어폰'],
            },
            {
              'name': '의류',
              'items': ['얇은 겉옷 (4월 쌀쌀)', '편한 운동화', '속옷/양말 4세트', '잠옷'],
            },
            {
              'name': '세면도구',
              'items': ['칫솔/치약', '세안제', '선크림', '기초화장품'],
            },
            {
              'name': '기타',
              'items': ['상비약 (소화제, 진통제)', '우산 (4월 비 올 수 있음)', '현금 (엔화)', '교통카드 (SUICA/PASMO)'],
            },
          ],
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ],
  };
}
