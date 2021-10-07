import 'dart:core';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show json;
import 'dart:convert' show utf8;

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:chat_ui_kit/chat_ui_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../utils/app_const.dart';
import '../../globals.dart' as globals;

class ChatViewModel {
  static ChatUser initialUser = ChatUser(id: AppConstants.localUserId,
      user: AppConstants.localUserId,
      group: '',
      lastPost: DateTime.now(),
      unRead: 0);
  ChatUser get localUser => chatUsers.length>0?chatUsers[0]:initialUser;
  Map<String, List<ChatMessage>> chatMessages = {};
  ChatsListController controller;
  Database sqlite3;

  List<ChatUser> chatUsers = [initialUser];

  ChatViewModel() {
    /*
    chatMessages = {
      "test_chat_id_0": [
        ChatMessage(
            author: chatUsers[1],
            text: "you? :)",
            creationTimestamp: DateTime.now().millisecondsSinceEpoch - 5000),
        ChatMessage(
            author: chatUsers[1],
            text: "not much",
            creationTimestamp: DateTime.now().millisecondsSinceEpoch - 3000),
        ChatMessage(
            author: localUser,
            text: "sup",
            creationTimestamp: DateTime.now().millisecondsSinceEpoch),
      ],
      "test_chat_id_1": [
        ChatMessage(
            type: ChatMessageType.image,
            author: localUser,
            attachment: 'images/other/paris_e_tower.jpg',
            creationTimestamp: DateTime(2020, 12, 29).millisecondsSinceEpoch)
      ],
      "test_chat_id_2": [
        ChatMessage(
            author: localUser,
            text: "Xmas was awesome!",
            creationTimestamp: DateTime(2020, 12, 28).millisecondsSinceEpoch)
      ],
      "test_chat_id_3": [
        ChatMessage(
            author: localUser,
            text: "Let's create a group",
            creationTimestamp: DateTime(2020, 12, 27).millisecondsSinceEpoch)
      ],
      "test_chat_id_4": [
        ChatMessage(
            author: localUser,
            type: ChatMessageType.image,
            attachment: 'images/other/paris_e_tower.jpg',
            creationTimestamp:
                DateTime(2020, 12, 26, 10, 5, 4).millisecondsSinceEpoch),
        ChatMessage(
            author: localUser,
            text: "Check out where I went during my last holidays",
            creationTimestamp:
                DateTime(2020, 12, 26, 10, 5, 2).millisecondsSinceEpoch),
        ChatMessage(
            author: localUser,
            text: "Me three",
            creationTimestamp:
                DateTime(2020, 12, 22, 8, 6, 2).millisecondsSinceEpoch),
        ChatMessage(
            author: chatUsers[5],
            text: "Me too",
            creationTimestamp:
                DateTime(2020, 12, 22, 8, 6).millisecondsSinceEpoch),
        ChatMessage(
            author: chatUsers[1],
            text: "I like it",
            creationTimestamp:
                DateTime(2020, 12, 22, 8, 5).millisecondsSinceEpoch),
        ChatMessage(
            author: chatUsers[3],
            text: "Do you guys like the new title?",
            creationTimestamp:
                DateTime(2020, 12, 22, 8, 1).millisecondsSinceEpoch),
        ChatMessage(
            author: chatUsers[3],
            type: ChatMessageType.renameChat,
            text: "Paradise",
            creationTimestamp:
                DateTime(2020, 12, 22, 8).millisecondsSinceEpoch),
      ],
      "test_chat_id_5": [
        ChatMessage(
            author: chatUsers[5],
            text: "What are you doing on new year's eve?",
            creationTimestamp: DateTime(2020, 12, 23).millisecondsSinceEpoch)
      ],
    };
       */
  }

  Future<List<ChatUser>> getUsers() async {
    final List<Map<String, dynamic>> maps = await sqlite3.query('bt_user');
    return List.generate(maps.length, (i) {
      return ChatUser(
        id: maps[i]['c_id'],
        user: maps[i]['n_user'].toString(),
        group: maps[i]['n_group'].toString(),
        username: maps[i]["c_name"],
        avatarURL: maps[i]["c_photo"],
        lastPost: maps[i]["d_last"].toString().isEmpty?null:DateTime.parse(maps[i]["d_last"]),
        unRead: maps[i]["n_unread"]
      );
    });
  }

  ChatUser findUser(String id) {
    for (var user in chatUsers) {
      if (user.user == id) {
        return user;
      }
    }
    return null;
  }

  Future<List<ChatMessage>> getMessages(ChatUser owner) async {
    List<Map<String, dynamic>> maps = await sqlite3.query(
        'bt_message', where: "c_owner = ?", whereArgs: [owner.id], orderBy: "d_write desc");
    return List.generate(maps.length, (i) {
      ChatUser author = findUser(maps[i]['n_writer'].toString());
      if (author == null) {
        author = ChatUser(id: "user_"+maps[i]['n_writer'].toString(), user: maps[i]['n_writer'].toString());
      }
      var messType = ChatMessageType.text;
      String url = maps[i]['c_attach'];
      String mimeType = maps[i]['c_type'];
      if (url != null && url.toString().isNotEmpty) {
        messType = ChatMessageType.image;
        var mime = mimeType.toString();
        if (mime.indexOf('image/') >= 0) {
          messType = ChatMessageType.image;
        } else if (mime.indexOf('video/') >= 0) {
          messType = ChatMessageType.video;
        } else if (mime.indexOf('audio/') >= 0) {
          messType = ChatMessageType.audio;
        } else {
          print("mime type: "+maps[i]["c_name"]+" user "+author.user);
        }
      }
      return ChatMessage(
        chatId: maps[i]['n_message'].toString(),
        owner: owner,
        author: author,
        text: maps[i]['c_contents'],
        type: messType,
        attachment: url,
        mimeType: mimeType,
        fileName: maps[i]["c_name"],
        creationTimestamp: DateTime.parse(maps[i]['d_write']),
        bSend: maps[i]['b_send']>0,
        bRead: maps[i]['b_read']>0,
      );
    });
  }

