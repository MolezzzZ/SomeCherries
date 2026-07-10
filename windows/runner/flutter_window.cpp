#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cmath>
#include <cstdint>
#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr const wchar_t kFlutterWindowProp[] = L"CherryTokenMonitorWindow";
constexpr const char kHitTestChannel[] = "cherry_token_monitor/hit_test";
constexpr const char kSetOverlayHitTestMethod[] = "setOverlayHitTest";
constexpr UINT_PTR kOverlayMouseTimer = 9001;
constexpr UINT kOverlayMouseTimerMs = 24;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  child_window_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(child_window_);
  SetProp(child_window_, kFlutterWindowProp, this);
  original_child_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
      child_window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(ChildWindowProc)));

  hit_test_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kHitTestChannel,
      &flutter::StandardMethodCodec::GetInstance());
  hit_test_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name().compare(kSetOverlayHitTestMethod) == 0) {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("bad_args", "Expected map arguments.");
            return;
          }

          auto enabled_it = args->find(flutter::EncodableValue("enabled"));
          if (enabled_it != args->end()) {
            if (const auto* enabled =
                    std::get_if<bool>(&enabled_it->second)) {
              overlay_hit_test_enabled_ = *enabled;
            }
          }

          auto height_it =
              args->find(flutter::EncodableValue("topPassThroughHeight"));
          if (height_it != args->end()) {
            if (const auto* height = std::get_if<double>(&height_it->second)) {
              top_pass_through_height_ = *height;
            }
          }

          auto width_it =
              args->find(flutter::EncodableValue("interactiveWidth"));
          if (width_it != args->end()) {
            if (const auto* width = std::get_if<double>(&width_it->second)) {
              interactive_width_ = *width;
            }
          }

          auto interactive_height_it =
              args->find(flutter::EncodableValue("interactiveHeight"));
          if (interactive_height_it != args->end()) {
            if (const auto* height =
                    std::get_if<double>(&interactive_height_it->second)) {
              interactive_height_ = *height;
            }
          }

          auto padding_it = args->find(flutter::EncodableValue("bottomPadding"));
          if (padding_it != args->end()) {
            if (const auto* padding =
                    std::get_if<double>(&padding_it->second)) {
              bottom_padding_ = *padding;
            }
          }

          if (overlay_hit_test_enabled_) {
            StartOverlayMouseTimer();
            UpdateOverlayMouseState();
          } else {
            StopOverlayMouseTimer();
            SetMousePassThrough(false);
            if (cursor_inside_interactive_) {
              cursor_inside_interactive_ = false;
              SendHoverChanged(false);
            }
          }

          result->Success();
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  StopOverlayMouseTimer();
  SetMousePassThrough(false);
  hit_test_channel_.reset();

  if (child_window_ && original_child_proc_) {
    SetWindowLongPtr(child_window_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(original_child_proc_));
    RemoveProp(child_window_, kFlutterWindowProp);
    original_child_proc_ = nullptr;
    child_window_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_NCHITTEST && ShouldPassThroughHitTest(hwnd, lparam)) {
    return HTTRANSPARENT;
  }

  if (message == WM_TIMER && wparam == kOverlayMouseTimer) {
    UpdateOverlayMouseState();
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

LRESULT CALLBACK FlutterWindow::ChildWindowProc(HWND hwnd,
                                                UINT const message,
                                                WPARAM const wparam,
                                                LPARAM const lparam) {
  auto window = reinterpret_cast<FlutterWindow*>(
      GetProp(hwnd, kFlutterWindowProp));
  if (window) {
    if (message == WM_NCHITTEST &&
        window->ShouldPassThroughHitTest(hwnd, lparam)) {
      return HTTRANSPARENT;
    }
    if (window->original_child_proc_) {
      return CallWindowProc(window->original_child_proc_, hwnd, message, wparam,
                            lparam);
    }
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}

bool FlutterWindow::ShouldPassThroughHitTest(HWND hwnd,
                                             LPARAM const lparam) const {
  if (!overlay_hit_test_enabled_ || top_pass_through_height_ <= 0) {
    return false;
  }

  if (interactive_width_ <= 0 || interactive_height_ <= 0) {
    return false;
  }

  POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  if (!ScreenToClient(hwnd, &point)) {
    return false;
  }

  RECT client_rect;
  GetClientRect(hwnd, &client_rect);
  if (point.x < client_rect.left || point.x >= client_rect.right ||
      point.y < client_rect.top || point.y >= client_rect.bottom) {
    return false;
  }

  const UINT dpi = GetDpiForWindow(hwnd);
  const int interactive_width_pixels =
      MulDiv(static_cast<int>(std::ceil(interactive_width_)), dpi, 96);
  const int interactive_height_pixels =
      MulDiv(static_cast<int>(std::ceil(interactive_height_)), dpi, 96);
  const int bottom_padding_pixels =
      MulDiv(static_cast<int>(std::ceil(bottom_padding_)), dpi, 96);

  const int client_width = client_rect.right - client_rect.left;
  const int client_height = client_rect.bottom - client_rect.top;
  const int interactive_left =
      (client_width - interactive_width_pixels) / 2;
  const int interactive_top =
      client_height - bottom_padding_pixels - interactive_height_pixels;
  const int interactive_right = interactive_left + interactive_width_pixels;
  const int interactive_bottom = interactive_top + interactive_height_pixels;

  return point.x < interactive_left || point.x >= interactive_right ||
         point.y < interactive_top || point.y >= interactive_bottom;
}

bool FlutterWindow::IsCursorInsideInteractiveRegion() {
  if (!overlay_hit_test_enabled_ || interactive_width_ <= 0 ||
      interactive_height_ <= 0) {
    return false;
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    return false;
  }

  POINT point;
  if (!GetCursorPos(&point) || !ScreenToClient(hwnd, &point)) {
    return false;
  }

  RECT client_rect;
  GetClientRect(hwnd, &client_rect);
  if (point.x < client_rect.left || point.x >= client_rect.right ||
      point.y < client_rect.top || point.y >= client_rect.bottom) {
    return false;
  }

  const UINT dpi = GetDpiForWindow(hwnd);
  const int interactive_width_pixels =
      MulDiv(static_cast<int>(std::ceil(interactive_width_)), dpi, 96);
  const int interactive_height_pixels =
      MulDiv(static_cast<int>(std::ceil(interactive_height_)), dpi, 96);
  const int bottom_padding_pixels =
      MulDiv(static_cast<int>(std::ceil(bottom_padding_)), dpi, 96);

  const int client_width = client_rect.right - client_rect.left;
  const int client_height = client_rect.bottom - client_rect.top;
  const int interactive_left = (client_width - interactive_width_pixels) / 2;
  const int interactive_top =
      client_height - bottom_padding_pixels - interactive_height_pixels;
  const int interactive_right = interactive_left + interactive_width_pixels;
  const int interactive_bottom = interactive_top + interactive_height_pixels;

  return point.x >= interactive_left && point.x < interactive_right &&
         point.y >= interactive_top && point.y < interactive_bottom;
}

void FlutterWindow::StartOverlayMouseTimer() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  SetTimer(hwnd, kOverlayMouseTimer, kOverlayMouseTimerMs, nullptr);
}

void FlutterWindow::StopOverlayMouseTimer() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  KillTimer(hwnd, kOverlayMouseTimer);
}

void FlutterWindow::UpdateOverlayMouseState() {
  const bool inside = IsCursorInsideInteractiveRegion();
  SetMousePassThrough(!inside);
  if (inside == cursor_inside_interactive_) {
    return;
  }

  cursor_inside_interactive_ = inside;
  SendHoverChanged(inside);
}

void FlutterWindow::SetMousePassThrough(bool enabled) {
  if (mouse_pass_through_ == enabled) {
    return;
  }

  auto set_transparent = [enabled](HWND hwnd) {
    if (!hwnd) {
      return;
    }
    LONG_PTR style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    if (enabled) {
      style |= WS_EX_TRANSPARENT;
    } else {
      style &= ~WS_EX_TRANSPARENT;
    }
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, style);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                     SWP_FRAMECHANGED);
  };

  set_transparent(GetHandle());
  set_transparent(child_window_);
  mouse_pass_through_ = enabled;
}

void FlutterWindow::SendHoverChanged(bool hovering) {
  if (!hit_test_channel_) {
    return;
  }

  hit_test_channel_->InvokeMethod(
      "hoverChanged", std::make_unique<flutter::EncodableValue>(hovering));
}
