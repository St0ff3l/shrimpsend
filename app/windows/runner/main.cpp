#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWakeMessageName[] =
    L"dev.ultrasend.shrimpsend.wake_main_window";

UINT GetWakeMessage() {
  static UINT message = ::RegisterWindowMessageW(kWakeMessageName);
  return message;
}

std::wstring GetCurrentExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = 0;
  while (true) {
    length = ::GetModuleFileNameW(nullptr, path.data(),
                                  static_cast<DWORD>(path.size()));
    if (length == 0) {
      return L"";
    }
    if (length < path.size()) {
      path.resize(length);
      return path;
    }
    path.resize(path.size() * 2);
  }
}

std::wstring GetProcessExecutablePath(DWORD process_id) {
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) {
    return L"";
  }

  std::wstring path(MAX_PATH, L'\0');
  DWORD size = static_cast<DWORD>(path.size());
  while (!::QueryFullProcessImageNameW(process, 0, path.data(), &size)) {
    if (::GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      ::CloseHandle(process);
      return L"";
    }
    path.resize(path.size() * 2);
    size = static_cast<DWORD>(path.size());
  }
  ::CloseHandle(process);
  path.resize(size);
  return path;
}

struct ExistingWindowSearch {
  std::wstring executable_path;
  HWND window = nullptr;
};

BOOL CALLBACK FindExistingWindowProc(HWND hwnd, LPARAM lparam) {
  auto* search = reinterpret_cast<ExistingWindowSearch*>(lparam);

  wchar_t class_name[256] = {};
  if (::GetClassNameW(
          hwnd, class_name,
          static_cast<int>(sizeof(class_name) / sizeof(class_name[0]))) == 0) {
    return TRUE;
  }
  if (::wcscmp(class_name, kWindowClassName) != 0) {
    return TRUE;
  }

  DWORD process_id = 0;
  ::GetWindowThreadProcessId(hwnd, &process_id);
  if (process_id == 0) {
    return TRUE;
  }

  const std::wstring window_executable_path =
      GetProcessExecutablePath(process_id);
  if (window_executable_path.empty() ||
      ::_wcsicmp(window_executable_path.c_str(),
                 search->executable_path.c_str()) != 0) {
    return TRUE;
  }

  search->window = hwnd;
  return FALSE;
}

HWND FindExistingUltrasendWindow() {
  ExistingWindowSearch search{GetCurrentExecutablePath(), nullptr};
  if (search.executable_path.empty()) {
    return nullptr;
  }

  ::EnumWindows(FindExistingWindowProc, reinterpret_cast<LPARAM>(&search));
  return search.window;
}

void BringWindowToFrontNatively(HWND hwnd) {
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }
  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

void ActivateExistingUltrasendWindow() {
  HWND hwnd = FindExistingUltrasendWindow();
  if (!hwnd) {
    return;
  }

  DWORD_PTR result = 0;
  const UINT wake_message = GetWakeMessage();
  if (wake_message == 0 ||
      !::SendMessageTimeoutW(hwnd, wake_message, 0, 0, SMTO_ABORTIFHUNG, 500,
                             &result)) {
    BringWindowToFrontNatively(hwnd);
  }
}

}  // namespace

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

  ::SetLastError(0);
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\UltrasendDesktopSingleInstance");
  if (instance_mutex == nullptr) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingUltrasendWindow();
    ::CloseHandle(instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
#if defined(WINDOWS_OVERSEAS_BRAND)
  constexpr wchar_t kAppWindowTitle[] = L"ShrimpSend";
#else
  constexpr wchar_t kAppWindowTitle[] = L"虾传";
#endif
  if (!window.Create(kAppWindowTitle, origin, size)) {
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
