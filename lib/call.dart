import 'dart:async';

import 'package:flutter/material.dart';

import 'components/size_config.dart';
import 'components/constants.dart';
import 'components/rounded_button.dart';
import 'components/dial_button.dart';
import 'components/dial_user_pic.dart';

/*
{
    "uuid": "xxxxx-xxxxx-xxxxx-xxxxx",
    "caller_id": "+8618612345678",
    "caller_name": "hello",
    "caller_id_type": "number",
    "has_video": false,

    "extra": {
        "foo": "bar",
        "key": "value",
    }
}
*/

class CallPage extends StatefulWidget {
  CallPage({this.numberCall, this.nameCall, this.photoCall, this.photoCookie = '', this.isIncomming = false});

  final String numberCall;
  final String nameCall;
  final String photoCall;
  final String photoCookie;
  final bool isIncomming;
  String status = "ringing";

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {

  String callUUID;
  Timer _callTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Timer.periodic(
      Duration(milliseconds: 100),
      _onTimer,
    );
  }

  void _onTimer(Timer timer) {
    if (widget.status != "ringing") {
      _callTimer.cancel();
      Navigator.of(context).pop(widget.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              widget.nameCall,
              style: Theme.of(context)
                  .textTheme
                  .headline4
                  .copyWith(color: Colors.white),
            ),
            Text(
              "Calling…",
              style: TextStyle(color: Colors.white),
            ),
            VerticalSpacing(),
            DialUserPic(binImage: Image(image: NetworkImage(widget.photoCall,
                headers: {'Cookie': widget.photoCookie}))),
            Spacer(),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                DialButton(
                  iconSrc: "images/icons/Icon Mic.svg",
                  text: "Audio",
                  press: () {},
                ),
                DialButton(
                  iconSrc: "images/icons/Icon Volume.svg",
                  text: "Microphone",
                  press: () {},
                ),
                DialButton(
                  iconSrc: "images/icons/Icon Video.svg",
                  text: "Video",
                  press: () {},
                ),
                DialButton(
                  iconSrc: "images/icons/Icon Message.svg",
                  text: "Message",
                  press: () {},
                ),
                DialButton(
                  iconSrc: "images/icons/Icon User.svg",
                  text: "Add contact",
                  press: () {},
                ),
                DialButton(
                  iconSrc: "images/icons/Icon Voicemail.svg",
                  text: "Voice mail",
                  press: () {},
                ),
              ],
            ),
            VerticalSpacing(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.isIncomming) RoundedButton(
                iconSrc: "images/icons/call_answer.svg",
                press: () {
                  Navigator.of(context).pop("answer");
                },
                color: Colors.blue,
                iconColor: Colors.white,
              ),
              if (widget.isIncomming) HorizontalSpacing(of: 40),
              RoundedButton(
                iconSrc: "images/icons/call_end.svg",
                press: () {
                  Navigator.of(context).pop("endcall");
                },
                color: kRedColor,
                iconColor: Colors.white,
              )
            ]),
          ],
        ),
      ),
    );
  }
}
