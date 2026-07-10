#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static LRESULT CALLBACK ChildWindowProc(HWND hwnd,
                                          UINT const message,
                                          WPARAM const wparam,
                                          LPARAM const lparam);

  bool ShouldPassThroughHitTest(HWND hwnd, LPARAM const lparam) const;
  bool IsCursorInsideInteractiveRegion();
  void StartOverlayMouseTimer();
  void StopOverlayMouseTimer();
  void UpdateOverlayMouseState();
  void SetMousePassThrough(bool enabled);
  void SendHoverChanged(bool hovering);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  HWND child_window_ = nullptr;
  WNDPROC original_child_proc_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      hit_test_channel_;
  bool overlay_hit_test_enabled_ = false;
  double top_pass_through_height_ = 0;
  double interactive_width_ = 0;
  double interactive_height_ = 0;
  double bottom_padding_ = 0;
  bool mouse_pass_through_ = false;
  bool cursor_inside_interactive_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
