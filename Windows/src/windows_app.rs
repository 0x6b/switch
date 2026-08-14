use std::{
    collections::HashMap,
    env::{current_dir, var_os},
    fs::{create_dir_all, write},
    path::{Path, PathBuf},
    sync::{
        Mutex, OnceLock,
        mpsc::{Sender, channel},
    },
    thread::spawn,
    time::Instant,
};

use windows::{
    Win32::{
        Foundation::{
            CloseHandle, ERROR_ALREADY_EXISTS, GetLastError, HINSTANCE, HWND, LPARAM, LRESULT,
            WPARAM,
        },
        System::LibraryLoader::GetModuleHandleW,
        System::Threading::{
            AttachThreadInput, CreateMutexW, GetCurrentThreadId, OpenProcess, PROCESS_NAME_WIN32,
            PROCESS_QUERY_LIMITED_INFORMATION, QueryFullProcessImageNameW,
        },
        UI::{
            Input::KeyboardAndMouse::{
                GetAsyncKeyState, VK_CONTROL, VK_LMENU, VK_LSHIFT, VK_LWIN, VK_MENU, VK_RCONTROL,
                VK_RMENU, VK_RSHIFT, VK_RWIN,
            },
            Shell::ShellExecuteW,
            WindowsAndMessaging::{
                BringWindowToTop, CallNextHookEx, DispatchMessageW, EnumWindows, GWL_EXSTYLE,
                GetForegroundWindow, GetMessageW, GetWindowLongW, GetWindowThreadProcessId,
                IsWindowVisible, KBDLLHOOKSTRUCT, MB_ICONERROR, MB_OK, MSG, MessageBoxW,
                SW_RESTORE, SW_SHOWNORMAL, SetForegroundWindow, SetWindowsHookExW, ShowWindow,
                TranslateMessage, UnhookWindowsHookEx, WH_KEYBOARD_LL, WM_KEYDOWN, WM_KEYUP,
                WM_SYSKEYDOWN, WM_SYSKEYUP, WS_EX_TOOLWINDOW,
            },
        },
    },
    core::{BOOL, PCWSTR, PWSTR},
};

use crate::{
    config::{Config, virtual_key},
    decoder::{Action, Decoder},
    executable,
};

static DECODER: OnceLock<Mutex<Decoder>> = OnceLock::new();
static LAUNCHER: OnceLock<Sender<String>> = OnceLock::new();

