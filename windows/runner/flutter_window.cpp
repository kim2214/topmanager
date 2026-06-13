`#include "flutter_window.h"

#include <windows.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
// Channel name must match the Dart side (system_monitor_service.dart).
    constexpr char kResourceChannel[] = "com.example.monitor/resource";
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
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
    SetupResourceChannel();
    SetChildContent(flutter_controller_->view()->GetNativeWindow());

    flutter_controller_->engine()->SetNextFrameCallback([&]() {
        this->Show();
    });

    // Flutter can complete the first frame before the "show window" callback is
    // registered. The following call ensures a frame is pending to ensure the
    // window is shown. It is a no-op if the first frame hasn't completed yet.
    flutter_controller_->ForceRedraw();

    return true;
}

void FlutterWindow::SetupResourceChannel() {
    resource_channel_ =
            std::make_unique < flutter::MethodChannel < flutter::EncodableValue >> (
                    flutter_controller_->engine()->messenger(), kResourceChannel,
                            &flutter::StandardMethodCodec::GetInstance());

    resource_channel_->SetMethodCallHandler(
            [](const flutter::MethodCall <flutter::EncodableValue> &call,
               std::unique_ptr <flutter::MethodResult<flutter::EncodableValue>>
               result) {
                if (call.method_name() != "getMemoryStatus") {
                    result->NotImplemented();
                    return;
                }

                MEMORYSTATUSEX mem_status;
                mem_status.dwLength = sizeof(mem_status);
                if (!GlobalMemoryStatusEx(&mem_status)) {
                    result->Error("UNAVAILABLE", "Failed to query memory status.");
                    return;
                }

                // ullTotalPhys is in bytes and easily exceeds 2^31, so it must be
                // sent as int64 to avoid overflow on the Dart side.
                const int64_t total_bytes =
                        static_cast<int64_t>(mem_status.ullTotalPhys);
                const int64_t used_bytes = static_cast<int64_t>(
                        mem_status.ullTotalPhys - mem_status.ullAvailPhys);

                flutter::EncodableMap response = {
                        {flutter::EncodableValue("total_bytes"),
                                flutter::EncodableValue(total_bytes)},
                        {flutter::EncodableValue("used_bytes"),
                                flutter::EncodableValue(used_bytes)},
                };
                result->Success(flutter::EncodableValue(response));
            });
}

void FlutterWindow::OnDestroy() {
    resource_channel_ = nullptr;
    if (flutter_controller_) {
        flutter_controller_ = nullptr;
    }

    Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam)

noexcept {
// Give Flutter, including plugins, an opportunity to handle window messages.
if (flutter_controller_) {
std::optional <LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
if (result) {
return *
result;
}
}

switch (message) {
case WM_FONTCHANGE:
flutter_controller_->engine()->ReloadSystemFonts();
break;
}

return
Win32Window::MessageHandler(hwnd, message, wparam, lparam
);
}
`