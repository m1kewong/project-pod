class VideoFeedController {
  Function(String)? _triggerSearchCallback;

  void setTriggerSearchCallback(Function(String) callback) {
    _triggerSearchCallback = callback;
  }

  void triggerSearch(String query) {
    _triggerSearchCallback?.call(query);
  }
}
