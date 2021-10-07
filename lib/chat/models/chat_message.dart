import 'package:chat_ui_kit/chat_ui_kit.dart';

import 'dart:math';

import 'chat_user.dart';

enum ChatMessageType {
  image,
  video,
  audio,
  text,
  other,
  addUser,
  leaveChat,
  renameChat,
  typingStart,
  typingStop,
  delete
}

class ChatMessage extends MessageBase {
  String id; //usually a UUID
  String chatId;
  ChatMessageType type;
  ChatUser author;
  ChatUser owner;
  String text;
  String attachment; //URL for the incoming attachment once downloaded and stored locally
  String mimeType;
  String fileName;
  DateTime creationTimestamp; //server creation timestamp
  bool bSend;
  bool bRead;

  ChatMessage({
    this.id,
    this.chatId,
    this.type = ChatMessageType.text,
    this.owner,
    this.author,
    this.text,
    this.attachment,
    this.mimeType,
    this.fileName,
    this.creationTimestamp,
    this.bSend, this.bRead}) {
    if (id == null || id.isEmpty) id = _generateRandomString(10);
    if (creationTimestamp == null) creationTimestamp = DateTime.now();
  }

  @override
  DateTime get createdAt => creationTimestamp;

  @override
  String get url => attachment;

  @override
  MessageBaseType get messageType {
    if (type == ChatMessageType.text) return MessageBaseType.text;
    if (type == ChatMessageType.image) return MessageBaseType.image;
    if (type == ChatMessageType.audio) return MessageBaseType.audio;
    if (type == ChatMessageType.video) return MessageBaseType.video;
    if (type == ChatMessageType.other) return MessageBaseType.image;
    return MessageBaseType.other;
  }

  bool get isTypeMedia {
    return type == ChatMessageType.video || type == ChatMessageType.image;
  }

  bool get isTypeEvent {
    return !isUserMessage && type != ChatMessageType.delete;
  }

  /// Helper message to check if the message is a user input,
  /// as opposed to generated events like renaming, leaving a chat
  bool get isUserMessage {
    final List<ChatMessageType> userTypes = [
      ChatMessageType.text,
      ChatMessageType.image,
      ChatMessageType.video,
      ChatMessageType.audio
    ];
    return userTypes.contains(type);
  }

  bool get hasAttachment => attachment != null && attachment.isNotEmpty;

  String messageText(String localUserId) {
    if (type == ChatMessageType.renameChat) {
      if (author.id == localUserId) {
        //current user renamed the chat
        return "You renamed the chat";
      } else {
        //another user renamed the chat
        return "${author.username} renamed the chat to '$text'";
      }
    } else {
      //type message, check if it's a file attachment
      if (!hasAttachment) return text;
      if (type == ChatMessageType.audio) {
        return "Voice";
      } else if (type == ChatMessageType.video) {
        return "Video";
      } else if (type == ChatMessageType.image) {
        if (mimeType.indexOf('image/') >= 0) return "Image";
        else return fileName;  //"Image";
      } else {
        return fileName;
      }
    }
  }

  String _generateRandomString(int len) {
    var r = Random();
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  Map<String, dynamic>toMap() {
    return {
      "n_message": chatId,
      "n_writer": author.user,
      "c_owner": owner.id,
      "d_write": creationTimestamp.toString(),
      "c_contents": text,
      "b_send": bSend?"1":"0",
      "b_read": bRead?"1":"0",
      "c_attach": attachment,
      "c_type": mimeType,
      "c_name": fileName,
    };
  }
}
