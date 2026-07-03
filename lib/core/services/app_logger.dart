class AppLogger {
  const AppLogger();

  void debug(String message) {
    assert(() {
      // Debug-only output keeps production workflows quiet.
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }
}
