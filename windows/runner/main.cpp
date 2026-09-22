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
  std::string widget_type = "all";
  for (const auto& arg : command_line_arguments) {
    if (arg == "--widget" || arg == "--widget=all") {
      is_widget_mode = true;
      widget_type = "all";
      break;
    } else if (arg == "--widget=dashboard" || arg == "--widget-dashboard") {
      is_widget_mode = true;
      widget_type = "dashboard";
      break;
    } else if (arg == "--widget=calendar" || arg == "--widget-calendar") {
      is_widget_mode = true;
      widget_type = "calendar";
      break;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size = Win32Window::Size(1280, 720);
  const wchar_t* title = L"lnote";

  if (is_widget_mode) {
    if (widget_type == "dashboard") {
      size = Win32Window::Size(440, 260);
      title = L"LNote Dashboard Widget";
    } else if (widget_type == "calendar") {
      size = Win32Window::Size(640, 340);
      title = L"LNote Calendar Widget";
    } else {
      size = Win32Window::Size(460, 580);
      title = L"LNote Widget";
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
