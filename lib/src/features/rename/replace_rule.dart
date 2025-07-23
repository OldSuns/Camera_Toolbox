/// 替换规则数据模型
class ReplaceRule {
  String findText;
  String replaceText;
  bool allowReplaceExtension;

  ReplaceRule({
    this.findText = '',
    this.replaceText = '',
    this.allowReplaceExtension = false,
  });

  /// 创建副本
  ReplaceRule copyWith({
    String? findText,
    String? replaceText,
    bool? allowReplaceExtension,
  }) {
    return ReplaceRule(
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
      allowReplaceExtension:
          allowReplaceExtension ?? this.allowReplaceExtension,
    );
  }

  // 从JSON创建对象的工厂构造函数
  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    return ReplaceRule(
      findText: json['findText'] as String,
      replaceText: json['replaceText'] as String,
      allowReplaceExtension: json['allowReplaceExtension'] as bool,
    );
  }

  // 将对象转换为JSON的方法
  Map<String, dynamic> toJson() {
    return {
      'findText': findText,
      'replaceText': replaceText,
      'allowReplaceExtension': allowReplaceExtension,
    };
  }
}
