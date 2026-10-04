class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.time,
    required this.isMerchant,
    this.isRead = false,
  });
  final String text;
  final String time;
  final bool isMerchant;
  final bool isRead;
}

const initialCustomerConversation = [
  ChatMessage(
    text: 'Hi, the milk is out of stock. Would you like to replace it with almond milk?',
    time: '10:15 AM',
    isMerchant: true,
    isRead: true,
  ),
  ChatMessage(
    text: "Yes, that's fine. Thank you!",
    time: '10:17 AM',
    isMerchant: false,
  ),
];
