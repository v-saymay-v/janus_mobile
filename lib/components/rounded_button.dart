import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'size_config.dart';

class RoundedButton extends StatelessWidget {
  const RoundedButton({
    Key key,
    this.size = 64,
    @required this.iconSrc,
    this.color = Colors.white,
    this.iconColor = Colors.black,
    @required this.press,
  }) : super(key: key);

  final double size;
  final String iconSrc;
  final Color color, iconColor;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getProportionateScreenWidth(size),
      width: getProportionateScreenWidth(size),
      child: TextButton(
        style: new ButtonStyle(
          padding: MaterialStateProperty.resolveWith<EdgeInsetsGeometry>((Set<MaterialState> states) => EdgeInsets.all(15 / 64 * size)),
          shape: MaterialStateProperty.resolveWith<OutlinedBorder>((Set<MaterialState> states) => RoundedRectangleBorder(borderRadius: new BorderRadius.all(Radius.circular(100)))),
          backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) => color),
        ),
        onPressed: press,
        child: SvgPicture.asset(iconSrc, color: iconColor),
      ),
    );
  }
}