  Future<String>readMemberList() async {
    // Construct a file path to copy database to
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "chat.db");

    //File(path).deleteSync();

    // Only copy if the database doesn't exist
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound){
      // Load database from asset and copy
      ByteData data = await rootBundle.load(join('assets', 'database.db'));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Save copied asset to documents
      await new File(path).writeAsBytes(bytes);
    }
    this.sqlite3 = await openDatabase(path);

    List<ChatUser> list = await getUsers();
    if (list.length > 0) {
      chatUsers.addAll(list);
    }

    String snsid = await globals.storage.read(key: "snsID");
    String photo = await globals.storage.read(key: "photo");
    String myName = await globals.storage.read(key: "fullname");
    chatUsers[0].id = "user_"+snsid;
    chatUsers[0].user = snsid;
    if (chatUsers.length == 1) {
      chatUsers[0].username = myName;
      chatUsers[0].avatarURL = photo;
      var users = await readPartnerList();
      if (users != null) {
        chatUsers.insertAll(1, users);
      }
    }

    for (var partner in chatUsers) {
      var messages = await getMessages(partner);
      if (messages.length > 0) {
        chatMessages[partner.id] = messages;
      }
    }
    if (chatMessages.length == 0) {
      for (var owner in chatUsers) {
        List<ChatMessage> messages = await readMemberListForUser(owner);
        chatMessages[owner.id] = messages;
      }
    }
    return "";
  }

  Future<List<ChatUser>>readPartnerList({bool save = true}) async {
    String type = await globals.storage.read(key: "loginType");
    String token = await globals.storage.read(key: "token");
    String snsid = await globals.storage.read(key: "snsID");
    String photo = await globals.storage.read(key: "photo");

    List<ChatUser> users = [];
    return users;
  }

  Future<List<ChatMessage>>readMemberListForUser(ChatUser owner, {bool all = true}) async {
    String type = await globals.storage.read(key: "loginType");
    String token = await globals.storage.read(key: "token");
    String snsid = await globals.storage.read(key: "snsID");
    String photo = await globals.storage.read(key: "photo");

    List<ChatMessage> messages = [];
    return messages;
  }

  int getUnRead(String id) {
    int unread = 0;
    List<ChatMessage> messages = chatMessages[id];
    for (int i = 0; i < messages.length; ++i) {
      ChatMessage mess = messages[i];
      if (!mess.bRead) ++ unread;
    }
    return unread;
  }

  List<ChatUser> getMembers(List<ChatMessage> messlist) {
    List<ChatUser> list = [localUser];
    for (int i = 0; i < messlist.length; ++i) {
      var mess = messlist[i];
      if (list.indexOf(mess.author) >= 0) {} else {
        list.add(mess.author);
      }
    }
    return list;
  }

  Future<List<ChatWithMembers>> generateChats() async {
    if (chatUsers.length == 1) {
      await readMemberList();
    }
    //String snsid = await globals.storage.read(key: "snsID");
    final List<ChatWithMembers> _chats = [];
    for (var partner in chatUsers) {
      var id = partner.id;
      if (chatMessages.keys.contains(id) && chatMessages[id].length > 0) {
        var members = getMembers(chatMessages[id]);
        if (partner.group != "") {
          members.insert(0, partner);
        }
        if (members.length > 1) {
          _chats.add(ChatWithMembers(
              lastMessage: chatMessages[id].first,
              chat: Chat(
                  id: id, ownerId: localUser.id, unreadCount: getUnRead(id)),
              members: members));
        }
      }
    }
    /*
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_0"].first,
        chat: Chat(id: "test_chat_id_0", ownerId: localUser.id, unreadCount: 2),
        members: [chatUsers[0], chatUsers[1]]));
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_1"].first,
        chat: Chat(id: "test_chat_id_1", ownerId: localUser.id),
        members: [chatUsers[0], chatUsers[4]]));
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_2"].first,
        chat: Chat(id: "test_chat_id_2", ownerId: localUser.id),
        members: [chatUsers[0], chatUsers[5]]));
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_3"].first,
        chat: Chat(id: "test_chat_id_3", ownerId: localUser.id),
        members: [chatUsers[0], chatUsers[1], chatUsers[3]]));
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_4"].first,
        chat: Chat(
            id: "test_chat_id_4", ownerId: chatUsers[3].id, name: "Paradise"),
        members: [chatUsers[0], chatUsers[1], chatUsers[3], chatUsers[5]]));
    _chats.add(ChatWithMembers(
        lastMessage: chatMessages["test_chat_id_5"].first,
        chat: Chat(id: "test_chat_id_5", ownerId: chatUsers[2].id),
        members: [chatUsers[0], chatUsers[2]]));
     */
    return _chats;
  }
}