pub fn run() -> Result<(), String> {
    let instance_name = wide("Local\\Switch.Windows");
    let instance = unsafe { CreateMutexW(None, false, PCWSTR(instance_name.as_ptr())) }
        .map_err(|error| format!("Could not create the single-instance lock: {error}"))?;
    if unsafe { GetLastError() } == ERROR_ALREADY_EXISTS {
        unsafe {
            let _ = CloseHandle(instance);
        }
        return Ok(());
    }

    let path = config_path()?;
    if !path.exists() {
        create_config(&path)?;
        open_shell(&path.to_string_lossy());
        return Ok(());
    }
    let config = Config::load(&path)?;
    let leader = virtual_key(&config.launcher.leader)?;
    let mappings = config
        .launcher
        .primary
        .iter()
        .map(|(key, target)| virtual_key(key).map(|key| (key, target.clone())))
        .collect::<Result<HashMap<_, _>, _>>()?;
    DECODER
        .set(Mutex::new(Decoder::new(
            leader,
            config.launcher.timeout_ms,
            mappings,
        )))
        .map_err(|_| "launcher was already initialized".to_string())?;

    let (sender, receiver) = channel();
    LAUNCHER
        .set(sender)
        .map_err(|_| "launcher worker was already initialized".to_string())?;
    spawn(move || {
        while let Ok(target) = receiver.recv() {
            open_or_activate(&target);
        }
    });

    let module = unsafe { GetModuleHandleW(None) }
        .map_err(|error| format!("Could not get executable module handle: {error}"))?;
    let hook = unsafe {
        SetWindowsHookExW(
            WH_KEYBOARD_LL,
            Some(keyboard_hook),
            Some(HINSTANCE(module.0)),
            0,
        )
    }
    .map_err(|error| format!("Could not install keyboard hook: {error}"))?;
    let mut message = MSG::default();
    while unsafe { GetMessageW(&mut message, None, 0, 0) }.0 > 0 {
        unsafe {
            let _ = TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    unsafe {
        let _ = UnhookWindowsHookEx(hook);
        let _ = CloseHandle(instance);
    }
    Ok(())
}

unsafe extern "system" fn keyboard_hook(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    if code >= 0 {
        let event = unsafe { &*(lparam.0 as *const KBDLLHOOKSTRUCT) };
        let message = wparam.0 as u32;
        if let Some(lock) = DECODER.get() {
            if message == WM_KEYDOWN || message == WM_SYSKEYDOWN {
                let modified = modifier_down();
                if let Ok(mut decoder) = lock.lock() {
                    match decoder.key_down(event.vkCode, modified, Instant::now()) {
                        Action::Consume => return LRESULT(1),
                        Action::Launch(target) => {
                            if let Some(sender) = LAUNCHER.get() {
                                let _ = sender.send(target);
                            }
                            return LRESULT(1);
                        }
                        Action::PassThrough => {}
                    }
                }
            } else if (message == WM_KEYUP || message == WM_SYSKEYUP)
                && lock
                    .lock()
                    .is_ok_and(|mut decoder| decoder.key_up(event.vkCode))
            {
                return LRESULT(1);
            }
        }
    }
    unsafe { CallNextHookEx(None, code, wparam, lparam) }
}

fn modifier_down() -> bool {
    [
        VK_CONTROL,
        VK_LMENU,
        VK_MENU,
        VK_LSHIFT,
        VK_RCONTROL,
        VK_RMENU,
        VK_RSHIFT,
        VK_LWIN,
        VK_RWIN,
    ]
    .iter()
    .any(|key| unsafe { GetAsyncKeyState(key.0 as i32) } < 0)
}

fn config_path() -> Result<PathBuf, String> {
    let root = var_os("LOCALAPPDATA").ok_or("LOCALAPPDATA is not set")?;
    Ok(PathBuf::from(root).join("Switch").join("config.toml"))
}

fn create_config(path: &Path) -> Result<(), String> {
    create_dir_all(path.parent().unwrap()).map_err(|error| error.to_string())?;
    write(path, include_str!("../config.example.toml")).map_err(|error| error.to_string())
}

fn open_or_activate(target: &str) {
    let path = Path::new(target);
    if path
        .extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("exe"))
        && activate_executable(path)
    {
        return;
    }
    open_shell(target);
}

fn activate_executable(executable: &Path) -> bool {
    struct Search {
        executable: PathBuf,
        window: HWND,
    }
    unsafe extern "system" fn callback(window: HWND, data: LPARAM) -> BOOL {
        let search = unsafe { &mut *(data.0 as *mut Search) };
        if !unsafe { IsWindowVisible(window) }.as_bool()
            || unsafe { GetWindowLongW(window, GWL_EXSTYLE) } as u32 & WS_EX_TOOLWINDOW.0 != 0
        {
            return true.into();
        }
        let mut process_id = 0;
        unsafe {
            GetWindowThreadProcessId(window, Some(&mut process_id));
        }
        if process_path(process_id)
            .is_some_and(|path| executable::matches(&path, &search.executable))
        {
            search.window = window;
            return false.into();
        }
        true.into()
    }
    let expected = if executable.is_absolute() {
        executable.to_path_buf()
    } else {
        current_dir().unwrap_or_default().join(executable)
    };
    let mut search = Search {
        executable: expected,
        window: HWND::default(),
    };
    unsafe {
        let _ = EnumWindows(
            Some(callback),
            LPARAM((&mut search as *mut Search) as isize),
        );
    }
    if search.window == HWND::default() {
        return false;
    }
    unsafe {
        let foreground_thread = GetWindowThreadProcessId(GetForegroundWindow(), None);
        let current_thread = GetCurrentThreadId();
        let attached = foreground_thread != 0
            && foreground_thread != current_thread
            && AttachThreadInput(current_thread, foreground_thread, true).as_bool();
        let _ = ShowWindow(search.window, SW_RESTORE);
        let raised = BringWindowToTop(search.window).is_ok();
        let foreground = SetForegroundWindow(search.window).as_bool();
        if attached {
            let _ = AttachThreadInput(current_thread, foreground_thread, false);
        }
        raised || foreground
    }
}

fn process_path(process_id: u32) -> Option<PathBuf> {
    let process =
        unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, process_id) }.ok()?;
    let mut buffer = vec![0u16; 32_768];
    let mut length = buffer.len() as u32;
    let result = unsafe {
        QueryFullProcessImageNameW(
            process,
            PROCESS_NAME_WIN32,
            PWSTR(buffer.as_mut_ptr()),
            &mut length,
        )
    };
    unsafe {
        let _ = CloseHandle(process);
    }
    result.ok()?;
    Some(PathBuf::from(String::from_utf16_lossy(
        &buffer[..length as usize],
    )))
}

fn open_shell(target: &str) {
    let target = wide(target);
    unsafe {
        ShellExecuteW(
            None,
            PCWSTR::null(),
            PCWSTR(target.as_ptr()),
            PCWSTR::null(),
            PCWSTR::null(),
            SW_SHOWNORMAL,
        );
    }
}

pub fn show_error(message: &str) {
    let message = wide(message);
    let title = wide("Switch");
    unsafe {
        MessageBoxW(
            None,
            PCWSTR(message.as_ptr()),
            PCWSTR(title.as_ptr()),
            MB_OK | MB_ICONERROR,
        );
    }
}

fn wide(value: &str) -> Vec<u16> {
    value.encode_utf16().chain(Some(0)).collect()
}
