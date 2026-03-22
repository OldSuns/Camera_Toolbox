enum ConflictAction {
  overwrite,
  skip,
  rename;

  String get displayName {
    switch (this) {
      case ConflictAction.overwrite:
        return '覆盖';
      case ConflictAction.skip:
        return '跳过';
      case ConflictAction.rename:
        return '重命名';
    }
  }

  String get description {
    switch (this) {
      case ConflictAction.overwrite:
        return '目标存在时直接覆盖';
      case ConflictAction.skip:
        return '目标存在时跳过该文件';
      case ConflictAction.rename:
        return '目标存在时自动追加 _1、_2';
    }
  }
}
