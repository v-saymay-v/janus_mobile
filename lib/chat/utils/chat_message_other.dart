import 'package:chat_ui_kit/chat_ui_kit.dart';
import 'package:flutter/material.dart';

/// Edited version of the default [ChatMessageImage] to load from assets
class ChatMessageOther extends StatelessWidget {
  const ChatMessageOther(
      this.index, this.message, this.messagePosition, this.messageFlow,
      {Key key, this.callback})
      : super(key: key);

  final int index;

  final MessageBase message;

  final MessagePosition messagePosition;

  final MessageFlow messageFlow;

  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    final Widget _image = message.url == null
        ? Container()
        : Icon(Icons.file_present, size:180, color: Colors.green);

    return MessageContainer(
        constraints: BoxConstraints(maxWidth: 300, maxHeight: 300),
        padding: EdgeInsets.zero,
        decoration: messageDecoration(context,
            messagePosition: messagePosition,
            messageFlow: messageFlow,
            color: Colors.transparent),
        child: GestureDetector(
            onTap: callback ?? () => {},
            child: Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                Hero(tag: message.url, child: _image),
                MessageFooter(message)
              ],
            )));
  }
}
