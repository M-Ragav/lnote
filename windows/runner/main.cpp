#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool is_widget_mode = false;
  std::string widget_type = "dashboard";
  for (const auto& arg : command_line_arguments) {
    if (arg == "--widget=empty" || arg == "--widget=glassy" || arg == "--widget-empty") {
      is_widget_mode = true;
      widget_type = "empty";
      break;
    } else if (arg == "--widget=dashboard" || arg == "--widget-dashboard") {
      is_widget_mode = true;
      widget_type = "dashboard";
      break;
    } else if (arg == "--widget=calendar" || arg == "--widget-calendar") {
      is_widget_mode = true;
      widget_type = "calendar";
      break;
    } else if (arg == "--widget" || arg == "--widget=all") {
      is_widget_mode = true;
      widget_type = "dashboard";
      break;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size = Win32Window::Size(1280, 720);
  const wchar_t* title = L"lnote";

  if (is_widget_mode) {
    // Fixed size: 400x200 px
    size = Win32Window::Size(400, 200);

    HMONITOR primary_monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
    UINT dpi = FlutterDesktopGetDpiForMonitor(primary_monitor);
    double scale_factor = (dpi > 0) ? (dpi / 96.0) : 1.0;

    RECT work_area;
    if (SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0)) {
      int work_left = static_cast<int>(work_area.left / scale_factor);
      int work_top = static_cast<int>(work_area.top / scale_factor);
      int work_bottom = static_cast<int>(work_area.bottom / scale_factor);

      const int margin_x = 24;
      const int margin_y = 24;
      const int widget_h = 200;

      if (widget_type == "calendar") {
        // Middle-left of desktop (vertically centered, left margin)
        int y_middle = work_top + (work_bottom - work_top - widget_h) / 2;
        origin = Win32Window::Point(work_left + margin_x, y_middle);
        title = L"LNote Calendar Widget";
      } else if (widget_type == "empty") {
        // Center-left or offset: pure glassy widget
        origin = Win32Window::Point(work_left + margin_x + 424, work_top + margin_y);
        title = L"LNote Glassy Widget";
      } else {
        // Dashboard: Top-left of desktop
        origin = Win32Window::Point(work_left + margin_x, work_top + margin_y);
        title = L"LNote Dashboard Widget";
      }
    } else {
      if (widget_type == "calendar") {
        origin = Win32Window::Point(24, 360);
        title = L"LNote Calendar Widget";
      } else if (widget_type == "empty") {
        origin = Win32Window::Point(450, 24);
        title = L"LNote Glassy Widget";
      } else {
        origin = Win32Window::Point(24, 24);
        title = L"LNote Dashboard Widget";
      }
    }
  }

  if (!window.Create(title, origin, size, is_widget_mode)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
